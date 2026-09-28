import Testing
import Foundation
@testable import UsageGrid

@Test func appTargetLinks() {
    #expect(String(describing: UsageGridApp.self) == "UsageGridApp")
}

@Test func codexRefreshStatePreservesSuccessfulData() {
    var state = CodexRefreshState()
    let first = [CodexUsageWindow(id: "primary", label: "5-hour limit", usedPercentage: 42, resetText: "Resets in 2h", durationMinutes: 300)]
    let second = [CodexUsageWindow(id: "primary", label: "5-hour limit", usedPercentage: 48, resetText: "Resets in 1h", durationMinutes: 300)]
    let firstDate = Date(timeIntervalSince1970: 1_000)
    let secondDate = Date(timeIntervalSince1970: 2_000)

    #expect(state.windows == nil)
    let started = state.start()
    let overlapping = state.start()
    #expect(started)
    #expect(!overlapping)
    state.finish(with: first, at: firstDate)
    #expect(state.windows?.first?.usedPercentage == 42)
    #expect(state.lastUpdated == firstDate)
    #expect(!state.refreshFailed)

    let refreshStarted = state.start()
    #expect(refreshStarted)
    #expect(state.windows?.first?.usedPercentage == 42)
    state.finish(with: nil, at: secondDate)
    #expect(state.windows?.first?.usedPercentage == 42)
    #expect(state.lastUpdated == firstDate)
    #expect(state.refreshFailed)

    let recoveryStarted = state.start()
    #expect(recoveryStarted)
    #expect(!state.refreshFailed)
    state.finish(with: second, at: secondDate)
    #expect(state.windows?.first?.usedPercentage == 48)
    #expect(state.lastUpdated == secondDate)
    #expect(!state.refreshFailed)
}

@Test func codexRefreshStateHandlesFirstLoadFailure() {
    var state = CodexRefreshState()
    let started = state.start()
    #expect(started)
    state.finish(with: nil, at: Date(timeIntervalSince1970: 1_000))
    #expect(state.windows == nil)
    #expect(state.lastUpdated == nil)
    #expect(state.refreshFailed)
    #expect(!state.isRefreshing)
    let retryStarted = state.start()
    #expect(retryStarted)
    #expect(!state.refreshFailed)
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

@Test func codexExecutableResolutionSupportsCurrentChatGPTBundle() {
    let current = CodexUsageReader.executableCandidates[0]
    let legacy = CodexUsageReader.executableCandidates[2]
    #expect(current == "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex")
    #expect(CodexUsageReader.resolveExecutable { $0 == current || $0 == legacy } == current)
    #expect(CodexUsageReader.resolveExecutable { $0 == legacy } == legacy)
    #expect(CodexUsageReader.resolveExecutable { _ in false } == nil)
}

@Test func codexRateLimitParsingIgnoresUnknownPlanMetadataAndNullWindow() {
    let now = Date(timeIntervalSince1970: 1_000)
    let changed = Data(#"{"result":{"rateLimitsByLimitId":{"codex":{"limitId":"codex","planType":"future-plan-value","primary":{"usedPercent":42,"windowDurationMins":300,"resetsAt":5920},"secondary":null,"rateLimitReachedType":null}},"rateLimitUpsell":{"unknown":true}}}"#.utf8)
    let windows = CodexUsageReader.parse(changed, now: now)
    #expect(windows?.count == 1)
    #expect(windows?.first?.usedPercentage == 42)
    #expect(windows?.first?.label == "5-hour limit")
}

@Test func codexFailureMessagesRemainActionable() {
    #expect(CodexUsageReadError.executableNotFound.userMessage.contains("executable"))
    #expect(CodexUsageReadError.authenticationRequired.userMessage.contains("Sign in"))
    #expect(CodexUsageReadError.requestTimedOut.userMessage.contains("timed out"))
    #expect(CodexUsageReadError.decodingFailed.userMessage.contains("supported usage windows"))
}
