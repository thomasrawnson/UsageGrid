import AppKit
import SwiftUI
import UserNotifications

final class UsageGridAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    static let foregroundPresentationOptions: UNNotificationPresentationOptions = [.banner, .list]

    func applicationWillFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        Self.foregroundPresentationOptions
    }
}

@main
struct UsageGridApp: App {
    @NSApplicationDelegateAdaptor(UsageGridAppDelegate.self) private var appDelegate
    @State private var codex = CodexRefreshCoordinator()
    @State private var claude = ClaudeUsageCoordinator()
    @State private var menuBarPreferences = MenuBarPreferences()
    @State private var usageAlerts: UsageAlertController
    @State private var themePreferences: ThemePreferences
    @State private var usageHistory = UsageHistoryController()
    init() {
        _themePreferences = State(initialValue: ThemePreferences())
        _usageAlerts = State(initialValue: UsageAlertController())
        #if DEBUG && !SWIFT_PACKAGE
        assert(Bundle.main.bundleIdentifier == "com.plutonightlabs.UsageGrid")
        #endif
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(codex: codex, claude: claude, alerts: usageAlerts, themePreferences: themePreferences, history: usageHistory)
        } label: {
            let presentation = MenuBarUsagePresentation.make(
                mode: menuBarPreferences.displayMode,
                selection: menuBarPreferences.windowSelection,
                windows: codex.windows,
                isStale: codex.isStale,
                isRefreshing: codex.isRefreshing,
                lastUpdated: codex.lastUpdated
            )
            HStack(spacing: 4) {
                Image(systemName: "square.grid.3x3")
                if let text = presentation.text {
                    Text(text)
                        .monospacedDigit()
                }
            }
            .accessibilityLabel(presentation.accessibilityLabel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(preferences: menuBarPreferences, codex: codex, alerts: usageAlerts, themePreferences: themePreferences, history: usageHistory)
        }
    }
}
