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
    let valid = Data(#"{"result":{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":42,"resetsAt":1300}}}}}"#.utf8)
    let usage = CodexUsageReader.parse(valid, now: now)
    #expect(usage?.name == "Codex")
    #expect(usage?.usedPercentage == 42)
    #expect(usage?.resetText == "Resets in 5m")

    let high = Data(#"{"result":{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":120,"resetsAt":5920}}}}}"#.utf8)
    #expect(CodexUsageReader.parse(high, now: now)?.usedPercentage == 100)
    #expect(CodexUsageReader.parse(high, now: now)?.resetText == "Resets in 1h 22m")

    let low = Data(#"{"result":{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":-4}}}}}"#.utf8)
    #expect(CodexUsageReader.parse(low, now: now)?.usedPercentage == 0)
    #expect(CodexUsageReader.parse(low, now: now)?.resetText == "Reset unavailable")
}

@Test func codexRateLimitMissingOrMalformed() {
    let now = Date(timeIntervalSince1970: 1_000)
    #expect(CodexUsageReader.parse(Data(#"{"result":{"rateLimitsByLimitId":{}}}"#.utf8), now: now) == nil)
    #expect(CodexUsageReader.parse(Data(#"{"result":{"rateLimitsByLimitId":{"codex":{"primary":{}}}}}"#.utf8), now: now) == nil)
    #expect(CodexUsageReader.parse(Data(#"{"result":{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":"bad"}}}}}"#.utf8), now: now) == nil)
    #expect(CodexUsageReader.parse(Data("not json".utf8), now: now) == nil)
}
