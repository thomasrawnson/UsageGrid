import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: MenuBarPreferences
    @Bindable var codex: CodexRefreshCoordinator
    @Bindable var alerts: UsageAlertController
    @Bindable var themePreferences: ThemePreferences
    @Bindable var history: UsageHistoryController
    @Bindable var proAccess: ProAccessController
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
        TabView {
            generalSettings
                .tabItem { Label("General", systemImage: "gearshape") }
            appearanceSettings
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
            usageSettings
                .tabItem { Label("Usage & History", systemImage: "chart.xyaxis.line") }
            alertSettings
                .tabItem { Label("Alerts", systemImage: "bell") }
            helpSettings
                .tabItem { Label("Help", systemImage: "questionmark.circle") }
        }
        .frame(minWidth: 420, idealWidth: 520, maxWidth: 640,
               minHeight: 480, idealHeight: 620, maxHeight: 760)
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

    private var generalSettings: some View {
        Form {
            Section("Launch") {
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

            Section("Menu bar display") {
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

            #if DEBUG
            Section("Developer testing") {
                Toggle("Simulate Pro access", isOn: $proAccess.isDeveloperProSimulationEnabled)
                Text(proAccess.isDeveloperProSimulationEnabled
                     ? "Developer Pro simulation"
                     : "Simulation off · normal Free access")
                    .font(.caption)
                    .foregroundStyle(proAccess.isDeveloperProSimulationEnabled ? .orange : .secondary)
                Text("Debug-only and held in memory. This is not a purchase or production entitlement and resets when UsageGrid quits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            #endif
        }
        .formStyle(.grouped)
    }

    private var appearanceSettings: some View {
        Form {
            Section("Appearance") {
                ThemeGalleryView(preferences: themePreferences, proAccess: proAccess, previewTheme: $previewTheme)
                Text(proAccess.effectiveAccess.hasProEntitlement
                     ? "Pro themes can be applied to live usage and recorded history. Sample previews remain isolated from real data."
                     : "Free themes can be selected immediately. Pro themes are available as isolated sample previews and do not change live usage or your saved theme.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Free and Pro") {
                VStack(alignment: .leading, spacing: 10) {
                    featureSummary(title: "Free", systemImage: "checkmark.circle", features: "Live Codex usage, menu-bar display, Programming and Professional themes, and primary threshold alerts.")
                    Divider()
                    featureSummary(title: "UsageGrid Pro", systemImage: "sparkles", features: "Premium themes, real history and session views, secondary threshold alerts, and confirmed reset notifications.")
                }
                Text("History recording is optional, local to this Mac, and off by default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("One-off purchase planned. Purchasing is not available yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Preview themes") {
                    previewTheme = UsageTheme.lookup(UsageThemeID.retro.rawValue)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var usageSettings: some View {
        Form {
            Section("Usage History") {
                Toggle("Record usage history on this Mac", isOn: $history.isRecording)
                Text(proAccess.effectiveAccess.canViewUsageHistory
                     ? "Optional and off by default. Recording occurs only while UsageGrid is running. Real history is available in the menu-bar popup while effective Pro access is active."
                     : "Optional and off by default. Recording is local and occurs only while UsageGrid is running. Real history and session views require Pro.")
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
        }
        .formStyle(.grouped)
    }

    private var alertSettings: some View {
        Form {
            Section("Usage Alerts") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(alertWindowTitle("primary", fallback: "Primary window"))
                        .font(.headline)
                    Toggle("Alert when usage reaches threshold", isOn: Binding(
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
                    if proAccess.effectiveAccess.canUseResetAlerts {
                        Toggle("Notify when window resets", isOn: Binding(
                            get: { alerts.preferences.primaryResetEnabled },
                            set: { enabled in Task { await alerts.setPrimaryResetEnabled(enabled) } }
                        ))
                    }
                }

                if proAccess.effectiveAccess.canUseSecondaryAlerts {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(alertWindowTitle("secondary", fallback: "Secondary window"))
                            .font(.headline)
                        if codex.windows?.contains(where: { $0.id == "secondary" }) != true {
                            Text("Window unavailable").font(.caption).foregroundStyle(.secondary)
                        }
                        Toggle("Alert when usage reaches threshold", isOn: Binding(
                            get: { alerts.preferences.secondaryEnabled },
                            set: { enabled in Task { await alerts.setSecondaryEnabled(enabled) } }
                        ))
                        Picker("Threshold", selection: Binding(
                            get: { alerts.preferences.secondaryThreshold },
                            set: { alerts.preferences.secondaryThreshold = $0 }
                        )) {
                            ForEach(UsageAlertThreshold.allCases) { threshold in
                                Text(threshold.title).tag(threshold)
                            }
                        }
                        .disabled(!alerts.preferences.secondaryEnabled)
                        Toggle("Notify when window resets", isOn: Binding(
                            get: { alerts.preferences.secondaryResetEnabled },
                            set: { enabled in Task { await alerts.setSecondaryResetEnabled(enabled) } }
                        ))
                    }
                } else {
                    Text("Secondary-window threshold alerts require Pro.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Text("Each threshold means percentage used, regardless of the menu-bar display preference.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if proAccess.effectiveAccess.canUseResetAlerts {
                    Text("Reset alerts arrive only after UsageGrid observes a confirmed rollover while running, which may be later than the displayed reset time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Confirmed primary and secondary reset notifications require Pro.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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
    }

    private var helpSettings: some View {
        Form {
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

            Section("Support diagnostics") {
                SupportDiagnosticsView(codex: codex, history: history, proAccess: proAccess)
            }

            Section("About") {
                Text(versionText)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func featureSummary(title: String, systemImage: String, features: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(features)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func refreshStatus() {
        status = SMAppService.mainApp.status
    }

    private func alertWindowTitle(_ id: String, fallback: String) -> String {
        guard let window = codex.windows?.first(where: { $0.id == id }) else { return fallback }
        return window.label
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
