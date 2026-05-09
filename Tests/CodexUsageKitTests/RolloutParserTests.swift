import CodexUsageKit
import Foundation
import Testing

@Test
func parsesTokenCountFixture() throws {
    let url = try #require(Bundle.module.url(forResource: "sample", withExtension: "jsonl", subdirectory: "Fixtures"))
    let raw = try String(contentsOf: url, encoding: .utf8)
    let line = try #require(raw.split(separator: "\n").first.map(String.init))

    let parser = RolloutParser()
    let event = try #require(parser.parseLine(line))

    #expect(event.rateLimits.primary.windowMinutes == 300)
    #expect(event.rateLimits.secondary.windowMinutes == 10080)
    #expect(event.rateLimits.primary.usedPercent == 52.0)
    #expect(event.totalTokenUsage?.totalTokens == 570488)
}
