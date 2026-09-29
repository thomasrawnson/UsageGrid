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
    @State private var menuBarPreferences = MenuBarPreferences()
    @State private var usageAlerts: UsageAlertController
    @State private var proAccess: ProAccessController
    @State private var themePreferences: ThemePreferences
    @State private var usageHistory = UsageHistoryController()
    #if DEBUG
    @State private var testLicense: ProLicenseController
    #endif

    init() {
        let access = ProAccessController()
        _proAccess = State(initialValue: access)
        _themePreferences = State(initialValue: ThemePreferences(access: access))
        _usageAlerts = State(initialValue: UsageAlertController(hasEffectiveProAccess: { access.effectiveAccess.hasProEntitlement }))
        #if DEBUG
        _testLicense = State(initialValue: ProLicenseController(
            service: LemonSqueezyTestLicenseService(),
            storage: KeychainProLicenseCredentialStore.testMode,
            expectedIdentity: LemonSqueezyTestLicenseService.identity,
            activationAvailable: true,
            entitlementChanged: { access.setVerifiedTestLicense($0) }
        ))
        #endif
        #if DEBUG && !SWIFT_PACKAGE
        assert(Bundle.main.bundleIdentifier == "com.plutonightlabs.UsageGrid")
        #endif
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(codex: codex, alerts: usageAlerts, themePreferences: themePreferences, history: usageHistory, proAccess: proAccess)
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
            #if DEBUG
            .task { testLicense.validateStoredCredential(initial: true) }
            #endif
        }
        .menuBarExtraStyle(.window)

        Settings {
            #if DEBUG
            SettingsView(
                preferences: menuBarPreferences, codex: codex, alerts: usageAlerts,
                themePreferences: themePreferences, history: usageHistory, proAccess: proAccess,
                testLicense: testLicense
            )
            #else
            SettingsView(
                preferences: menuBarPreferences, codex: codex, alerts: usageAlerts,
                themePreferences: themePreferences, history: usageHistory, proAccess: proAccess
            )
            #endif
        }
    }
}
