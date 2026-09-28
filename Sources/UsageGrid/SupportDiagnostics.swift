import AppKit
import Foundation
import SwiftUI
import UserNotifications

struct SupportNotificationSettings: Equatable {
    let authorization: String
    let alerts: String
    let notificationCentre: String
}

struct SupportDiagnosticsInput {
    let appVersion: String?
    let appBuild: String?
    let macOSVersion: String?
    let architecture: String?
    let isRefreshing: Bool
    let hasReading: Bool
    let isStale: Bool
    let lastSuccessfulRefresh: Date?
    let lastError: CodexUsageReadError?
    /// Accepted so callers cannot accidentally fall back to displaying a raw error.
    /// The report intentionally never reads this value.
    let unsafeErrorDetail: String?
    let executableSource: String?
    let notificationSettings: SupportNotificationSettings?
    let historyRecordingEnabled: Bool
    let historyHasStorageError: Bool
    let hasProAccess: Bool
    let isDebugSimulation: Bool
}

enum SupportDiagnosticsReport {
    static func make(input: SupportDiagnosticsInput, now: Date = Date()) -> String {
        let connection: String
        if input.isRefreshing && !input.hasReading {
            connection = "Connecting"
        } else if input.hasReading && input.isStale {
            connection = "Connected; latest refresh failed"
        } else if input.hasReading {
            connection = "Connected"
        } else if input.lastError != nil {
            connection = "Unavailable"
        } else {
            connection = "Not yet established"
        }

        let freshness: String
        if input.isStale { freshness = "Stale" }
        else if input.hasReading { freshness = input.isRefreshing ? "Refreshing; retained reading" : "Fresh" }
        else { freshness = input.isRefreshing ? "Connecting" : "Unavailable" }

        let safeError = safeErrorDescription(input.lastError)
        let notifications = input.notificationSettings
        let access: String
        if input.isDebugSimulation {
            access = "Pro (Debug simulation; not a purchase)"
        } else if input.hasProAccess {
            access = "Pro (verified entitlement)"
        } else {
            access = "Free"
        }

        return [
            "UsageGrid Support Diagnostics",
            "App version: \(known(input.appVersion))",
            "App build: \(known(input.appBuild))",
            "macOS: \(known(input.macOSVersion))",
            "Process architecture: \(known(input.architecture))",
            "Connection: \(connection)",
            "Last error category: \(safeError.category)",
            "Last error: \(safeError.description)",
            "Reading freshness: \(freshness)",
            "Last successful refresh: \(elapsedDescription(since: input.lastSuccessfulRefresh, now: now))",
            "Codex executable source: \(known(input.executableSource))",
            "Notification permission: \(known(notifications?.authorization))",
            "Notification alerts: \(known(notifications?.alerts))",
            "Notification Centre: \(known(notifications?.notificationCentre))",
            "History recording: \(input.historyRecordingEnabled ? "Enabled" : "Disabled")",
            "History storage: \(input.historyHasStorageError ? "Unavailable (local storage error)" : "Available")",
            "Access: \(access)"
        ].joined(separator: "\n")
    }

    static func safeErrorDescription(_ error: CodexUsageReadError?) -> (category: String, description: String) {
        guard let error else { return ("None", "None") }
        switch error {
        case .executableNotFound: return ("Executable unavailable", "A supported bundled Codex executable was not found.")
        case .processLaunchFailed: return ("Process launch", "The local Codex process could not be started.")
        case .initializationTimedOut: return ("Initialization timeout", "The local Codex process did not initialize in time.")
        case .initializationFailed: return ("Initialization", "The local Codex process could not initialize.")
        case .requestTimedOut: return ("Request timeout", "The usage request did not complete in time.")
        case .authenticationRequired: return ("Authentication", "Codex sign-in is required.")
        case .requestFailed: return ("Request", "The local Codex usage request failed.")
        case .decodingFailed: return ("Usage data", "No supported usage windows were available.")
        case .cancelled: return ("Cancelled", "The usage refresh was cancelled.")
        }
    }

    private static func known(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "Unknown" }
        return value
    }

    private static func elapsedDescription(since date: Date?, now: Date) -> String {
        guard let date else { return "Unavailable" }
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "less than 1 minute ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) minute\(minutes == 1 ? "" : "s") ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) hour\(hours == 1 ? "" : "s") ago" }
        let days = hours / 24
        return "\(days) day\(days == 1 ? "" : "s") ago"
    }
}

enum SupportNotificationSettingsReader {
    static func read() async -> SupportNotificationSettings {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return SupportNotificationSettings(
            authorization: authorizationDescription(settings.authorizationStatus),
            alerts: settingDescription(settings.alertSetting),
            notificationCentre: settingDescription(settings.notificationCenterSetting)
        )
    }

    private static func authorizationDescription(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "Not requested"
        case .denied: "Denied"
        case .authorized: "Authorized"
        case .provisional: "Provisional"
        case .ephemeral: "Ephemeral"
        @unknown default: "Unknown"
        }
    }

    private static func settingDescription(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .enabled: "Enabled"
        case .disabled: "Disabled"
        case .notSupported: "Unavailable"
        @unknown default: "Unknown"
        }
    }
}

struct SupportDiagnosticsView: View {
    @Bindable var codex: CodexRefreshCoordinator
    @Bindable var history: UsageHistoryController
    @Bindable var proAccess: ProAccessController
    @State private var report = "Preparing diagnostics…"
    @State private var copyMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A privacy-safe snapshot for troubleshooting. Nothing is uploaded or sent.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView([.horizontal, .vertical]) {
                Text(report)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(8)
            }
            .frame(minHeight: 170, maxHeight: 230)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))

            HStack {
                Button("Copy diagnostics", action: copyReport)
                Button("Refresh snapshot") { Task { await refreshReport() } }
                if let copyMessage {
                    Text(copyMessage).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .task { await refreshReport() }
    }

    @MainActor private func refreshReport() async {
        let notificationSettings = await SupportNotificationSettingsReader.read()
        report = SupportDiagnosticsReport.make(input: diagnosticsInput(notificationSettings))
        copyMessage = nil
    }

    @MainActor private func diagnosticsInput(_ notifications: SupportNotificationSettings?) -> SupportDiagnosticsInput {
        #if arch(arm64)
        let architecture = "arm64"
        #elseif arch(x86_64)
        let architecture = "x86_64"
        #else
        let architecture: String? = nil
        #endif

        #if DEBUG
        let debugSimulation = proAccess.isDeveloperSimulationActive
        #else
        let debugSimulation = false
        #endif

        let executableSource: String?
        if codex.lastError == .executableNotFound { executableSource = "Unavailable" }
        else if codex.windows != nil || codex.lastError != nil { executableSource = "ChatGPT bundled Codex" }
        else { executableSource = nil }

        return SupportDiagnosticsInput(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: architecture,
            isRefreshing: codex.isRefreshing,
            hasReading: codex.windows != nil,
            isStale: codex.isStale,
            lastSuccessfulRefresh: codex.lastUpdated,
            lastError: codex.lastError,
            unsafeErrorDetail: codex.errorMessage,
            executableSource: executableSource,
            notificationSettings: notifications,
            historyRecordingEnabled: history.isRecording,
            historyHasStorageError: history.storageError != nil,
            hasProAccess: proAccess.effectiveAccess.hasProEntitlement,
            isDebugSimulation: debugSimulation
        )
    }

    private func copyReport() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        copyMessage = pasteboard.setString(report, forType: .string)
            ? "Diagnostics copied"
            : "Couldn’t copy diagnostics"
    }
}
