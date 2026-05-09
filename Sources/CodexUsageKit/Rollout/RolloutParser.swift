import Foundation

public struct RolloutParser {
    private let decoder: JSONDecoder
    private let dateFormatter: ISO8601DateFormatter

    public init() {
        decoder = JSONDecoder()
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    public func parseLine(_ line: String) -> TokenCountEvent? {
        guard let data = line.data(using: .utf8) else {
            return nil
        }
        return parseData(data)
    }

    public func parseData(_ data: Data) -> TokenCountEvent? {
        guard let envelope = try? decoder.decode(RolloutEnvelope.self, from: data) else {
            return nil
        }
        guard envelope.type == "event_msg" else {
            return nil
        }
        guard let payload = envelope.payload, payload.type == "token_count" else {
            return nil
        }
        guard let limits = payload.rateLimits else {
            return nil
        }

        let timestamp = parseTimestamp(envelope.timestamp) ?? Date()
        return TokenCountEvent(
            eventTimestamp: timestamp,
            totalTokenUsage: payload.info?.totalTokenUsage,
            lastTokenUsage: payload.info?.lastTokenUsage,
            rateLimits: limits.asRateLimits()
        )
    }

    private func parseTimestamp(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }
        if let parsed = dateFormatter.date(from: value) {
            return parsed
        }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: value)
    }
}
