import CodexUsageKit
import Foundation
import Testing

private final class EventBox: @unchecked Sendable {
    var event: TokenCountEvent?
}

@Test
func watcherReadsAppendedRolloutLines() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sessionsDir = tempRoot.appendingPathComponent("sessions/2026/05/09", isDirectory: true)
    try FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)

    let rollout = sessionsDir.appendingPathComponent("rollout-2026-05-09T19-49-11-demo.jsonl")
    try Data().write(to: rollout)

    let parser = RolloutParser()
    let box = EventBox()
    let watcher = RolloutWatcher(sessionsRoot: tempRoot.appendingPathComponent("sessions"), parser: parser)
    watcher.onEvent = { event in
        box.event = event
    }

    let lineOne = """
    {"timestamp":"2026-05-09T17:50:53.430Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":0,"output_tokens":100,"reasoning_output_tokens":10,"total_tokens":1110},"last_token_usage":{"input_tokens":1000,"cached_input_tokens":0,"output_tokens":100,"reasoning_output_tokens":10,"total_tokens":1110}},"rate_limits":{"primary":{"used_percent":40.0,"window_minutes":300,"resets_at":2778358634},"secondary":{"used_percent":50.0,"window_minutes":10080,"resets_at":2778603545},"plan_type":"plus","rate_limit_reached_type":null}}}
    """
    let payloadOne = try #require((lineOne + "\n").data(using: .utf8))
    try payloadOne.write(to: rollout)

    watcher.scanNow()
    #expect(box.event?.rateLimits.primary.usedPercent == 40.0)

    let lineTwo = """
    {"timestamp":"2026-05-09T17:51:53.430Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1500,"cached_input_tokens":0,"output_tokens":100,"reasoning_output_tokens":10,"total_tokens":1610},"last_token_usage":{"input_tokens":500,"cached_input_tokens":0,"output_tokens":0,"reasoning_output_tokens":0,"total_tokens":500}},"rate_limits":{"primary":{"used_percent":45.0,"window_minutes":300,"resets_at":2778358634},"secondary":{"used_percent":52.0,"window_minutes":10080,"resets_at":2778603545},"plan_type":"plus","rate_limit_reached_type":null}}}
    """
    let existing = try String(contentsOf: rollout, encoding: .utf8)
    let payloadTwo = try #require((existing + lineTwo + "\n").data(using: .utf8))
    try payloadTwo.write(to: rollout)

    watcher.scanNow()
    #expect(box.event?.rateLimits.primary.usedPercent == 45.0)
}
