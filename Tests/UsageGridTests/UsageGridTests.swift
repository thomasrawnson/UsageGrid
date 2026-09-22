import Testing
import Foundation
@testable import UsageGrid

@Test func appTargetLinks() {
    #expect(String(describing: UsageGridApp.self) == "UsageGridApp")
}

@Test func usageStatusBoundary() {
    #expect(ProviderUsage(name: "Codex", usedPercentage: 79.9, resetText: "").statusText == "Healthy")
    #expect(ProviderUsage(name: "Codex", usedPercentage: 80, resetText: "").statusText == "Getting high")
}

@Test func codexRateLimitParsing() {
    let now = Date(timeIntervalSince1970: 1_000)
    let valid = Data(#"{"result":{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":42,"windowDurationMins":300,"resetsAt":5920},"secondary":{"usedPercent":18,"windowDurationMins":10080,"resetsAt":371800}}}}}"#.utf8)
    let windows = CodexUsageReader.parse(valid, now: now)
    #expect(windows?.count == 2)
    #expect(windows?[0].label == "5-hour limit")
    #expect(windows?[0].usedPercentage == 42)
    #expect(windows?[0].resetText == "Resets in 1h 22m")
    #expect(windows?[1].label == "Weekly limit")
    #expect(windows?[1].usedPercentage == 18)
    #expect(windows?[1].resetText == "Resets in 4d 7h")

    let reversed = Data(#"{"result":{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":18,"windowDurationMins":10080,"resetsAt":371800},"secondary":{"usedPercent":42,"windowDurationMins":300,"resetsAt":5920}}}}}"#.utf8)
    #expect(CodexUsageReader.parse(reversed, now: now)?.map(\.label) == ["5-hour limit", "Weekly limit"])
}

@Test func codexRateLimitMissingOrMalformed() {
    let now = Date(timeIntervalSince1970: 1_000)
    let shortOnly = Data(#"{"result":{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":42,"windowDurationMins":300,"resetsAt":1300}}}}}"#.utf8)
    #expect(CodexUsageReader.parse(shortOnly, now: now)?.map(\.label) == ["5-hour limit"])
    #expect(CodexUsageReader.parse(shortOnly, now: now)?[0].resetText == "Resets in 5m")

    let longOnly = Data(#"{"result":{"rateLimitsByLimitId":{"codex":{"secondary":{"usedPercent":18,"windowDurationMins":10080,"resetsAt":519400}}}}}"#.utf8)
    #expect(CodexUsageReader.parse(longOnly, now: now)?.map(\.label) == ["Weekly limit"])
    #expect(CodexUsageReader.parse(longOnly, now: now)?[0].resetText == "Resets in 6d")

    let mixed = Data(#"{"result":{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":"bad","windowDurationMins":300},"secondary":{"usedPercent":120,"windowDurationMins":10080}}}}}"#.utf8)
    #expect(CodexUsageReader.parse(mixed, now: now)?.count == 1)
    #expect(CodexUsageReader.parse(mixed, now: now)?[0].usedPercentage == 100)
    #expect(CodexUsageReader.parse(mixed, now: now)?[0].resetText == "Reset unavailable")

    let low = Data(#"{"result":{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":-4,"windowDurationMins":300}}}}}"#.utf8)
    #expect(CodexUsageReader.parse(low, now: now)?[0].usedPercentage == 0)

    #expect(CodexUsageReader.parse(Data(#"{"result":{"rateLimitsByLimitId":{}}}"#.utf8), now: now) == nil)
    #expect(CodexUsageReader.parse(Data(#"{"result":{"rateLimitsByLimitId":{"codex":{"primary":{}}}}}"#.utf8), now: now) == nil)
    #expect(CodexUsageReader.parse(Data(#"{"result":{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":"bad"}}}}}"#.utf8), now: now) == nil)
    #expect(CodexUsageReader.parse(Data("not json".utf8), now: now) == nil)
}
