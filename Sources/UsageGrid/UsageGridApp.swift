import SwiftUI

@main
struct UsageGridApp: App {
    @State private var codex = CodexRefreshCoordinator()
    @State private var menuBarPreferences = MenuBarPreferences()
    @State private var usageAlerts: UsageAlertController
    @State private var proAccess: ProAccessController
    @State private var themePreferences: ThemePreferences
    @State private var usageHistory = UsageHistoryController()

    init() {
        let access = ProAccessController()
        _proAccess = State(initialValue: access)
        _themePreferences = State(initialValue: ThemePreferences(access: access))
        _usageAlerts = State(initialValue: UsageAlertController(hasEffectiveProAccess: { access.effectiveAccess.canUseSecondaryAlerts }))
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
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(preferences: menuBarPreferences, codex: codex, alerts: usageAlerts, themePreferences: themePreferences, history: usageHistory, proAccess: proAccess)
        }
    }
}
