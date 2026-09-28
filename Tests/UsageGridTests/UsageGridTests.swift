import Testing
import Foundation
import Darwin
@testable import UsageGrid

actor TestUsageAlertNotifications: UsageAlertNotificationProviding {
    var status: UsageAlertPermissionStatus
    var requestResult: Bool
    var requestCount = 0
    var deliveries: [UsageAlertNotification] = []
    var failDelivery: Bool

    init(status: UsageAlertPermissionStatus, requestResult: Bool = false, failDelivery: Bool = false) {
        self.status = status
        self.requestResult = requestResult
        self.failDelivery = failDelivery
    }

    func permissionStatus() async -> UsageAlertPermissionStatus { status }

    func requestPermission() async throws -> Bool {
        requestCount += 1
        status = requestResult ? .authorized : .denied
        return requestResult
    }

    func deliver(_ notification: UsageAlertNotification) async throws {
        deliveries.append(notification)
        if failDelivery { throw TestDeliveryError.failed }
    }

    func snapshot() -> (requestCount: Int, deliveries: [UsageAlertNotification]) {
        (requestCount, deliveries)
    }

    enum TestDeliveryError: Error { case failed }
}

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
    #expect(state.refreshFailed)
    #expect(state.isStale)
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
    #expect(state.refreshFailed)
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

@Test @MainActor func codexCoordinatorRejectsOverlappingRefreshTriggers() async {
    actor Counter {
        var value = 0
        func increment() { value += 1 }
    }
    let counter = Counter()
    let coordinator = CodexRefreshCoordinator()
    let reader: @Sendable () async -> CodexUsageReadResult = {
        await counter.increment()
        try? await Task.sleep(for: .milliseconds(100))
        return .success([CodexUsageWindow(id: "primary", label: "5-hour limit", usedPercentage: 25, resetText: "Resets in 1h", durationMinutes: 300)])
    }

    #expect(coordinator.requestRefresh(reader: reader))
    #expect(!coordinator.requestRefresh(reader: reader))
    await coordinator.waitForRefresh()
    #expect(await counter.value == 1)
}

@Test @MainActor func codexCoordinatorCoalescesWakeRefreshes() async {
    actor Counter {
        var value = 0
        func increment() { value += 1 }
    }
    let counter = Counter()
    let coordinator = CodexRefreshCoordinator()
    let reader: @Sendable () async -> CodexUsageReadResult = {
        await counter.increment()
        return .success([CodexUsageWindow(id: "primary", label: "5-hour limit", usedPercentage: 25, resetText: "Resets in 1h", durationMinutes: 300)])
    }
    let now = Date(timeIntervalSince1970: 10_000)

    #expect(coordinator.handleWake(at: now, reader: reader))
    #expect(!coordinator.handleWake(at: now.addingTimeInterval(0.2), reader: reader))
    await coordinator.waitForRefresh()
    #expect(await counter.value == 1)
}

@Test func codexSuccessfulResponseRemovesMissingOlderSecondaryWindow() {
    var state = CodexRefreshState()
    let primary = CodexUsageWindow(id: "primary", label: "5-hour limit", usedPercentage: 25, resetText: "Resets in 1h", durationMinutes: 300)
    let secondary = CodexUsageWindow(id: "secondary", label: "Weekly limit", usedPercentage: 50, resetText: "Resets in 2d", durationMinutes: 10_080)

    let firstStarted = state.start()
    #expect(firstStarted)
    state.finish(with: .success([primary, secondary]), at: Date(timeIntervalSince1970: 1_000))
    #expect(state.windows?.count == 2)
    let secondStarted = state.start()
    #expect(secondStarted)
    state.finish(with: .success([primary]), at: Date(timeIntervalSince1970: 2_000))
    #expect(state.windows?.map(\.id) == ["primary"])
}

@Test func codexTimeoutCleansUpChildProcess() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let processIDFile = temporaryDirectory.appendingPathComponent("pid")
    let executable = temporaryDirectory.appendingPathComponent("slow-codex")
    let script = """
    #!/bin/sh
    echo $$ > "\(processIDFile.path)"
    while :; do :; done
    """
    try Data(script.utf8).write(to: executable)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)

    let result = await CodexUsageReader.read(executablePath: executable.path, timeout: 1)
    #expect(result.error == .initializationTimedOut)
    let processIDText = try String(contentsOf: processIDFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    let processID = try #require(Int32(processIDText))
    #expect(Darwin.kill(processID, 0) == -1)
}

@Test func menuBarUsageUsedAndRemainingUseTheSameRoundedValue() {
    let timestamp = Date(timeIntervalSince1970: 1_000)
    func presentation(_ percentage: Double, mode: MenuBarDisplayMode) -> MenuBarUsagePresentation {
        MenuBarUsagePresentation.make(
            mode: mode,
            selection: .primary,
            windows: [CodexUsageWindow(id: "primary", label: "3-hour limit", usedPercentage: percentage, resetText: "Reset unavailable", durationMinutes: 180)],
            isStale: false,
            isRefreshing: false,
            lastUpdated: timestamp
        )
    }

    #expect(presentation(0, mode: .usageUsed).text == "0% used")
    #expect(presentation(0, mode: .usageRemaining).text == "100% left")
    #expect(presentation(42.5, mode: .usageUsed).text == "43% used")
    #expect(presentation(42.5, mode: .usageRemaining).text == "57% left")
    #expect(presentation(100, mode: .usageUsed).text == "100% used")
    #expect(presentation(100, mode: .usageRemaining).text == "0% left")
    #expect(presentation(42, mode: .iconOnly).text == nil)
}

@Test func menuBarUsageDoesNotFallBackWhenSelectedWindowIsMissing() {
    let presentation = MenuBarUsagePresentation.make(
        mode: .usageUsed,
        selection: .secondary,
        windows: [CodexUsageWindow(id: "primary", label: "3-hour limit", usedPercentage: 42, resetText: "Reset unavailable", durationMinutes: 180)],
        isStale: false,
        isRefreshing: false,
        lastUpdated: Date(timeIntervalSince1970: 1_000)
    )

    #expect(presentation.text == "—")
    #expect(presentation.accessibilityLabel.contains("Secondary window"))
    #expect(presentation.accessibilityLabel.contains("unavailable"))
}

@Test func menuBarUsageMarksStaleDataAndClearsMarkerAfterRecovery() {
    let window = CodexUsageWindow(id: "primary", label: "3-hour limit", usedPercentage: 42, resetText: "Reset unavailable", durationMinutes: 180)
    let stale = MenuBarUsagePresentation.make(
        mode: .usageUsed,
        selection: .primary,
        windows: [window],
        isStale: true,
        isRefreshing: false,
        lastUpdated: Date(timeIntervalSince1970: 1_000)
    )
    let recovered = MenuBarUsagePresentation.make(
        mode: .usageUsed,
        selection: .primary,
        windows: [window],
        isStale: false,
        isRefreshing: false,
        lastUpdated: Date(timeIntervalSince1970: 2_000)
    )

    #expect(stale.text == "42% used ⚠︎")
    #expect(stale.accessibilityLabel.contains("stale"))
    #expect(recovered.text == "42% used")
    #expect(recovered.accessibilityLabel.contains("fresh"))
}

@Test func menuBarPreferencesPersistInIsolatedDefaults() throws {
    let suiteName = "UsageGridTests.MenuBarPreferences.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let initial = MenuBarPreferences(defaults: defaults)
    #expect(initial.displayMode == .iconOnly)
    #expect(initial.windowSelection == .primary)
    initial.displayMode = .usageRemaining
    initial.windowSelection = .secondary

    let reloaded = MenuBarPreferences(defaults: defaults)
    #expect(reloaded.displayMode == .usageRemaining)
    #expect(reloaded.windowSelection == .secondary)
}

@Test @MainActor func usageAlertsDisabledAndBelowThresholdDoNotDeliver() async throws {
    let suiteName = "UsageGridTests.Alerts.Disabled.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preferences = UsageAlertPreferences(defaults: defaults)
    let notifications = TestUsageAlertNotifications(status: .authorized)
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)
    let reset = Date(timeIntervalSince1970: 20_000)

    let disabled = await controller.evaluate(windows: [alertWindow(used: 95, reset: reset)], isFresh: true)
    #expect(!disabled)
    preferences.enabled = true
    let below = await controller.evaluate(windows: [alertWindow(used: 89.9, reset: reset)], isFresh: true)
    #expect(!below)
    #expect(await notifications.snapshot().deliveries.isEmpty)
}

@Test @MainActor func usageAlertsDeliverAtAndAboveThresholdIncludingFirstReading() async throws {
    let suiteName = "UsageGridTests.Alerts.Threshold.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preferences = UsageAlertPreferences(defaults: defaults)
    preferences.enabled = true
    let notifications = TestUsageAlertNotifications(status: .authorized)
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)

    #expect(await controller.evaluate(windows: [alertWindow(used: 90, reset: Date(timeIntervalSince1970: 20_000))], isFresh: true))
    #expect(await controller.evaluate(windows: [alertWindow(used: 96, reset: Date(timeIntervalSince1970: 30_000))], isFresh: true))
    let deliveries = await notifications.snapshot().deliveries
    #expect(deliveries.count == 2)
    #expect(deliveries[0].title == "Codex usage getting low")
    #expect(deliveries[0].body.contains("90% used, 10% remaining"))
    #expect(deliveries[0].body.contains("3-hour limit"))
}

@Test @MainActor func usageAlertsDeduplicateRepeatedReadingsAndRestart() async throws {
    let suiteName = "UsageGridTests.Alerts.Restart.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let notifications = TestUsageAlertNotifications(status: .authorized)
    let reset = Date(timeIntervalSince1970: 20_000)
    var preferences = UsageAlertPreferences(defaults: defaults)
    preferences.enabled = true
    var controller = UsageAlertController(preferences: preferences, notifications: notifications)

    #expect(await controller.evaluate(windows: [alertWindow(used: 92, reset: reset)], isFresh: true))
    #expect(!(await controller.evaluate(windows: [alertWindow(used: 95, reset: reset)], isFresh: true)))
    preferences = UsageAlertPreferences(defaults: defaults)
    controller = UsageAlertController(preferences: preferences, notifications: notifications)
    #expect(!(await controller.evaluate(windows: [alertWindow(used: 96, reset: reset)], isFresh: true)))
    #expect(await notifications.snapshot().deliveries.count == 1)
}

@Test @MainActor func usageAlertsAllowANewResetWindow() async throws {
    let suiteName = "UsageGridTests.Alerts.NewReset.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preferences = UsageAlertPreferences(defaults: defaults)
    preferences.enabled = true
    let notifications = TestUsageAlertNotifications(status: .authorized)
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)

    #expect(await controller.evaluate(windows: [alertWindow(used: 90, reset: Date(timeIntervalSince1970: 20_000))], isFresh: true))
    #expect(await controller.evaluate(windows: [alertWindow(used: 90, reset: Date(timeIntervalSince1970: 30_000))], isFresh: true))
    #expect(await notifications.snapshot().deliveries.count == 2)
}

@Test @MainActor func usageAlertsSkipMissingResetStaleAndFailedReadings() async throws {
    let suiteName = "UsageGridTests.Alerts.Invalid.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preferences = UsageAlertPreferences(defaults: defaults)
    preferences.enabled = true
    let notifications = TestUsageAlertNotifications(status: .authorized)
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)

    #expect(!(await controller.evaluate(windows: [alertWindow(used: 95, reset: nil)], isFresh: true)))
    #expect(!(await controller.evaluate(windows: [alertWindow(used: 95, reset: Date(timeIntervalSince1970: 20_000))], isFresh: false)))
    #expect(!(await controller.evaluate(windows: nil, isFresh: false)))
    #expect(await notifications.snapshot().deliveries.isEmpty)
}

@Test @MainActor func usageAlertsDoNotRepromptWhenPermissionIsDenied() async throws {
    let suiteName = "UsageGridTests.Alerts.Denied.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preferences = UsageAlertPreferences(defaults: defaults)
    let notifications = TestUsageAlertNotifications(status: .denied)
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)

    await controller.setEnabled(true)
    await controller.setEnabled(true)
    #expect(!preferences.enabled)
    #expect(controller.permissionStatus == .denied)
    #expect(await notifications.snapshot().requestCount == 0)
}

@Test @MainActor func usageAlertsRequestPermissionOnlyWhenEnabled() async throws {
    let suiteName = "UsageGridTests.Alerts.Permission.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preferences = UsageAlertPreferences(defaults: defaults)
    let notifications = TestUsageAlertNotifications(status: .notDetermined, requestResult: true)
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)

    await controller.refreshPermissionStatus()
    #expect(await notifications.snapshot().requestCount == 0)
    await controller.setEnabled(true)
    #expect(preferences.enabled)
    #expect(controller.permissionStatus == .authorized)
    #expect(await notifications.snapshot().requestCount == 1)
}

@Test @MainActor func usageAlertDeliveryFailureIsContainedAndDeduplicated() async throws {
    let suiteName = "UsageGridTests.Alerts.DeliveryFailure.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preferences = UsageAlertPreferences(defaults: defaults)
    preferences.enabled = true
    let notifications = TestUsageAlertNotifications(status: .authorized, failDelivery: true)
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)
    let window = alertWindow(used: 95, reset: Date(timeIntervalSince1970: 20_000))

    #expect(!(await controller.evaluate(windows: [window], isFresh: true)))
    #expect(controller.deliveryError != nil)
    #expect(!(await controller.evaluate(windows: [window], isFresh: true)))
    #expect(await notifications.snapshot().deliveries.count == 1)
}

private func alertWindow(used: Double, reset: Date?) -> CodexUsageWindow {
    CodexUsageWindow(
        id: "primary",
        label: "3-hour limit",
        usedPercentage: used,
        resetText: reset == nil ? "Reset unavailable" : "Resets later",
        durationMinutes: 180,
        resetsAt: reset
    )
}
