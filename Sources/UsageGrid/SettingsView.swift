import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @State private var status = SMAppService.mainApp.status
    @State private var errorMessage: String?

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
        .onAppear(perform: refreshStatus)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshStatus()
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
