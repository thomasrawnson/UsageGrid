import AppKit
import Foundation
import Observation
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
    func permissionStatus() async -> UsageAlertPermissionStatus {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        switch status {
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
        try await UNUserNotificationCenter.current().add(request)
    }
}

@Observable
final class UsageAlertPreferences {
    static let enabledKey = "usageAlertsEnabled"
    static let thresholdKey = "usageAlertsThreshold"
    static let lastAlertedWindowKey = "usageAlertsLastPrimaryResetWindow"

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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.bool(forKey: Self.enabledKey)
        threshold = UsageAlertThreshold(rawValue: defaults.integer(forKey: Self.thresholdKey)) ?? .ninety
        lastAlertedWindow = defaults.string(forKey: Self.lastAlertedWindowKey)
    }
}

@MainActor
@Observable
final class UsageAlertController {
    let preferences: UsageAlertPreferences
    private let notifications: any UsageAlertNotificationProviding

    private(set) var permissionStatus: UsageAlertPermissionStatus = .notDetermined
    private(set) var deliveryError: String?
    private(set) var testNotificationMessage: String?
    private(set) var isSendingTestNotification = false
    private(set) var isTestNotificationCoolingDown = false
    @ObservationIgnored private var testCooldownTask: Task<Void, Never>?
    @ObservationIgnored private var permissionRefreshRevision = 0
    @ObservationIgnored private var userActionRevision = 0

    init(
        preferences: UsageAlertPreferences = UsageAlertPreferences(),
        notifications: any UsageAlertNotificationProviding = SystemUsageAlertNotifications()
    ) {
        self.preferences = preferences
        self.notifications = notifications
    }

    var permissionMessage: String {
        switch permissionStatus {
        case .authorized: preferences.enabled ? "Alerts active for the primary window." : "Notifications allowed; usage alerts are off."
        case .denied: "Notifications are denied. Enable them for UsageGrid in System Settings."
        case .notDetermined: preferences.enabled ? "Checking notification permission…" : "Permission will be requested only when alerts are enabled."
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
        userActionRevision += 1
        let actionRevision = userActionRevision
        deliveryError = nil
        guard enabled else {
            preferences.enabled = false
            return
        }

        let status = await notifications.permissionStatus()
        guard actionRevision == userActionRevision else { return }
        switch status {
        case .authorized:
            permissionStatus = .authorized
            preferences.enabled = true
        case .denied:
            permissionStatus = .denied
            preferences.enabled = false
        case .unavailable:
            permissionStatus = .unavailable
            preferences.enabled = false
        case .notDetermined:
            do {
                let granted = try await notifications.requestPermission()
                guard actionRevision == userActionRevision else { return }
                permissionStatus = granted ? .authorized : .denied
                preferences.enabled = granted
            } catch {
                let currentStatus = await notifications.permissionStatus()
                guard actionRevision == userActionRevision else { return }
                permissionStatus = currentStatus
                preferences.enabled = false
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
    func evaluate(windows: [CodexUsageWindow]?, isFresh: Bool) async -> Bool {
        guard preferences.enabled, isFresh,
              let primary = windows?.first(where: { $0.id == "primary" }),
              primary.usedPercentage >= Double(preferences.threshold.rawValue),
              let resetsAt = primary.resetsAt else { return false }

        let windowKey = "primary:\(primary.durationMinutes):\(Int64(resetsAt.timeIntervalSince1970.rounded()))"
        guard preferences.lastAlertedWindow != windowKey else { return false }
        let actionRevision = userActionRevision
        let currentPermission = await notifications.permissionStatus()
        guard currentPermission == .authorized else {
            if actionRevision == userActionRevision { permissionStatus = currentPermission }
            return false
        }

        let used = min(100, max(0, Int(primary.usedPercentage.rounded())))
        let remaining = 100 - used
        let resetDescription = resetsAt.formatted(date: .abbreviated, time: .shortened)
        let notification = UsageAlertNotification(
            identifier: "usagegrid.codex.primary.\(windowKey)",
            title: "Codex usage limit approaching",
            body: "Codex \(primary.label) is \(used)% used, \(remaining)% remaining. Resets \(resetDescription)."
        )

        preferences.lastAlertedWindow = windowKey
        deliveryError = nil
        do {
            try await notifications.deliver(notification)
            return true
        } catch {
            deliveryError = "Couldn’t deliver the usage alert."
            return false
        }
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
}
