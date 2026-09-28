import AppKit
import Foundation
import SwiftUI

enum CodexSetupState: Equatable {
    case connecting
    case executableNotFound
    case authenticationRequired
    case connectionFailure(String)
    case usageUnavailable

    static func from(_ state: CodexRefreshState) -> Self? {
        if let windows = state.windows {
            return windows.isEmpty ? .usageUnavailable : nil
        }
        if state.isRefreshing || !state.refreshFailed { return .connecting }
        switch state.lastError {
        case .executableNotFound: return .executableNotFound
        case .authenticationRequired: return .authenticationRequired
        case .decodingFailed: return .usageUnavailable
        case .processLaunchFailed, .initializationTimedOut, .initializationFailed,
             .requestTimedOut, .requestFailed, .cancelled, .none:
            return .connectionFailure(state.errorMessage ?? "Could not connect to local Codex usage. Try again.")
        }
    }

    var title: String {
        switch self {
        case .connecting: "Connecting to Codex…"
        case .executableNotFound: "Supported Codex executable not found"
        case .authenticationRequired: "Codex sign-in required"
        case .connectionFailure: "Couldn’t connect to Codex"
        case .usageUnavailable: "Connected, but usage is unavailable"
        }
    }

    var message: String {
        switch self {
        case .connecting:
            "UsageGrid is asking the local Codex integration for your usage."
        case .executableNotFound:
            "UsageGrid could not find a supported Codex executable inside the standard ChatGPT application bundle. ChatGPT may still be installed, but this version or location is not supported."
        case .authenticationRequired:
            "Open ChatGPT or Codex and sign in, then return here and retry. UsageGrid never asks for or stores your credentials."
        case .connectionFailure(let message):
            message
        case .usageUnavailable:
            "The local Codex integration responded, but did not provide a supported usage window. No zero or demo value is substituted."
        }
    }
}

enum ChatGPTApplication {
    static let applicationURL = URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true)

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: applicationURL.path)
    }

    static func open() {
        guard isInstalled else { return }
        NSWorkspace.shared.openApplication(
            at: applicationURL,
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: nil
        )
    }
}

struct CodexSetupStatusView: View {
    let state: CodexSetupState
    let retry: () -> Void
    @State private var guideExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.title)
                .font(.system(.callout, design: .monospaced).weight(.semibold))
            Text(state.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if state != .connecting {
                HStack(spacing: 12) {
                    Button("Retry", action: retry)
                    if ChatGPTApplication.isInstalled {
                        Button("Open ChatGPT", action: ChatGPTApplication.open)
                    }
                }
                .buttonStyle(.plain)
            }

            DisclosureGroup("Codex setup guide", isExpanded: $guideExpanded) {
                CodexSetupGuideView()
                    .padding(.top, 4)
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CodexSetupGuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("1. Install a supported local Codex executable. UsageGrid currently checks only these ChatGPT bundle locations:")
            VStack(alignment: .leading, spacing: 2) {
                ForEach(CodexUsageReader.executableCandidates, id: \.self) { path in
                    Text(path)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            Text("2. Sign in to Codex using ChatGPT or the Codex app. UsageGrid does not handle credentials.")
            Text("3. Retry. UsageGrid reads quota windows through the local Codex app-server integration.")
            Text("Claude remains unavailable in this version and is not connected by Codex setup.")
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
