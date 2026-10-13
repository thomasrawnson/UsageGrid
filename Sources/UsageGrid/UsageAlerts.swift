import AppKit
import Foundation
import Observation
import OSLog
import UserNotifications

enum UsageAlertThreshold: Int, CaseIterable, Identifiable {
    case eighty = 80
    case ninety = 90
    case ninetyFive = 95

    var id: Int { rawValue }
    var title: String { "\(rawValue)% used" }
}

enum UsageAlertPermissionStatus: Equatable {
    case notDetermined
    case authorized
    case denied
    case unavailable
}

struct UsageAlertNotification: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
}

protocol UsageAlertNotificationProviding: Sendable {
    func permissionStatus() async -> UsageAlertPermissionStatus
    func requestPermission() async throws -> Bool
    func deliver(_ notification: UsageAlertNotification) async throws
}

struct SystemUsageAlertNotifications: UsageAlertNotificationProviding {
    private static let logger = Logger(subsystem: "com.plutonightlabs.UsageGrid", category: "UsageAlerts")

    func permissionStatus() async -> UsageAlertPermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        Self.logger.info("Notification settings checked: authorization=\(String(describing: settings.authorizationStatus), privacy: .public), alerts=\(String(describing: settings.alertSetting), privacy: .public), centre=\(String(describing: settings.notificationCenterSetting), privacy: .public)")
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .authorized, .provisional, .ephemeral: return .authorized
        case .denied: return .denied
        @unknown default: return .unavailable
        }
    }

    func requestPermission() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
    }

    func deliver(_ notification: UsageAlertNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        let request = UNNotificationRequest(identifier: notification.identifier, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
            Self.logger.info("Notification request submitted successfully; kind=\(notificationKind(notification.identifier), privacy: .public)")
        } catch {
            Self.logger.error("Notification request submission failed; kind=\(notificationKind(notification.identifier), privacy: .public), domain=\((error as NSError).domain, privacy: .public), code=\((error as NSError).code)")
            throw error
        }
    }

    private func notificationKind(_ identifier: String) -> String {
        if identifier.hasPrefix("usagegrid.test.") { return "test" }
        if identifier.hasPrefix("usagegrid.codex.reset.") { return "reset" }
        return "threshold"
    }
}

@Observable
final class UsageAlertPreferences {
    static let enabledKey = "usageAlertsEnabled"
    static let thresholdKey = "usageAlertsThreshold"
    static let lastAlertedWindowKey = "usageAlertsLastPrimaryResetWindow"
    static let secondaryEnabledKey = "usageAlertsSecondaryEnabled"
    static let secondaryThresholdKey = "usageAlertsSecondaryThreshold"
    static let lastAlertedSecondaryWindowKey = "usageAlertsLastSecondaryResetWindow"
    static let primaryResetEnabledKey = "usageAlertsPrimaryResetEnabled"
    static let secondaryResetEnabledKey = "usageAlertsSecondaryResetEnabled"
    static let lastPrimaryResetNotificationKey = "usageAlertsLastPrimaryResetNotification"
    static let lastSecondaryResetNotificationKey = "usageAlertsLastSecondaryResetNotification"

    private let defaults: UserDefaults

    var enabled: Bool {
        didSet { defaults.set(enabled, forKey: Self.enabledKey) }
    }

    var threshold: UsageAlertThreshold {
        didSet { defaults.set(threshold.rawValue, forKey: Self.thresholdKey) }
    }

    var lastAlertedWindow: String? {
        didSet { defaults.set(lastAlertedWindow, forKey: Self.lastAlertedWindowKey) }
    }

    var secondaryEnabled: Bool {
        didSet { defaults.set(secondaryEnabled, forKey: Self.secondaryEnabledKey) }
    }

    var secondaryThreshold: UsageAlertThreshold {
        didSet { defaults.set(secondaryThreshold.rawValue, forKey: Self.secondaryThresholdKey) }
    }

    var lastAlertedSecondaryWindow: String? {
        didSet { defaults.set(lastAlertedSecondaryWindow, forKey: Self.lastAlertedSecondaryWindowKey) }
    }

    var primaryResetEnabled: Bool {
        didSet { defaults.set(primaryResetEnabled, forKey: Self.primaryResetEnabledKey) }
    }

    var secondaryResetEnabled: Bool {
        didSet { defaults.set(secondaryResetEnabled, forKey: Self.secondaryResetEnabledKey) }
    }

    var lastPrimaryResetNotification: String? {
        didSet { defaults.set(lastPrimaryResetNotification, forKey: Self.lastPrimaryResetNotificationKey) }
    }

    var lastSecondaryResetNotification: String? {
        didSet { defaults.set(lastSecondaryResetNotification, forKey: Self.lastSecondaryResetNotificationKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.bool(forKey: Self.enabledKey)
        threshold = UsageAlertThreshold(rawValue: defaults.integer(forKey: Self.thresholdKey)) ?? .ninety
        lastAlertedWindow = defaults.string(forKey: Self.lastAlertedWindowKey)
        secondaryEnabled = defaults.bool(forKey: Self.secondaryEnabledKey)
        secondaryThreshold = UsageAlertThreshold(rawValue: defaults.integer(forKey: Self.secondaryThresholdKey)) ?? .ninety
        lastAlertedSecondaryWindow = defaults.string(forKey: Self.lastAlertedSecondaryWindowKey)
        primaryResetEnabled = defaults.bool(forKey: Self.primaryResetEnabledKey)
        secondaryResetEnabled = defaults.bool(forKey: Self.secondaryResetEnabledKey)
        lastPrimaryResetNotification = defaults.string(forKey: Self.lastPrimaryResetNotificationKey)
        lastSecondaryResetNotification = defaults.string(forKey: Self.lastSecondaryResetNotificationKey)
    }
}

@MainActor
@Observable
final class UsageAlertController {
    let preferences: UsageAlertPreferences
    private let notifications: any UsageAlertNotificationProviding
    private let hasEffectiveProAccess: @MainActor () -> Bool

    private(set) var permissionStatus: UsageAlertPermissionStatus = .notDetermined
    private(set) var deliveryError: String?
    private(set) var testNotificationMessage: String?
    private(set) var isSendingTestNotification = false
    private(set) var isTestNotificationCoolingDown = false
    @ObservationIgnored private var testCooldownTask: Task<Void, Never>?
    @ObservationIgnored private var permissionRefreshRevision = 0
    @ObservationIgnored private var userActionRevision = 0
    @ObservationIgnored private var resetBaselines: [AlertWindow: ResetBaseline] = [:]

    init(
        preferences: UsageAlertPreferences = UsageAlertPreferences(),
        notifications: any UsageAlertNotificationProviding = SystemUsageAlertNotifications(),
        hasEffectiveProAccess: @escaping @MainActor () -> Bool = { false }
    ) {
        self.preferences = preferences
        self.notifications = notifications
        self.hasEffectiveProAccess = hasEffectiveProAccess
    }

    var permissionMessage: String {
        switch permissionStatus {
        case .authorized: hasAnyEnabledAlert ? "Alerts active for enabled usage windows." : "Notifications allowed; usage alerts are off."
        case .denied: "Notifications are denied. Enable them for UsageGrid in System Settings."
        case .notDetermined: hasAnyEnabledAlert ? "Checking notification permission…" : "Permission will be requested only when alerts are enabled."
        case .unavailable: "Notification permission is unavailable."
        }
    }

    var canSendTestNotification: Bool {
        permissionStatus == .authorized && !isSendingTestNotification && !isTestNotificationCoolingDown
    }

    func refreshPermissionStatus() async {
        permissionRefreshRevision += 1
        let refreshRevision = permissionRefreshRevision
        let actionRevision = userActionRevision
        let status = await notifications.permissionStatus()
        guard refreshRevision == permissionRefreshRevision,
              actionRevision == userActionRevision else { return }
        permissionStatus = status
    }

    func setEnabled(_ enabled: Bool) async {
        await setEnabled(enabled, for: .primary)
    }

    func setSecondaryEnabled(_ enabled: Bool) async {
        await setEnabled(enabled, for: .secondary)
    }

    func setPrimaryResetEnabled(_ enabled: Bool) async {
        await setResetEnabled(enabled, for: .primary)
    }

    func setSecondaryResetEnabled(_ enabled: Bool) async {
        await setResetEnabled(enabled, for: .secondary)
    }

    private func setEnabled(_ enabled: Bool, for window: AlertWindow) async {
        userActionRevision += 1
        let actionRevision = userActionRevision
        deliveryError = nil
        guard enabled else {
            setPreference(false, for: window)
            return
        }
        guard window != .secondary || hasEffectiveProAccess() else { return }

        let status = await notifications.permissionStatus()
        guard actionRevision == userActionRevision else { return }
        guard window != .secondary || hasEffectiveProAccess() else { return }
        switch status {
        case .authorized:
            permissionStatus = .authorized
            setPreference(true, for: window)
        case .denied:
            permissionStatus = .denied
            setPreference(false, for: window)
        case .unavailable:
            permissionStatus = .unavailable
            setPreference(false, for: window)
        case .notDetermined:
            do {
                let granted = try await notifications.requestPermission()
                guard actionRevision == userActionRevision else { return }
                guard window != .secondary || hasEffectiveProAccess() else { return }
                permissionStatus = granted ? .authorized : .denied
                setPreference(granted, for: window)
            } catch {
                let currentStatus = await notifications.permissionStatus()
                guard actionRevision == userActionRevision else { return }
                permissionStatus = currentStatus
                setPreference(false, for: window)
                deliveryError = "Couldn’t request notification permission."
            }
        }
    }

    private func setResetEnabled(_ enabled: Bool, for window: AlertWindow) async {
        userActionRevision += 1
        let actionRevision = userActionRevision
        deliveryError = nil
        resetBaselines[window] = nil
        guard enabled else {
            setResetPreference(false, for: window)
            return
        }
        guard hasEffectiveProAccess() else { return }

        let status = await notifications.permissionStatus()
        guard actionRevision == userActionRevision, hasEffectiveProAccess() else { return }
        switch status {
        case .authorized:
            permissionStatus = .authorized
            setResetPreference(true, for: window)
        case .denied:
            permissionStatus = .denied
            setResetPreference(false, for: window)
        case .unavailable:
            permissionStatus = .unavailable
            setResetPreference(false, for: window)
        case .notDetermined:
            do {
                let granted = try await notifications.requestPermission()
                guard actionRevision == userActionRevision, hasEffectiveProAccess() else { return }
                permissionStatus = granted ? .authorized : .denied
                setResetPreference(granted, for: window)
            } catch {
                let currentStatus = await notifications.permissionStatus()
                guard actionRevision == userActionRevision else { return }
                permissionStatus = currentStatus
                setResetPreference(false, for: window)
                deliveryError = "Couldn’t request notification permission."
            }
        }
    }

    @discardableResult
    func sendTestNotification(cooldown: Duration = .seconds(2)) async -> Bool {
        guard !isSendingTestNotification, !isTestNotificationCoolingDown else { return false }
        let actionRevision = userActionRevision
        let currentPermission = await notifications.permissionStatus()
        if actionRevision == userActionRevision { permissionStatus = currentPermission }
        guard currentPermission == .authorized else {
            testNotificationMessage = "Notification permission is required to send a test."
            return false
        }

        isSendingTestNotification = true
        testNotificationMessage = nil
        let notification = UsageAlertNotification(
            identifier: "usagegrid.test.\(UUID().uuidString)",
            title: "UsageGrid test notification",
            body: "Notifications are working. Usage alerts will warn you when your selected threshold is reached."
        )

        let submitted: Bool
        do {
            try await notifications.deliver(notification)
            testNotificationMessage = "Test notification requested"
            submitted = true
        } catch {
            testNotificationMessage = "Couldn’t request the test notification."
            submitted = false
        }
        isSendingTestNotification = false
        beginTestCooldown(cooldown)
        return submitted
    }

    @discardableResult
    func evaluate(windows: [CodexUsageWindow]?, isFresh: Bool, observedAt: Date = Date()) async -> Bool {
        guard isFresh, let windows else { return false }
        var delivered = false
        if preferences.enabled, let primary = windows.first(where: { $0.id == AlertWindow.primary.rawValue }) {
            delivered = await evaluate(primary, as: .primary, observedAt: observedAt) || delivered
        }
        if hasEffectiveProAccess(), preferences.secondaryEnabled,
           let secondary = windows.first(where: { $0.id == AlertWindow.secondary.rawValue }) {
            delivered = await evaluate(secondary, as: .secondary, observedAt: observedAt) || delivered
        }
        if hasEffectiveProAccess() {
            delivered = await evaluateReset(windows.first(where: { $0.id == AlertWindow.primary.rawValue }), as: .primary, observedAt: observedAt) || delivered
            delivered = await evaluateReset(windows.first(where: { $0.id == AlertWindow.secondary.rawValue }), as: .secondary, observedAt: observedAt) || delivered
        } else {
            resetBaselines.removeAll()
        }
        return delivered
    }

    func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    private func beginTestCooldown(_ duration: Duration) {
        isTestNotificationCoolingDown = true
        testCooldownTask?.cancel()
        testCooldownTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.isTestNotificationCoolingDown = false
        }
    }

    private func evaluate(_ usage: CodexUsageWindow, as window: AlertWindow, observedAt: Date) async -> Bool {
        let threshold = window == .primary ? preferences.threshold : preferences.secondaryThreshold
        guard usage.usedPercentage >= Double(threshold.rawValue),
              let resetsAt = usage.resetsAt, resetsAt > observedAt else { return false }
        let windowKey = "\(window.rawValue):\(usage.durationMinutes):\(Int64(resetsAt.timeIntervalSince1970.rounded()))"
        let priorReceipt = window == .primary ? preferences.lastAlertedWindow : preferences.lastAlertedSecondaryWindow
        guard priorReceipt != windowKey else { return false }

        let actionRevision = userActionRevision
        let currentPermission = await notifications.permissionStatus()
        if actionRevision == userActionRevision { permissionStatus = currentPermission }
        guard currentPermission == .authorized,
              isEnabled(window),
              window != .secondary || hasEffectiveProAccess() else { return false }

        let used = min(100, max(0, Int(usage.usedPercentage.rounded())))
        let remaining = 100 - used
        let resetDescription = resetsAt.formatted(date: .abbreviated, time: .shortened)
        let notification = UsageAlertNotification(
            identifier: "usagegrid.codex.\(window.rawValue).\(windowKey)",
            title: "Codex usage limit approaching",
            body: "Codex \(window.title) window (\(usage.label)) is \(used)% used, \(remaining)% remaining. Resets \(resetDescription)."
        )

        if window == .primary { preferences.lastAlertedWindow = windowKey }
        else { preferences.lastAlertedSecondaryWindow = windowKey }
        deliveryError = nil
        do {
            try await notifications.deliver(notification)
            return true
        } catch {
            deliveryError = "Couldn’t deliver the \(window.title.lowercased()) usage alert."
            return false
        }
    }

    private func evaluateReset(_ usage: CodexUsageWindow?, as window: AlertWindow, observedAt: Date) async -> Bool {
        guard isResetEnabled(window) else {
            resetBaselines[window] = nil
            return false
        }
        guard let usage, usage.durationMinutes > 0, let resetsAt = usage.resetsAt, resetsAt > observedAt else {
            resetBaselines[window] = nil
            return false
        }

        let nextBaseline = ResetBaseline(durationMinutes: usage.durationMinutes, resetsAt: resetsAt)
        guard let previous = resetBaselines[window] else {
            resetBaselines[window] = nextBaseline
            return false
        }
        guard previous.durationMinutes == usage.durationMinutes else {
            resetBaselines[window] = nextBaseline
            return false
        }
        guard resetsAt > previous.resetsAt else { return false }
        resetBaselines[window] = nextBaseline
        guard observedAt >= previous.resetsAt else { return false }

        let receipt = "\(window.rawValue):\(usage.durationMinutes):\(Int64(resetsAt.timeIntervalSince1970.rounded()))"
        guard resetReceipt(for: window) != receipt else { return false }
        let actionRevision = userActionRevision
        let currentPermission = await notifications.permissionStatus()
        if actionRevision == userActionRevision { permissionStatus = currentPermission }
        guard currentPermission == .authorized,
              hasEffectiveProAccess(), isResetEnabled(window) else { return false }

        let used = min(100, max(0, Int(usage.usedPercentage.rounded())))
        let remaining = 100 - used
        let notification = UsageAlertNotification(
            identifier: "usagegrid.codex.reset.\(receipt)",
            title: "Codex usage window reset",
            body: "Codex \(window.title) window (\(usage.label)) reset was observed with \(remaining)% remaining."
        )
        setResetReceipt(receipt, for: window)
        deliveryError = nil
        do {
            try await notifications.deliver(notification)
            return true
        } catch {
            deliveryError = "Couldn’t deliver the \(window.title.lowercased()) reset notification."
            return false
        }
    }

    private func isEnabled(_ window: AlertWindow) -> Bool {
        window == .primary ? preferences.enabled : preferences.secondaryEnabled
    }

    private func setPreference(_ enabled: Bool, for window: AlertWindow) {
        if window == .primary { preferences.enabled = enabled }
        else { preferences.secondaryEnabled = enabled }
    }

    private var hasAnyEnabledAlert: Bool {
        preferences.enabled || (hasEffectiveProAccess() && (preferences.secondaryEnabled || preferences.primaryResetEnabled || preferences.secondaryResetEnabled))
    }

    private func isResetEnabled(_ window: AlertWindow) -> Bool {
        window == .primary ? preferences.primaryResetEnabled : preferences.secondaryResetEnabled
    }

    private func setResetPreference(_ enabled: Bool, for window: AlertWindow) {
        if window == .primary { preferences.primaryResetEnabled = enabled }
        else { preferences.secondaryResetEnabled = enabled }
    }

    private func resetReceipt(for window: AlertWindow) -> String? {
        window == .primary ? preferences.lastPrimaryResetNotification : preferences.lastSecondaryResetNotification
    }

    private func setResetReceipt(_ receipt: String, for window: AlertWindow) {
        if window == .primary { preferences.lastPrimaryResetNotification = receipt }
        else { preferences.lastSecondaryResetNotification = receipt }
    }

    private struct ResetBaseline {
        let durationMinutes: Int
        let resetsAt: Date
    }

    private enum AlertWindow: String, Hashable {
        case primary, secondary
        var title: String { rawValue.capitalized }
    }
}
