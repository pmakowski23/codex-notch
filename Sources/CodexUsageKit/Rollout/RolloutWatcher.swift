import CoreServices
import Foundation

public final class RolloutWatcher {
    public typealias EventHandler = @Sendable (TokenCountEvent) -> Void

    private let sessionsRoot: URL
    private let parser: RolloutParser
    private let queue = DispatchQueue(label: "app.codexusage.rolloutwatcher")
    private var fileOffsets: [URL: UInt64] = [:]
    private var stream: FSEventStreamRef?
    private var latestTimestamp: Date = .distantPast

    public var onEvent: EventHandler?

    public init(sessionsRoot: URL, parser: RolloutParser = .init()) {
        self.sessionsRoot = sessionsRoot
        self.parser = parser
    }

    deinit {
        stop()
    }

    public func start() {
        queue.async { [weak self] in
            guard let self else { return }
            self.scanNow()
            self.startEventStream()
        }
    }

    public func stop() {
        queue.sync {
            guard let stream else { return }
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    public func scanNow() {
        guard let latestRollout = newestRolloutFile() else {
            return
        }
        readNewLines(from: latestRollout)
    }

    private func startEventStream() {
        guard stream == nil else {
            return
        }

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<RolloutWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.queue.async {
                watcher.scanNow()
            }
        }

        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        guard let createdStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [sessionsRoot.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            flags
        ) else {
            return
        }

        stream = createdStream
        FSEventStreamSetDispatchQueue(createdStream, queue)
        FSEventStreamStart(createdStream)
    }

    private func newestRolloutFile() -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: [.isRegularFileKey, .nameKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var latestPath: URL?
        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent.hasPrefix("rollout-"),
                  fileURL.pathExtension == "jsonl"
            else {
                continue
            }
            if latestPath == nil || fileURL.path > latestPath!.path {
                latestPath = fileURL
            }
        }
        return latestPath
    }

    private func readNewLines(from fileURL: URL) {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return
        }
        defer { try? handle.close() }

        let currentOffset = fileOffsets[fileURL] ?? 0
        if currentOffset > 0 {
            try? handle.seek(toOffset: currentOffset)
        }

        let data = try? handle.readToEnd()
        let endOffset = (try? handle.offset()) ?? currentOffset
        fileOffsets[fileURL] = endOffset

        guard let data, !data.isEmpty else {
            return
        }

        let raw = String(decoding: data, as: UTF8.self)
        let lines = raw.split(whereSeparator: \.isNewline)
        for line in lines {
            guard let event = parser.parseLine(String(line)) else {
                continue
            }
            guard event.eventTimestamp >= latestTimestamp else {
                continue
            }
            latestTimestamp = event.eventTimestamp
            let handler = onEvent
            if Thread.isMainThread {
                handler?(event)
            } else {
                DispatchQueue.main.sync {
                    handler?(event)
                }
            }
        }
    }
}
