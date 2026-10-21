import Testing
import Foundation
import Darwin
import SwiftUI
import AppKit
import UserNotifications
@testable import UsageGrid
@testable import UsageGridClaudeCore

@Test func claudeStatusLineDecodesOnlySupportedQuotaFields() throws {
    let captured = Date(timeIntervalSince1970: 2_000)
    let data = Data(#"{"session_id":"private","transcript_path":"/private/transcript","workspace":{"current_dir":"/private/repo"},"account_id":"private","version":"2.1.90","rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":5000},"seven_day":{"used_percentage":41.2,"resets_at":9000},"spend_limit":{"used_usd":12}}}"#.utf8)
    let snapshot = try ClaudeStatusLineDecoder.decode(data, capturedAt: captured)

    #expect(snapshot.sourceVersion == "2.1.90")
    #expect(snapshot.capturedAt == captured)
    #expect(snapshot.measurementObservedAt == captured)
    #expect(snapshot.windows.map(\.id) == ["five_hour", "seven_day"])
    #expect(snapshot.windows.map(\.usedPercentage) == [23.5, 41.2])

    let encoded = String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
    for forbidden in ["session_id", "private", "transcript", "workspace", "account_id", "spend_limit"] {
        #expect(!encoded.contains(forbidden))
    }
}

@Test func claudeStatusLinePreservesMeasurementFreshnessForIdenticalPayloads() throws {
    let data = Data(#"{"version":"2.1.90","rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":5000}}}"#.utf8)
    let first = try ClaudeStatusLineDecoder.decode(data, capturedAt: Date(timeIntervalSince1970: 1_000))
    let repeated = try ClaudeStatusLineDecoder.decode(data, capturedAt: Date(timeIntervalSince1970: 1_100), previous: first)
    #expect(repeated.capturedAt == Date(timeIntervalSince1970: 1_100))
    #expect(repeated.measurementObservedAt == first.measurementObservedAt)

    let changedData = Data(#"{"version":"2.1.90","rate_limits":{"five_hour":{"used_percentage":24,"resets_at":5000}}}"#.utf8)
    let changed = try ClaudeStatusLineDecoder.decode(changedData, capturedAt: Date(timeIntervalSince1970: 1_200), previous: repeated)
    #expect(changed.measurementObservedAt == Date(timeIntervalSince1970: 1_200))
}

@Test func claudeStatusLineRejectsMalformedUnsupportedAndInvalidPayloads() {
    let now = Date(timeIntervalSince1970: 1_000)
    #expect(throws: ClaudeStatusLineDecodeError.malformedJSON) {
        try ClaudeStatusLineDecoder.decode(Data("not json".utf8), capturedAt: now)
    }
    #expect(throws: ClaudeStatusLineDecodeError.unsupportedPayload) {
        try ClaudeStatusLineDecoder.decode(Data(#"{"version":"2.1.90"}"#.utf8), capturedAt: now)
    }
    #expect(throws: ClaudeStatusLineDecodeError.unsupportedPayload) {
        try ClaudeStatusLineDecoder.decode(Data(#"{"rate_limits":{}}"#.utf8), capturedAt: now)
    }
    for invalid in [-1.0, 101.0] {
        let data = Data("{\"rate_limits\":{\"five_hour\":{\"used_percentage\":\(invalid),\"resets_at\":5000}}}".utf8)
        #expect(throws: ClaudeStatusLineDecodeError.invalidWindow) {
            try ClaudeStatusLineDecoder.decode(data, capturedAt: now)
        }
    }
    let wrongType = Data(#"{"rate_limits":{"five_hour":{"used_percentage":"23","resets_at":5000}}}"#.utf8)
    #expect(throws: ClaudeStatusLineDecodeError.malformedJSON) {
        try ClaudeStatusLineDecoder.decode(wrongType, capturedAt: now)
    }
}

@Test func claudeSnapshotStoreWritesRestrictedSanitizedFile() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("nested/claude.json")
    let store = ClaudeSnapshotStore(fileURL: file)
    let input = Data(#"{"session_id":"must-not-persist","rate_limits":{"five_hour":{"used_percentage":12,"resets_at":5000}}}"#.utf8)
    let snapshot = try store.capture(statusLineData: input, at: Date(timeIntervalSince1970: 1_000))
    #expect(try store.load() == snapshot)

    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    let contents = try String(contentsOf: file, encoding: .utf8)
    #expect(!contents.contains("must-not-persist"))
    #expect(!contents.contains("session_id"))
}

@Test @MainActor func claudeCoordinatorClassifiesFreshStaleExpiredMissingAndCorrupt() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("claude.json")
    let store = ClaudeSnapshotStore(fileURL: file)
    var now = Date(timeIntervalSince1970: 1_000)
    let coordinator = ClaudeUsageCoordinator(store: store, now: { now })

    coordinator.refresh()
    #expect(coordinator.availability == .missing)
    let data = Data(#"{"rate_limits":{"five_hour":{"used_percentage":12,"resets_at":5000}}}"#.utf8)
    _ = try store.capture(statusLineData: data, at: now)
    coordinator.refresh()
    #expect(coordinator.availability == .available)

    now = Date(timeIntervalSince1970: 1_121)
    coordinator.refresh()
    #expect(coordinator.availability == .stale)
    now = Date(timeIntervalSince1970: 5_001)
    coordinator.refresh()
    #expect(coordinator.availability == .expired)

    try Data("broken".utf8).write(to: file)
    coordinator.refresh()
    #expect(coordinator.availability == .corrupt)
}

@Test func claudeMissingSnapshotPresentationIsHonestAboutIndistinguishableCauses() {
    let message = ClaudeUsageAvailability.missing.message
    #expect(message.contains("No snapshot has been received"))
    #expect(message.contains("may not be configured"))
    #expect(message.contains("may not have run"))
    #expect(!message.contains("not installed"))
    #expect(!message.contains("signed out"))
}

@Test func claudeCorruptUnsupportedStaleAndExpiredPresentationsAreActionable() {
    #expect(ClaudeUsageAvailability.corrupt.message.contains("cannot be read"))
    #expect(ClaudeUsageAvailability.corrupt.message.contains("replacement"))
    #expect(ClaudeUsageAvailability.unsupported.message.contains("not supported"))
    #expect(ClaudeUsageAvailability.unsupported.message.contains("matching capture helper"))
    #expect(ClaudeUsageAvailability.stale.message.contains("may be stale"))
    #expect(ClaudeUsageAvailability.expired.message.contains("expired"))
}

@Test func claudeOnboardingTemplatesRequireReviewedPathsAndPreserveExistingStatusLine() {
    #expect(ClaudeOnboardingContent.repositoryBuildCommand == "swift build -c release --product UsageGridClaudeCapture")
    #expect(ClaudeOnboardingContent.configurationTemplate.contains("/absolute/path/to/UsageGridClaudeCapture"))
    #expect(ClaudeOnboardingContent.coexistenceWrapperTemplate.contains("/absolute/path/to/existing-status-line"))
    #expect(ClaudeOnboardingContent.coexistenceWrapperTemplate.contains("input=$(cat)"))
    #expect(ClaudeOnboardingContent.undetectableState.contains("cannot determine"))
    #expect(ClaudeOnboardingContent.undetectableState.contains("installed, authenticated, or configured"))
}

@Test @MainActor func claudeSetupGuideRendersWithoutChangingCodexPresentation() {
    let renderer = ImageRenderer(content: ClaudeSetupGuideView().frame(width: 320))
    renderer.proposedSize = ProposedViewSize(width: 320, height: 900)
    #expect(renderer.cgImage != nil)
    #expect(SelectedProvider.codex.selectorTitle == "Codex")
    #expect(SelectedProvider.codex.accessibilityLabel == "Codex provider")
}

@Test func supportDiagnosticsUsesOnlyAllowlistedSafeFields() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let sentinel = "SECRET user@example.com /Users/private token=abc123"
    let report = SupportDiagnosticsReport.make(input: SupportDiagnosticsInput(
        appVersion: "1.2.3", appBuild: "45", macOSVersion: "Version 15.0", architecture: "arm64",
        isRefreshing: false, hasReading: true, isStale: true,
        lastSuccessfulRefresh: now.addingTimeInterval(-125), lastError: .authenticationRequired,
        unsafeErrorDetail: sentinel, executableSource: "ChatGPT bundled Codex",
        notificationSettings: SupportNotificationSettings(authorization: "Authorized", alerts: "Enabled", notificationCentre: "Disabled"),
        historyRecordingEnabled: true, historyHasStorageError: true
    ), now: now)

    #expect(report.contains("App version: 1.2.3"))
    #expect(report.contains("Connection: Connected; latest refresh failed"))
    #expect(report.contains("Last error category: Authentication"))
    #expect(report.contains("Last error: Codex sign-in is required."))
    #expect(report.contains("Last successful refresh: 2 minutes ago"))
    #expect(report.contains("Notification Centre: Disabled"))
    #expect(report.contains("History storage: Unavailable (local storage error)"))
    #expect(!report.contains(sentinel))
    #expect(!report.contains("user@example.com"))
    #expect(!report.contains("/Users/"))
}

@Test func supportDiagnosticsReportsUnknownAndUnavailableStates() {
    let report = SupportDiagnosticsReport.make(input: SupportDiagnosticsInput(
        appVersion: nil, appBuild: nil, macOSVersion: nil, architecture: nil,
        isRefreshing: false, hasReading: false, isStale: false,
        lastSuccessfulRefresh: nil, lastError: nil, unsafeErrorDetail: nil,
        executableSource: nil, notificationSettings: nil,
        historyRecordingEnabled: false, historyHasStorageError: false
    ))

    #expect(report.contains("App version: Unknown"))
    #expect(report.contains("Connection: Not yet established"))
    #expect(report.contains("Reading freshness: Unavailable"))
    #expect(report.contains("Last successful refresh: Unavailable"))
    #expect(report.contains("Notification permission: Unknown"))
}

@Test func supportDiagnosticsMapsEveryReaderErrorToFixedSafeCopy() {
    let errors: [CodexUsageReadError] = [
        .executableNotFound, .processLaunchFailed, .initializationTimedOut, .initializationFailed,
        .requestTimedOut, .authenticationRequired, .requestFailed, .usageUnavailable,
        .unsupportedResponse, .decodingFailed, .cancelled
    ]
    for error in errors {
        let mapped = SupportDiagnosticsReport.safeErrorDescription(error)
        #expect(mapped.category != "Unknown")
        #expect(!mapped.description.isEmpty)
        #expect(!mapped.description.contains("/"))
    }
}

actor TestUsageAlertNotifications: UsageAlertNotificationProviding {
    var status: UsageAlertPermissionStatus
    var requestResult: Bool
    var requestCount = 0
    var deliveries: [UsageAlertNotification] = []
    var failDelivery: Bool
    var deliveryDelay: Duration?
    var permissionStatusDelays: [Duration]

    init(status: UsageAlertPermissionStatus, requestResult: Bool = false, failDelivery: Bool = false, deliveryDelay: Duration? = nil, permissionStatusDelays: [Duration] = []) {
        self.status = status
        self.requestResult = requestResult
        self.failDelivery = failDelivery
        self.deliveryDelay = deliveryDelay
        self.permissionStatusDelays = permissionStatusDelays
    }

    func permissionStatus() async -> UsageAlertPermissionStatus {
        let result = status
        if !permissionStatusDelays.isEmpty {
            let delay = permissionStatusDelays.removeFirst()
            try? await Task.sleep(for: delay)
        }
        return result
    }

    func setStatus(_ newStatus: UsageAlertPermissionStatus) {
        status = newStatus
    }

    func requestPermission() async throws -> Bool {
        requestCount += 1
        status = requestResult ? .authorized : .denied
        return requestResult
    }

    func deliver(_ notification: UsageAlertNotification) async throws {
        deliveries.append(notification)
        if let deliveryDelay { try? await Task.sleep(for: deliveryDelay) }
        if failDelivery { throw TestDeliveryError.failed }
    }

    func snapshot() -> (requestCount: Int, deliveries: [UsageAlertNotification]) {
        (requestCount, deliveries)
    }

    enum TestDeliveryError: Error { case failed }
}

@Test func foregroundNotificationPresentationIncludesBannerAndNotificationCentre() {
    let options = UsageGridAppDelegate.foregroundPresentationOptions
    #expect(options.contains(.banner))
    #expect(options.contains(.list))
}

actor TestHistoryStore: UsageHistoryPersisting {
    var stored: [UsageHistorySample]
    var generation = 0
    var failLoad = false
    var failSave = false
    var failClear = false

    init(stored: [UsageHistorySample] = []) { self.stored = stored }
    func load(now: Date) async throws -> [UsageHistorySample] {
        if failLoad { throw TestError.failed }
        return UsageHistoryMath.retained(stored, now: now)
    }
    func save(_ samples: [UsageHistorySample], generation requested: Int) async throws {
        if failSave { throw TestError.failed }
        guard requested >= generation else { return }
        generation = requested; stored = samples
    }
    func clear(generation requested: Int) async throws {
        if failClear { throw TestError.failed }
        generation = max(generation, requested); stored = []
    }
    func setFailSave(_ value: Bool) { failSave = value }
    func snapshot() -> [UsageHistorySample] { stored }
    enum TestError: Error { case failed }
}

@Test func appTargetLinks() {
    #expect(String(describing: UsageGridApp.self) == "UsageGridApp")
}

@Test func themeCatalogueLookupAndFallback() {
    #expect(UsageTheme.lookup("programming").id == .programming)
    #expect(UsageTheme.lookup("professional").id == .professional)
    #expect(UsageTheme.lookup("retro").id == .retro)
    #expect(UsageTheme.lookup("anime").id == .anime)
    #expect(UsageTheme.lookup("zenForest").id == .zenForest)
    #expect(UsageTheme.lookup("space").id == .space)
    #expect(UsageTheme.lookup("christmas").id == .programming)
    #expect(UsageTheme.lookup("halloween").id == .programming)
    #expect(UsageTheme.lookup("midnight").id == .programming)
    #expect(UsageTheme.lookup("paper").id == .programming)
    #expect(UsageTheme.lookup("aurora").id == .programming)
    #expect(UsageTheme.lookup("future-theme").id == .programming)
    #expect(UsageTheme.lookup(nil).id == .programming)
    #expect(UsageTheme.all.count == 6)
}

@Test func allThemesAreAvailableAndSavedSelectionSurvivesRestart() throws {
    let suiteName = "UsageGridTests.Themes.Free.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    for theme in UsageTheme.all {
        defaults.set(theme.id.rawValue, forKey: ThemePreferences.activeThemeKey)
        let preferences = ThemePreferences(defaults: defaults)
        #expect(preferences.activeTheme.id == theme.id)
        #expect(preferences.select(theme))
        #expect(defaults.string(forKey: ThemePreferences.activeThemeKey) == theme.id.rawValue)
    }
    let preferences = ThemePreferences(defaults: defaults)
    let previewedTheme = UsageTheme.lookup(UsageThemeID.anime.rawValue)
    #expect(previewedTheme.id == .anime)
    #expect(ThemePreviewState.allCases == [.normal, .stale, .unavailable, .error])
    #expect(preferences.activeTheme.id == .space)
}

@Test @MainActor func themeSampleStatesRender() {
    for theme in UsageTheme.all {
        let palette = UsageThemePalette(theme: theme, colorScheme: .dark)
        for state in ThemePreviewState.allCases {
            let renderer = ImageRenderer(content: ThemeSampleCard(theme: theme, state: state, palette: palette).frame(width: 460))
            renderer.proposedSize = ProposedViewSize(width: 460, height: state == .normal || state == .stale ? 190 : 90)
            #expect(renderer.cgImage != nil, "Expected \(theme.name) \(state.title) preview to render")
        }
    }
}

@Test @MainActor func exportThemePreviewsWhenRequested() throws {
    guard let outputPath = ProcessInfo.processInfo.environment["USAGEGRID_THEME_PREVIEW_DIR"] else { return }
    let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

    for theme in UsageTheme.all {
        let palette = UsageThemePalette(theme: theme, colorScheme: .dark)
        let renderer = ImageRenderer(content: ThemeExportPreview(theme: theme, palette: palette))
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: 940, height: 650)
        let image = try #require(renderer.cgImage)
        let bitmap = NSBitmapImageRep(cgImage: image)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: outputURL.appendingPathComponent("\(theme.id.rawValue)-preview.png"))
    }
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

@Test func codexRateLimitParsingPrefersDocumentedTopLevelSnapshot() {
    let now = Date(timeIntervalSince1970: 1_000)
    let payload = Data(#"{"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":37,"windowDurationMins":300,"resetsAt":5920}},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":99,"windowDurationMins":300,"resetsAt":5920}}},"planType":"changed-plan"}}"#.utf8)
    let windows = CodexUsageReader.parse(payload, now: now)
    #expect(windows?.count == 1)
    #expect(windows?.first?.usedPercentage == 37)
    #expect(windows?.first?.label == "5-hour limit")
}

@Test func codexRateLimitParsingAcceptsMappedLimitWithChangedKey() {
    let now = Date(timeIntervalSince1970: 1_000)
    let payload = Data(#"{"result":{"rateLimitsByLimitId":{"new-account-scope":{"limitId":"codex","primary":{"usedPercent":21,"windowDurationMins":300,"resetsAt":5920}}}}}"#.utf8)
    #expect(CodexUsageReader.parse(payload, now: now)?.first?.usedPercentage == 21)
}

@Test func codexRateLimitParsingHandlesOptionalAndPartialFieldsWithoutInventingValues() {
    let now = Date(timeIntervalSince1970: 1_000)
    let payload = Data(#"{"result":{"rateLimits":{"primary":{"usedPercent":42},"secondary":{"usedPercent":"malformed","windowDurationMins":10080}}}}"#.utf8)
    let windows = CodexUsageReader.parse(payload, now: now)
    #expect(windows?.count == 1)
    #expect(windows?.first?.label == "Primary limit")
    #expect(windows?.first?.durationMinutes == 0)
    #expect(windows?.first?.resetsAt == nil)
    #expect(windows?.first?.resetText == "Reset unavailable")
}

@Test func codexRateLimitParsingDistinguishesUnavailableAndUnsupportedResponses() {
    let now = Date(timeIntervalSince1970: 1_000)
    let unavailable = Data(#"{"result":{"rateLimits":{"limitId":"codex","primary":null,"secondary":null}}}"#.utf8)
    let malformed = Data(#"{"result":{"rateLimits":{"primary":{"usedPercent":"bad","windowDurationMins":300}}}}"#.utf8)
    #expect(CodexUsageReader.parseResult(unavailable, now: now) == .usageUnavailable)
    #expect(CodexUsageReader.parseResult(malformed, now: now) == .unsupportedResponse)
    #expect(CodexUsageReader.parseResult(Data("not json".utf8), now: now) == .unsupportedResponse)
}

@Test func codexExpiredWindowIsExplicitAndNotFabricated() {
    let now = Date(timeIntervalSince1970: 2_000)
    let payload = Data(#"{"result":{"rateLimits":{"primary":{"usedPercent":91,"windowDurationMins":300,"resetsAt":1000}}}}"#.utf8)
    let window = CodexUsageReader.parse(payload, now: now)?.first
    #expect(window?.usedPercentage == 91)
    #expect(window?.resetsAt == Date(timeIntervalSince1970: 1_000))
    #expect(window?.resetText == "Reset due")
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
    #expect(CodexUsageReadError.usageUnavailable.userMessage.contains("temporarily unavailable"))
    #expect(CodexUsageReadError.unsupportedResponse.userMessage.contains("unsupported"))
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

@Test func providerSelectorLabelsClaudeAsExperimentalAndPreservesCodexPresentation() {
    #expect(SelectedProvider.codex.selectorTitle == "Codex")
    #expect(SelectedProvider.codex.accessibilityLabel == "Codex provider")
    #expect(SelectedProvider.claude.selectorTitle == "Claude — Experimental")
    #expect(SelectedProvider.claude.accessibilityLabel.contains("experimental passive snapshot"))
}

@Test func usageWindowAccessibilityUsesActualProviderAndCompleteWindowDetails() {
    let window = CodexUsageWindow(
        id: "seven_day", label: "Weekly limit", usedPercentage: 41.6,
        resetText: "Resets in 2d", durationMinutes: 10_080,
        resetsAt: Date(timeIntervalSince1970: 20_000)
    )
    let presentation = UsageWindowAccessibilityPresentation.make(
        providerName: "Claude", window: window, freshnessDescription: "stale measurement"
    )

    #expect(presentation.label == "Claude, Weekly limit usage")
    #expect(!presentation.label.contains("Codex"))
    #expect(presentation.value.contains("42 percent used"))
    #expect(presentation.value.contains("7 days window"))
    #expect(presentation.value.contains("Resets in 2d"))
    #expect(presentation.value.contains("stale measurement"))
}

@Test func usageWindowAccessibilityAnnouncesMissingMetadataAsUnavailableNotZero() {
    let window = CodexUsageWindow(
        id: "primary", label: "Primary limit", usedPercentage: 23,
        resetText: "Reset unavailable", durationMinutes: 0, resetsAt: nil
    )
    let presentation = UsageWindowAccessibilityPresentation.make(
        providerName: "Codex", window: window, freshnessDescription: nil
    )

    #expect(presentation.label == "Codex, Primary limit usage")
    #expect(presentation.value.contains("23 percent used"))
    #expect(presentation.value.contains("window duration unavailable"))
    #expect(presentation.value.contains("reset unavailable"))
    #expect(!presentation.value.contains("0 percent"))
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

    #expect(await controller.evaluate(windows: [alertWindow(used: 90, reset: Date(timeIntervalSince1970: 20_000))], isFresh: true, observedAt: Date(timeIntervalSince1970: 10_000)))
    #expect(await controller.evaluate(windows: [alertWindow(used: 96, reset: Date(timeIntervalSince1970: 30_000))], isFresh: true, observedAt: Date(timeIntervalSince1970: 10_000)))
    let deliveries = await notifications.snapshot().deliveries
    #expect(deliveries.count == 2)
    #expect(deliveries[0].title == "Codex usage limit approaching")
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

    #expect(await controller.evaluate(windows: [alertWindow(used: 92, reset: reset)], isFresh: true, observedAt: Date(timeIntervalSince1970: 10_000)))
    #expect(!(await controller.evaluate(windows: [alertWindow(used: 95, reset: reset)], isFresh: true, observedAt: Date(timeIntervalSince1970: 10_000))))
    preferences = UsageAlertPreferences(defaults: defaults)
    controller = UsageAlertController(preferences: preferences, notifications: notifications)
    #expect(!(await controller.evaluate(windows: [alertWindow(used: 96, reset: reset)], isFresh: true, observedAt: Date(timeIntervalSince1970: 10_000))))
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

    #expect(await controller.evaluate(windows: [alertWindow(used: 90, reset: Date(timeIntervalSince1970: 20_000))], isFresh: true, observedAt: Date(timeIntervalSince1970: 10_000)))
    #expect(await controller.evaluate(windows: [alertWindow(used: 90, reset: Date(timeIntervalSince1970: 30_000))], isFresh: true, observedAt: Date(timeIntervalSince1970: 10_000)))
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

@Test @MainActor func stalePermissionRefreshCannotUndoNewerEnableAction() async throws {
    let suiteName = "UsageGridTests.Alerts.RefreshRace.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preferences = UsageAlertPreferences(defaults: defaults)
    let notifications = TestUsageAlertNotifications(
        status: .denied,
        permissionStatusDelays: [.milliseconds(80), .zero]
    )
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)

    let staleRefresh = Task { await controller.refreshPermissionStatus() }
    try? await Task.sleep(for: .milliseconds(10))
    await notifications.setStatus(.authorized)
    await controller.setEnabled(true)
    await staleRefresh.value

    #expect(preferences.enabled)
    #expect(controller.permissionStatus == .authorized)
}

@Test @MainActor func permissionRefreshDoesNotRewriteAlertPreference() async throws {
    let suiteName = "UsageGridTests.Alerts.PreferenceSeparation.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preferences = UsageAlertPreferences(defaults: defaults)
    preferences.enabled = true
    let notifications = TestUsageAlertNotifications(status: .denied)
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)

    await controller.refreshPermissionStatus()

    #expect(preferences.enabled)
    #expect(controller.permissionStatus == .denied)
    #expect(controller.permissionMessage.contains("System Settings"))
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

    #expect(!(await controller.evaluate(windows: [window], isFresh: true, observedAt: Date(timeIntervalSince1970: 10_000))))
    #expect(controller.deliveryError != nil)
    #expect(!(await controller.evaluate(windows: [window], isFresh: true, observedAt: Date(timeIntervalSince1970: 10_000))))
    #expect(await notifications.snapshot().deliveries.count == 1)
}

private func alertWindow(used: Double, reset: Date?, id: String = "primary", duration: Int = 180, label: String = "3-hour limit") -> CodexUsageWindow {
    CodexUsageWindow(
        id: id,
        label: label,
        usedPercentage: used,
        resetText: reset == nil ? "Reset unavailable" : "Resets later",
        durationMinutes: duration,
        resetsAt: reset
    )
}

@Test func secondaryAlertPreferencesAreAdditiveAndPrimaryStateMigratesUnchanged() throws {
    let suite = "UsageGridTests.Alerts.Migration.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(true, forKey: UsageAlertPreferences.enabledKey)
    defaults.set(95, forKey: UsageAlertPreferences.thresholdKey)
    defaults.set("primary:180:20000", forKey: UsageAlertPreferences.lastAlertedWindowKey)
    let preferences = UsageAlertPreferences(defaults: defaults)
    #expect(preferences.enabled)
    #expect(preferences.threshold == .ninetyFive)
    #expect(preferences.lastAlertedWindow == "primary:180:20000")
    #expect(!preferences.secondaryEnabled)
    #expect(preferences.secondaryThreshold == .ninety)
    #expect(preferences.lastAlertedSecondaryWindow == nil)
}

@Test @MainActor func secondaryAlertsUseIndependentThresholdsAndIdentifyWindows() async throws {
    let defaults = try #require(UserDefaults(suiteName: "UsageGridTests.Alerts.Independent.\(UUID())"))
    let preferences = UsageAlertPreferences(defaults: defaults)
    preferences.enabled = true; preferences.threshold = .ninetyFive
    preferences.secondaryEnabled = true; preferences.secondaryThreshold = .eighty
    let notifications = TestUsageAlertNotifications(status: .authorized)
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)
    let reset = Date(timeIntervalSince1970: 20_000)
    let windows = [
        alertWindow(used: 90, reset: reset),
        alertWindow(used: 80, reset: reset, id: "secondary", duration: 10_080, label: "Weekly limit")
    ]
    #expect(await controller.evaluate(windows: windows, isFresh: true, observedAt: Date(timeIntervalSince1970: 10_000)))
    let deliveries = await notifications.snapshot().deliveries
    #expect(deliveries.count == 1)
    #expect(deliveries[0].body.contains("Secondary window"))
    #expect(deliveries[0].body.contains("Weekly limit"))
    #expect(preferences.lastAlertedWindow == nil)
    #expect(preferences.lastAlertedSecondaryWindow != nil)
}

@Test @MainActor func missingSecondaryDoesNotSuppressPrimaryAndMissingPrimaryDoesNotSuppressSecondary() async throws {
    let defaults = try #require(UserDefaults(suiteName: "UsageGridTests.Alerts.MissingWindow.\(UUID())"))
    let preferences = UsageAlertPreferences(defaults: defaults)
    preferences.enabled = true; preferences.secondaryEnabled = true
    let notifications = TestUsageAlertNotifications(status: .authorized)
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)
    #expect(await controller.evaluate(windows: [alertWindow(used: 91, reset: Date(timeIntervalSince1970: 20_000))], isFresh: true, observedAt: Date(timeIntervalSince1970: 10_000)))
    #expect(await controller.evaluate(windows: [alertWindow(used: 91, reset: Date(timeIntervalSince1970: 30_000), id: "secondary", duration: 10_080, label: "Weekly limit")], isFresh: true, observedAt: Date(timeIntervalSince1970: 10_000)))
    #expect(await notifications.snapshot().deliveries.count == 2)
}

@Test @MainActor func primaryAndSecondaryDeduplicateSeparatelyAcrossRestart() async throws {
    let suite = "UsageGridTests.Alerts.SecondaryRestart.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
    var preferences = UsageAlertPreferences(defaults: defaults)
    preferences.enabled = true; preferences.secondaryEnabled = true
    let notifications = TestUsageAlertNotifications(status: .authorized)
    let reset = Date(timeIntervalSince1970: 20_000)
    let windows = [alertWindow(used: 92, reset: reset), alertWindow(used: 92, reset: reset, id: "secondary", duration: 10_080, label: "Weekly limit")]
    var controller = UsageAlertController(preferences: preferences, notifications: notifications)
    #expect(await controller.evaluate(windows: windows, isFresh: true, observedAt: Date(timeIntervalSince1970: 10_000)))
    #expect(await notifications.snapshot().deliveries.count == 2)
    preferences = UsageAlertPreferences(defaults: defaults)
    controller = UsageAlertController(preferences: preferences, notifications: notifications)
    #expect(!(await controller.evaluate(windows: windows, isFresh: true, observedAt: Date(timeIntervalSince1970: 10_000))))
    #expect(await notifications.snapshot().deliveries.count == 2)
}

@Test @MainActor func permissionRefreshDoesNotEnableEitherWindowAlert() async throws {
    let defaults = try #require(UserDefaults(suiteName: "UsageGridTests.Alerts.BothPreferenceSeparation.\(UUID())"))
    let preferences = UsageAlertPreferences(defaults: defaults)
    let notifications = TestUsageAlertNotifications(status: .authorized)
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)
    await controller.refreshPermissionStatus()
    #expect(controller.permissionStatus == .authorized)
    #expect(!preferences.enabled)
    #expect(!preferences.secondaryEnabled)
}

@Test func resetAlertPreferencesDefaultOffAndPersistSeparately() throws {
    let suite = "UsageGridTests.Alerts.ResetPreferences.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
    var preferences = UsageAlertPreferences(defaults: defaults)
    #expect(!preferences.primaryResetEnabled)
    #expect(!preferences.secondaryResetEnabled)
    preferences.primaryResetEnabled = true
    preferences.lastPrimaryResetNotification = "primary-reset"
    preferences = UsageAlertPreferences(defaults: defaults)
    #expect(preferences.primaryResetEnabled)
    #expect(!preferences.secondaryResetEnabled)
    #expect(preferences.lastPrimaryResetNotification == "primary-reset")
    #expect(preferences.lastAlertedWindow == nil)
}

@Test @MainActor func resetAlertFirstReadingBaselinesAndConfirmedRolloverNotifiesOnce() async throws {
    let defaults = try #require(UserDefaults(suiteName: "UsageGridTests.Alerts.ResetConfirmed.\(UUID())"))
    let preferences = UsageAlertPreferences(defaults: defaults); preferences.primaryResetEnabled = true
    let notifications = TestUsageAlertNotifications(status: .authorized)
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)
    let firstReset = Date(timeIntervalSince1970: 1_100)
    let nextReset = Date(timeIntervalSince1970: 1_400)

    #expect(!(await controller.evaluate(windows: [alertWindow(used: 72, reset: firstReset)], isFresh: true, observedAt: Date(timeIntervalSince1970: 1_000))))
    #expect(await controller.evaluate(windows: [alertWindow(used: 8, reset: nextReset)], isFresh: true, observedAt: Date(timeIntervalSince1970: 1_101)))
    #expect(!(await controller.evaluate(windows: [alertWindow(used: 9, reset: nextReset)], isFresh: true, observedAt: Date(timeIntervalSince1970: 1_102))))
    let deliveries = await notifications.snapshot().deliveries
    #expect(deliveries.count == 1)
    #expect(deliveries[0].title == "Codex usage window reset")
    #expect(deliveries[0].body.contains("Primary window"))
    #expect(deliveries[0].body.contains("92% remaining"))
}

@Test @MainActor func resetAlertRejectsEarlyMetadataChangesAndPercentageDecreases() async throws {
    let defaults = try #require(UserDefaults(suiteName: "UsageGridTests.Alerts.ResetEarly.\(UUID())"))
    let preferences = UsageAlertPreferences(defaults: defaults); preferences.primaryResetEnabled = true
    let notifications = TestUsageAlertNotifications(status: .authorized)
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)

    _ = await controller.evaluate(windows: [alertWindow(used: 70, reset: Date(timeIntervalSince1970: 1_200))], isFresh: true, observedAt: Date(timeIntervalSince1970: 1_000))
    #expect(!(await controller.evaluate(windows: [alertWindow(used: 20, reset: Date(timeIntervalSince1970: 1_400))], isFresh: true, observedAt: Date(timeIntervalSince1970: 1_100))))
    #expect(!(await controller.evaluate(windows: [alertWindow(used: 5, reset: Date(timeIntervalSince1970: 1_400))], isFresh: true, observedAt: Date(timeIntervalSince1970: 1_150))))
    #expect(await notifications.snapshot().deliveries.isEmpty)
}

@Test @MainActor func resetAlertRebaselinesInvalidMissingAndChangedDurationButIgnoresStaleGap() async throws {
    let defaults = try #require(UserDefaults(suiteName: "UsageGridTests.Alerts.ResetMetadata.\(UUID())"))
    let preferences = UsageAlertPreferences(defaults: defaults); preferences.primaryResetEnabled = true
    let notifications = TestUsageAlertNotifications(status: .authorized)
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)

    _ = await controller.evaluate(windows: [alertWindow(used: 60, reset: Date(timeIntervalSince1970: 1_100))], isFresh: true, observedAt: Date(timeIntervalSince1970: 1_000))
    _ = await controller.evaluate(windows: nil, isFresh: false, observedAt: Date(timeIntervalSince1970: 1_200))
    #expect(await controller.evaluate(windows: [alertWindow(used: 10, reset: Date(timeIntervalSince1970: 1_500))], isFresh: true, observedAt: Date(timeIntervalSince1970: 1_201)))

    #expect(!(await controller.evaluate(windows: [alertWindow(used: 10, reset: nil)], isFresh: true, observedAt: Date(timeIntervalSince1970: 1_202))))
    #expect(!(await controller.evaluate(windows: [alertWindow(used: 10, reset: Date(timeIntervalSince1970: 1_800), duration: 300)], isFresh: true, observedAt: Date(timeIntervalSince1970: 1_600))))
    #expect(!(await controller.evaluate(windows: [alertWindow(used: 10, reset: Date(timeIntervalSince1970: 2_200), duration: 180)], isFresh: true, observedAt: Date(timeIntervalSince1970: 1_900))))
    #expect(await notifications.snapshot().deliveries.count == 1)
}

@Test @MainActor func resetAlertsAreIndependentAndRestartDoesNotCatchUp() async throws {
    let suite = "UsageGridTests.Alerts.ResetWindows.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
    var preferences = UsageAlertPreferences(defaults: defaults)
    preferences.primaryResetEnabled = true; preferences.secondaryResetEnabled = true
    let notifications = TestUsageAlertNotifications(status: .authorized)
    var controller = UsageAlertController(preferences: preferences, notifications: notifications)
    let first = [alertWindow(used: 60, reset: Date(timeIntervalSince1970: 1_100)), alertWindow(used: 50, reset: Date(timeIntervalSince1970: 2_000), id: "secondary", duration: 10_080, label: "Weekly limit")]
    _ = await controller.evaluate(windows: first, isFresh: true, observedAt: Date(timeIntervalSince1970: 1_000))
    let rolled = [alertWindow(used: 5, reset: Date(timeIntervalSince1970: 1_500)), first[1]]
    #expect(await controller.evaluate(windows: rolled, isFresh: true, observedAt: Date(timeIntervalSince1970: 1_101)))
    #expect(await notifications.snapshot().deliveries.count == 1)

    preferences = UsageAlertPreferences(defaults: defaults)
    controller = UsageAlertController(preferences: preferences, notifications: notifications)
    let bothLater = [alertWindow(used: 4, reset: Date(timeIntervalSince1970: 1_800)), alertWindow(used: 3, reset: Date(timeIntervalSince1970: 3_000), id: "secondary", duration: 10_080, label: "Weekly limit")]
    #expect(!(await controller.evaluate(windows: bothLater, isFresh: true, observedAt: Date(timeIntervalSince1970: 2_100))))
    #expect(await notifications.snapshot().deliveries.count == 1)
}

@Test @MainActor func resetAlertDisableReenableAndPermissionDenialDoNotReplay() async throws {
    let defaults = try #require(UserDefaults(suiteName: "UsageGridTests.Alerts.ResetAccess.\(UUID())"))
    let preferences = UsageAlertPreferences(defaults: defaults)
    let notifications = TestUsageAlertNotifications(status: .authorized)
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)
    await controller.setPrimaryResetEnabled(true)
    _ = await controller.evaluate(windows: [alertWindow(used: 60, reset: Date(timeIntervalSince1970: 1_100))], isFresh: true, observedAt: Date(timeIntervalSince1970: 1_000))
    await controller.setPrimaryResetEnabled(false)
    await controller.setPrimaryResetEnabled(true)
    #expect(!(await controller.evaluate(windows: [alertWindow(used: 5, reset: Date(timeIntervalSince1970: 1_500))], isFresh: true, observedAt: Date(timeIntervalSince1970: 1_200))))
    #expect(preferences.primaryResetEnabled)

    let denied = TestUsageAlertNotifications(status: .denied)
    let deniedPreferences = UsageAlertPreferences(defaults: try #require(UserDefaults(suiteName: "UsageGridTests.Alerts.ResetDenied.\(UUID())")))
    let deniedController = UsageAlertController(preferences: deniedPreferences, notifications: denied)
    await deniedController.setSecondaryResetEnabled(true)
    #expect(!deniedPreferences.secondaryResetEnabled)
    #expect(await denied.snapshot().requestCount == 0)
}

@Test @MainActor func resetAlertPermissionRefreshCannotOverwriteNewerChoice() async throws {
    let defaults = try #require(UserDefaults(suiteName: "UsageGridTests.Alerts.ResetPermissionRace.\(UUID())"))
    let preferences = UsageAlertPreferences(defaults: defaults)
    let notifications = TestUsageAlertNotifications(status: .denied, permissionStatusDelays: [.milliseconds(80), .zero])
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)
    let staleRefresh = Task { await controller.refreshPermissionStatus() }
    try? await Task.sleep(for: .milliseconds(10))
    await notifications.setStatus(.authorized)
    await controller.setPrimaryResetEnabled(true)
    await staleRefresh.value
    #expect(preferences.primaryResetEnabled)
    #expect(controller.permissionStatus == .authorized)
    #expect(!preferences.secondaryResetEnabled)
}

@Test @MainActor func resetDeliveryFailureDeduplicatesSeparatelyFromThresholdReceipt() async throws {
    let defaults = try #require(UserDefaults(suiteName: "UsageGridTests.Alerts.ResetFailure.\(UUID())"))
    let preferences = UsageAlertPreferences(defaults: defaults)
    preferences.enabled = true; preferences.primaryResetEnabled = true
    let notifications = TestUsageAlertNotifications(status: .authorized, failDelivery: true)
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)
    let firstReset = Date(timeIntervalSince1970: 1_100)
    _ = await controller.evaluate(windows: [alertWindow(used: 95, reset: firstReset)], isFresh: true, observedAt: Date(timeIntervalSince1970: 1_000))
    let thresholdReceipt = preferences.lastAlertedWindow
    let newWindow = alertWindow(used: 10, reset: Date(timeIntervalSince1970: 1_500))
    #expect(!(await controller.evaluate(windows: [newWindow], isFresh: true, observedAt: Date(timeIntervalSince1970: 1_101))))
    #expect(!(await controller.evaluate(windows: [newWindow], isFresh: true, observedAt: Date(timeIntervalSince1970: 1_102))))
    #expect(preferences.lastAlertedWindow == thresholdReceipt)
    #expect(preferences.lastPrimaryResetNotification != nil)
    #expect(await notifications.snapshot().deliveries.count == 2)
}

@Test @MainActor func testNotificationDeliversWithPermissionWithoutChangingAlertState() async throws {
    let suiteName = "UsageGridTests.TestNotification.Allowed.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preferences = UsageAlertPreferences(defaults: defaults)
    preferences.enabled = false
    preferences.threshold = .ninetyFive
    preferences.lastAlertedWindow = "existing-reset-window"
    let notifications = TestUsageAlertNotifications(status: .authorized)
    let controller = UsageAlertController(preferences: preferences, notifications: notifications)
    await controller.refreshPermissionStatus()

    #expect(await controller.sendTestNotification(cooldown: .milliseconds(20)))
    let snapshot = await notifications.snapshot()
    #expect(snapshot.deliveries.count == 1)
    #expect(snapshot.deliveries[0].title == "UsageGrid test notification")
    #expect(snapshot.deliveries[0].body == "Notifications are working. Usage alerts will warn you when your selected threshold is reached.")
    #expect(controller.testNotificationMessage == "Test notification requested")
    #expect(!preferences.enabled)
    #expect(preferences.threshold == .ninetyFive)
    #expect(preferences.lastAlertedWindow == "existing-reset-window")
}

@Test @MainActor func testNotificationDoesNotRequestOrDeliverWithoutPermission() async throws {
    let suiteName = "UsageGridTests.TestNotification.Denied.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let notifications = TestUsageAlertNotifications(status: .denied)
    let controller = UsageAlertController(preferences: UsageAlertPreferences(defaults: defaults), notifications: notifications)
    await controller.refreshPermissionStatus()

    #expect(!controller.canSendTestNotification)
    #expect(!(await controller.sendTestNotification()))
    let snapshot = await notifications.snapshot()
    #expect(snapshot.requestCount == 0)
    #expect(snapshot.deliveries.isEmpty)
    #expect(controller.testNotificationMessage?.contains("permission") == true)
}

@Test @MainActor func testNotificationContainsErrorsAndPreventsRepeatedClicks() async throws {
    let suiteName = "UsageGridTests.TestNotification.Failure.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let notifications = TestUsageAlertNotifications(status: .authorized, failDelivery: true, deliveryDelay: .milliseconds(50))
    let controller = UsageAlertController(preferences: UsageAlertPreferences(defaults: defaults), notifications: notifications)
    await controller.refreshPermissionStatus()

    let first = Task { await controller.sendTestNotification(cooldown: .seconds(1)) }
    try? await Task.sleep(for: .milliseconds(10))
    #expect(!(await controller.sendTestNotification(cooldown: .seconds(1))))
    #expect(!(await first.value))
    #expect(controller.testNotificationMessage == "Couldn’t request the test notification.")
    #expect(!(await controller.sendTestNotification(cooldown: .seconds(1))))
    #expect(await notifications.snapshot().deliveries.count == 1)
}

@Test func codexSetupStateMapsReaderResultsWithoutGuessing() {
    var state = CodexRefreshState()
    #expect(CodexSetupState.from(state) == .connecting)

    let failures: [(CodexUsageReadError, CodexSetupState)] = [
        (.executableNotFound, .executableNotFound),
        (.authenticationRequired, .authenticationRequired),
        (.usageUnavailable, .usageUnavailable),
        (.decodingFailed, .usageUnavailable),
        (.unsupportedResponse, .unsupportedResponse)
    ]
    for (error, expected) in failures {
        state = CodexRefreshState()
        let started = state.start()
        #expect(started)
        state.finish(with: .failure(error), at: Date(timeIntervalSince1970: 1_000))
        #expect(CodexSetupState.from(state) == expected)
    }

    for error in [CodexUsageReadError.initializationTimedOut, .requestTimedOut, .requestFailed, .processLaunchFailed] {
        state = CodexRefreshState()
        let started = state.start()
        #expect(started)
        state.finish(with: .failure(error), at: Date(timeIntervalSince1970: 1_000))
        guard case .connectionFailure = CodexSetupState.from(state) else {
            Issue.record("Expected connection failure for \(error)")
            continue
        }
    }
}

@Test func codexSetupTransitionsDirectlyToUsageAfterFirstSuccess() {
    var state = CodexRefreshState()
    #expect(CodexSetupState.from(state) == .connecting)
    let started = state.start()
    #expect(started)
    state.finish(
        with: .success([CodexUsageWindow(id: "primary", label: "3-hour limit", usedPercentage: 42, resetText: "Resets later", durationMinutes: 180)]),
        at: Date(timeIntervalSince1970: 1_000)
    )

    #expect(CodexSetupState.from(state) == nil)
    #expect(state.windows?.first?.usedPercentage == 42)
}

@Test func codexSetupShowsUnavailableForSuccessfulResponseWithoutUsageWindows() {
    var state = CodexRefreshState()
    let started = state.start()
    #expect(started)
    state.finish(with: .success([]), at: Date(timeIntervalSince1970: 1_000))

    #expect(CodexSetupState.from(state) == .usageUnavailable)
    #expect(state.windows?.isEmpty == true)
}

@Test func codexSetupDoesNotReplaceStaleUsageAfterLaterFailure() {
    var state = CodexRefreshState()
    let firstStarted = state.start()
    #expect(firstStarted)
    state.finish(
        with: .success([CodexUsageWindow(id: "primary", label: "3-hour limit", usedPercentage: 42, resetText: "Resets later", durationMinutes: 180)]),
        at: Date(timeIntervalSince1970: 1_000)
    )
    let refreshStarted = state.start()
    #expect(refreshStarted)
    state.finish(with: .failure(.authenticationRequired), at: Date(timeIntervalSince1970: 2_000))

    #expect(CodexSetupState.from(state) == nil)
    #expect(state.isStale)
    #expect(state.windows?.first?.usedPercentage == 42)
    #expect(state.lastUpdated == Date(timeIntervalSince1970: 1_000))
}

private func historySample(_ minute: Int, used: Double, window: UsageHistoryWindow = .primary,
                           reset: TimeInterval = 10_000, run: UUID) -> UsageHistorySample {
    UsageHistorySample(observedAt: Date(timeIntervalSince1970: Double(minute * 60)), window: window,
                       durationMinutes: window == .primary ? 180 : 10_080,
                       resetsAt: Date(timeIntervalSince1970: reset), usedPercentage: used, processRunID: run)
}

@Test @MainActor func historyOptInCollectsOnlyUsableSuccessfulWindows() async throws {
    let suite = "UsageGridTests.History.OptIn.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
    let store = TestHistoryStore()
    let now = Date(timeIntervalSince1970: 1_000)
    let controller = UsageHistoryController(defaults: defaults, store: store, now: { now })
    let valid = CodexUsageWindow(id: "primary", label: "3-hour", usedPercentage: 42, resetText: "later", durationMinutes: 180, resetsAt: Date(timeIntervalSince1970: 2_000))
    let missingReset = CodexUsageWindow(id: "secondary", label: "weekly", usedPercentage: 10, resetText: "unknown", durationMinutes: 10_080)

    await controller.record(windows: [valid], observedAt: now)
    #expect(controller.samples.isEmpty)
    controller.isRecording = true
    await controller.record(windows: [valid, missingReset], observedAt: now)
    #expect(controller.samples.count == 1)
    #expect(controller.samples.first?.window == .primary)
    #expect(defaults.bool(forKey: UsageHistoryController.recordingKey))
}

@Test func historyRetentionCapAndPersistence() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("history.json")
    let store = UsageHistoryStore(fileURL: url)
    let now = Date(timeIntervalSince1970: 2_000_000)
    let run = UUID()
    var values = (0...25_010).map { index in
        UsageHistorySample(observedAt: now.addingTimeInterval(Double(index - 25_010)), window: .primary,
                           durationMinutes: 180, resetsAt: now.addingTimeInterval(10_000),
                           usedPercentage: Double(index % 101), processRunID: run)
    }
    values.append(UsageHistorySample(observedAt: now.addingTimeInterval(-UsageHistoryMath.retention - 1), window: .secondary,
                                     durationMinutes: 10_080, resetsAt: now, usedPercentage: 1, processRunID: run))
    let retained = UsageHistoryMath.retained(values, now: now)
    #expect(retained.count == 25_000)
    try await store.save(retained, generation: 0)
    let loaded = try await store.load(now: now)
    #expect(loaded.map(\.observedAt) == retained.map(\.observedAt))
    #expect(loaded.map(\.usedPercentage) == retained.map(\.usedPercentage))
    let document = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let object = try #require(document["samples"] as? [[String: Any]])
    let boundaries = try #require(document["segmentStarts"] as? [[String: Any]])
    #expect(Set(object[0].keys) == ["observedAt", "window", "durationMinutes", "resetsAt", "usedPercentage"])
    #expect(boundaries.allSatisfy { Set($0.keys) == ["observedAt", "window"] })
}

@Test func persistedHistoryRetainsProcessAndMissingWindowBoundaries() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = UsageHistoryStore(fileURL: directory.appendingPathComponent("history.json"))
    let run1 = UUID(), run2 = UUID()
    let values = [historySample(1, used: 10, run: run1), historySample(2, used: 12, run: run1), historySample(3, used: 14, run: run2)]
    try await store.save(values, generation: 0)
    let loaded = try await store.load(now: Date(timeIntervalSince1970: 1_000))
    #expect(UsageHistoryMath.segments(loaded, window: .primary).map(\.samples.count) == [2, 1])
}

@Test func popupPreviewNavigationAlwaysReturnsToUsage() {
    var state = PopupPresentationState()
    #expect(state.page == .usage)
    state.showHistoryPreview(); #expect(state.page == .historyPreview)
    state.showUsage(); #expect(state.page == .usage)
    state.showHistoryPreview(); state.popupDismissed()
    #expect(state.page == .usage)
}

@Test func popupRootHeightIsStableAndScreenBounded() {
    #expect(PopupSizing.height(availableScreenHeight: 900) == 640)
    #expect(PopupSizing.height(availableScreenHeight: 500) == 468)
    #expect(PopupSizing.height(availableScreenHeight: 360) == 328)
    #expect(PopupSizing.height(availableScreenHeight: 192) == 160)

    let loadingHeight = PopupSizing.height(availableScreenHeight: 500)
    let successfulUsageHeight = PopupSizing.height(availableScreenHeight: 500)
    #expect(loadingHeight == successfulUsageHeight)
}

@Test func popupKeepsHistoryUntilDismissed() {
    var state = PopupPresentationState()
    state.showHistory()
    #expect(state.page == .history)
    state.popupDismissed()
    #expect(state.page == .usage)

    state.showHistoryPreview()
    #expect(state.page == .historyPreview)
}

@Test @MainActor func missingWindowObservationBreaksSessionComparison() async throws {
    let defaults = try #require(UserDefaults(suiteName: "UsageGridTests.History.Missing.\(UUID())"))
    let controller = UsageHistoryController(defaults: defaults, store: TestHistoryStore())
    controller.isRecording = true
    let reset = Date(timeIntervalSince1970: 10_000)
    func window(_ id: String, _ used: Double) -> CodexUsageWindow {
        CodexUsageWindow(id: id, label: id, usedPercentage: used, resetText: "later", durationMinutes: id == "primary" ? 180 : 10_080, resetsAt: reset)
    }
    await controller.record(windows: [window("primary", 10)], observedAt: Date(timeIntervalSince1970: 1_000))
    await controller.record(windows: [window("secondary", 20)], observedAt: Date(timeIntervalSince1970: 1_060))
    await controller.record(windows: [window("primary", 15)], observedAt: Date(timeIntervalSince1970: 1_120))
    #expect(controller.session.change == nil)
    #expect(UsageHistoryMath.segments(controller.samples, window: .primary).count == 2)
}

@Test func corruptHistoryAndWriteFailuresAreReportedWithoutLiveDataImpact() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("history.json")
    try Data("not-json".utf8).write(to: url)
    do { _ = try await UsageHistoryStore(fileURL: url).load(now: Date()); Issue.record("Expected corrupt file failure") }
    catch { }

    let defaults = try #require(UserDefaults(suiteName: "UsageGridTests.History.Error.\(UUID())"))
    let fake = TestHistoryStore(); await fake.setFailSave(true)
    let controller = await UsageHistoryController(defaults: defaults, store: fake, now: { Date(timeIntervalSince1970: 1_000) })
    await MainActor.run { controller.isRecording = true }
    let window = CodexUsageWindow(id: "primary", label: "3-hour", usedPercentage: 42, resetText: "later", durationMinutes: 180, resetsAt: Date(timeIntervalSince1970: 2_000))
    await controller.record(windows: [window], observedAt: Date(timeIntervalSince1970: 1_000))
    #expect(await controller.samples.count == 1)
    #expect(await controller.storageError?.contains("could not be saved") == true)
}

@Test func historySegmentationSeparatesWindowsRestartsResetsGapsAndDecreases() {
    let run1 = UUID(), run2 = UUID()
    let values = [
        historySample(1, used: 10, run: run1), historySample(2, used: 12, run: run1),
        historySample(6, used: 14, run: run1),
        historySample(7, used: 15, run: run2),
        historySample(8, used: 9, run: run2),
        historySample(9, used: 11, reset: 20_000, run: run2),
        historySample(10, used: 30, window: .secondary, run: run1)
    ]
    let primary = UsageHistoryMath.segments(values, window: .primary)
    #expect(primary.map(\.samples.count) == [2, 1, 1, 1, 1])
    #expect(UsageHistoryMath.segments(values, window: .secondary).count == 1)
}

@Test func sessionBaselineRequiresContinuousComparisonAndUsesPercentagePoints() {
    let run = UUID(); var tracker = UsageSessionTracker()
    tracker.observe(historySample(1, used: 20, run: run)); #expect(tracker.change == nil)
    tracker.observe(historySample(2, used: 32, run: run))
    #expect(tracker.change?.percentagePoints == 12)
    #expect(tracker.change?.since == Date(timeIntervalSince1970: 60))
    tracker.observe(historySample(6, used: 35, run: run)); #expect(tracker.change == nil)
    tracker.observe(historySample(7, used: 30, run: run)); #expect(tracker.change == nil)
}

@Test @MainActor func disablingReenablingAndClearingResetSessionAndPreventOldWrites() async throws {
    let defaults = try #require(UserDefaults(suiteName: "UsageGridTests.History.Clear.\(UUID())"))
    let store = TestHistoryStore(); let controller = UsageHistoryController(defaults: defaults, store: store)
    controller.isRecording = true
    let first = CodexUsageWindow(id: "primary", label: "3-hour", usedPercentage: 10, resetText: "later", durationMinutes: 180, resetsAt: Date(timeIntervalSinceNow: 3_600))
    await controller.record(windows: [first], observedAt: Date())
    controller.isRecording = false; controller.isRecording = true
    #expect(controller.session.change == nil)
    await controller.clear()
    #expect(controller.samples.isEmpty)
    let old = historySample(1, used: 1, run: UUID())
    try await store.save([old], generation: 0)
    #expect(await store.snapshot().isEmpty)
}

@Test @MainActor func historyPreviewIsIsolatedAndRendersAcrossSixThemes() {
    #expect(UsageHistoryPreviewSheet.sampleData.count == 6)
    for theme in UsageTheme.all {
        let palette = UsageThemePalette(theme: theme, colorScheme: .dark)
        for samples in [UsageHistoryPreviewSheet.sampleData, Array(UsageHistoryPreviewSheet.sampleData.prefix(1)), []] {
            let renderer = ImageRenderer(content: UsageHistoryChartView(samples: samples, selection: .primary, palette: palette, isRecording: true, storageError: nil, isSample: true).frame(width: 440))
            #expect(renderer.cgImage != nil)
        }
    }
}

@Test @MainActor func exportHistoryPreviewsWhenRequested() throws {
    guard let path = ProcessInfo.processInfo.environment["USAGEGRID_HISTORY_PREVIEW_DIR"] else { return }
    let directory = URL(fileURLWithPath: path, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for theme in UsageTheme.all {
        let palette = UsageThemePalette(theme: theme, colorScheme: .dark)
        let renderer = ImageRenderer(content: UsageHistoryExportPreview(theme: theme, palette: palette))
        renderer.scale = 2; renderer.proposedSize = ProposedViewSize(width: 940, height: 610)
        let image = try #require(renderer.cgImage)
        let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try data.write(to: directory.appendingPathComponent("\(theme.id.rawValue)-history-preview.png"))
    }
}

@Test @MainActor func exportContainerLayoutChecksWhenRequested() throws {
    guard let path = ProcessInfo.processInfo.environment["USAGEGRID_UI_FIX_PREVIEW_DIR"] else { return }
    let directory = URL(fileURLWithPath: path, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let theme = UsageTheme.lookup("retro")

    func write<V: View>(_ name: String, size: CGSize, @ViewBuilder content: () -> V) throws {
        let renderer = ImageRenderer(content: content().frame(width: size.width, height: size.height, alignment: .top))
        renderer.scale = 2; renderer.proposedSize = ProposedViewSize(size)
        let image = try #require(renderer.cgImage)
        let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try data.write(to: directory.appendingPathComponent(name))
    }

    try write("history-popup-default.png", size: CGSize(width: 350, height: 500)) {
        UsageHistoryPreviewContent(theme: theme, closeTitle: "Back to usage", close: {})
    }
    try write("history-popup-enlarged.png", size: CGSize(width: 350, height: 500)) {
        UsageHistoryPreviewContent(theme: theme, closeTitle: "Back to usage", close: {})
            .environment(\.dynamicTypeSize, .accessibility2)
    }
    try write("theme-sheet-small.png", size: CGSize(width: 440, height: 420)) {
        ThemePreviewSheet(theme: theme)
    }
    try write("theme-sheet-enlarged.png", size: CGSize(width: 500, height: 520)) {
        ThemePreviewSheet(theme: theme).environment(\.dynamicTypeSize, .accessibility2)
    }
}

#if DEBUG
@Test @MainActor func combinedLiveAndHistoryPanelRendersAcrossAllThemesAndHeights() throws {
    let outputDirectory = ProcessInfo.processInfo.environment["USAGEGRID_COMBINED_PANEL_DIR"].map {
        URL(fileURLWithPath: $0, isDirectory: true)
    }
    if let outputDirectory {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    for theme in UsageTheme.all {
        let palette = UsageThemePalette(theme: theme, colorScheme: .dark)
        for constrained in [false, true] {
            let size = CGSize(width: 350, height: constrained ? 400 : 620)
            let renderer = ImageRenderer(content: CombinedPanelFixtureView(theme: theme, constrained: constrained, palette: palette))
            renderer.scale = 2
            renderer.proposedSize = ProposedViewSize(size)
            let image = try #require(renderer.cgImage)
            guard let outputDirectory else { continue }
            let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            let suffix = constrained ? "constrained" : "default"
            try data.write(to: outputDirectory.appendingPathComponent("\(theme.id.rawValue)-combined-\(suffix).png"))
        }
    }

    let defaultsName = "UsageGridTests.History.Enlarged.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: defaultsName))
    defer { defaults.removePersistentDomain(forName: defaultsName) }
    let history = UsageHistoryController(defaults: defaults, store: TestHistoryStore())
    let enlarged = RealUsageHistoryContent(
        theme: UsageTheme.lookup(UsageThemeID.retro.rawValue),
        history: history,
        isFresh: true,
        close: {},
        openRecordingSettings: {}
    )
    .environment(\.dynamicTypeSize, .accessibility2)
    .frame(width: 350, height: 400, alignment: .top)
    let enlargedRenderer = ImageRenderer(content: enlarged)
    enlargedRenderer.scale = 2
    enlargedRenderer.proposedSize = ProposedViewSize(width: 350, height: 400)
    let enlargedImage = try #require(enlargedRenderer.cgImage)
    if let outputDirectory {
        let data = try #require(NSBitmapImageRep(cgImage: enlargedImage).representation(using: .png, properties: [:]))
        try data.write(to: outputDirectory.appendingPathComponent("retro-history-enlarged.png"))
    }
}
#endif
