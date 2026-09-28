import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: MenuBarPreferences
    @Bindable var codex: CodexRefreshCoordinator
    @Bindable var alerts: UsageAlertController
    @Bindable var themePreferences: ThemePreferences
    @Bindable var history: UsageHistoryController
    @State private var status = SMAppService.mainApp.status
    @State private var errorMessage: String?
    @State private var previewTheme: UsageTheme?
    @State private var showingHistoryPreview = false
    @State private var confirmingHistoryClear = false

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
                Text("The planned Pro offering adds 90s Retro, Anime, Zen Forest, Space, and usage-history viewing.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("One-off purchase planned. Purchasing is not available yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Preview themes") {
                    previewTheme = UsageTheme.lookup(UsageThemeID.retro.rawValue)
                }
            }

            Section("Usage History") {
                Toggle("Record usage history on this Mac", isOn: $history.isRecording)
                Text("Optional and off by default. Recording occurs only while UsageGrid is running. History viewing is planned for Pro; purchasing is not available yet.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Stores only observation time, window type and duration, reset time, and percentage used for up to seven days. It describes observed account usage, not activity attributable to this Mac, app, or task.")
                    .font(.caption).foregroundStyle(.secondary)
                if let storageError = history.storageError {
                    Label(storageError, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
                }
                HStack {
                    Button("Preview usage history") { showingHistoryPreview = true }
                    Button("Clear History", role: .destructive) { confirmingHistoryClear = true }
                        .disabled(history.samples.isEmpty && history.storageError == nil)
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
        .frame(minWidth: 420, idealWidth: 440, maxWidth: 560,
               minHeight: 480, idealHeight: 620, maxHeight: 720)
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
        .sheet(isPresented: $showingHistoryPreview) {
            UsageHistoryPreviewSheet(theme: themePreferences.activeTheme)
        }
        .confirmationDialog("Clear all recorded usage history?", isPresented: $confirmingHistoryClear) {
            Button("Clear History", role: .destructive) { Task { await history.clear() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the local history file and cannot be undone.")
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
