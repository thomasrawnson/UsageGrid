import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: MenuBarPreferences
    @Bindable var codex: CodexRefreshCoordinator
    @Bindable var alerts: UsageAlertController
    @Bindable var themePreferences: ThemePreferences
    @State private var status = SMAppService.mainApp.status
    @State private var errorMessage: String?
    @State private var previewTheme: UsageTheme?

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        guard let version, !version.isEmpty else { return "UsageGrid" }
        guard let build, !build.isEmpty else { return "UsageGrid \(version)" }
        return "UsageGrid \(version) (\(build))"
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch UsageGrid at Login", isOn: Binding(
                    get: { status == .enabled },
                    set: { updateLaunchAtLogin($0) }
                ))

                if status == .requiresApproval {
                    Text("Approve UsageGrid in Login Items to launch it at login.")
                        .foregroundStyle(.secondary)
                    Button("Open Login Items Settings") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                } else if status == .notFound {
                    Text("Launch at Login is unavailable for this app build.")
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Menu Bar") {
                Picker("Menu bar display", selection: $preferences.displayMode) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                if preferences.displayMode != .iconOnly {
                    Picker("Usage window", selection: $preferences.windowSelection) {
                        ForEach(MenuBarWindowSelection.allCases) { selection in
                            Text(MenuBarUsagePresentation.windowTitle(for: selection, windows: codex.windows)).tag(selection)
                        }
                    }
                }
            }

            Section("Appearance") {
                ThemeGalleryView(preferences: themePreferences, previewTheme: $previewTheme)
                Text("Free themes can be selected immediately. Pro themes are available as isolated sample previews and do not change live usage or your saved theme.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("UsageGrid Pro") {
                Text("Everything currently available in UsageGrid remains Free, including live Codex usage, refresh recovery, menu-bar display, alerts, and the Programming theme.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("The planned Pro offering adds the Midnight, Paper, and Aurora premium themes.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("One-off purchase planned. Purchasing is not available yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Preview themes") {
                    previewTheme = UsageTheme.lookup(UsageThemeID.midnight.rawValue)
                }
            }

            Section("Codex Connection") {
                if codex.setupState == nil {
                    Text("Connected · usage available")
                        .foregroundStyle(.secondary)
                    DisclosureGroup("Codex setup guide") {
                        CodexSetupGuideView()
                            .padding(.top, 4)
                    }
                } else if let setupState = codex.setupState {
                    CodexSetupStatusView(state: setupState) {
                        codex.requestRefresh()
                    }
                }
            }

            Section("Usage Alerts") {
                Toggle("Alert when primary usage reaches threshold", isOn: Binding(
                    get: { alerts.preferences.enabled },
                    set: { enabled in Task { await alerts.setEnabled(enabled) } }
                ))

                Picker("Threshold", selection: Binding(
                    get: { alerts.preferences.threshold },
                    set: { alerts.preferences.threshold = $0 }
                )) {
                    ForEach(UsageAlertThreshold.allCases) { threshold in
                        Text(threshold.title).tag(threshold)
                    }
                }
                .disabled(!alerts.preferences.enabled)

                Text("Threshold is percentage used for the Codex primary window, regardless of the menu-bar display setting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(alerts.permissionMessage)
                    .font(.caption)
                    .foregroundStyle(alerts.permissionStatus == .denied ? .orange : .secondary)

                if alerts.permissionStatus == .denied {
                    Button("Open Notification Settings") {
                        alerts.openNotificationSettings()
                    }
                }


                Button(alerts.isSendingTestNotification ? "Requesting test…" : "Send test notification") {
                    Task { await alerts.sendTestNotification() }
                }
                .disabled(!alerts.canSendTestNotification)

                Text("A test does not use quota data. macOS notification settings or Focus may suppress the banner.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let testNotificationMessage = alerts.testNotificationMessage {
                    Text(testNotificationMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let deliveryError = alerts.deliveryError {
                    Text(deliveryError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .safeAreaInset(edge: .bottom) {
            Text(versionText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
        }
        .onAppear {
            refreshStatus()
            Task { await alerts.refreshPermissionStatus() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshStatus()
            Task { await alerts.refreshPermissionStatus() }
        }
        .sheet(item: $previewTheme) { theme in
            ProThemePreviewSheet(theme: theme)
        }
    }

    private func refreshStatus() {
        status = SMAppService.mainApp.status
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = enabled
                ? "Couldn’t enable Launch at Login."
                : "Couldn’t disable Launch at Login."
        }
        refreshStatus()
    }
}
