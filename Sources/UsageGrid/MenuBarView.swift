import SwiftUI
import AppKit

struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings
    @State private var codex = CodexRefreshState()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("UsageGrid")
                    .font(.headline)
                Spacer()
                if codex.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Refreshing Codex usage")
                } else {
                    Button(action: refreshCodex) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Refresh usage")
                    .help("Refresh Codex usage")
                }
            }

            if let codexWindows = codex.windows {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Codex").fontWeight(.medium)
                    ForEach(codexWindows, id: \.id) { window in
                        CodexWindowRow(window: window)
                    }
                    if let lastUpdated = codex.lastUpdated {
                        HStack(spacing: 4) {
                            Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                            if codex.refreshFailed {
                                Text("· Refresh failed")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Codex").fontWeight(.medium)
                    Text(codex.refreshFailed ? "Usage unavailable" : "Loading usage…")
                        .foregroundStyle(.secondary)
                    if codex.refreshFailed {
                        Text("Could not read Codex usage")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Claude").fontWeight(.medium)
                Text("Usage unavailable")
                    .foregroundStyle(.secondary)
                Text("Live usage source unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Button("Settings") {
                    openSettings()
                }
                Spacer()
                Button("Quit UsageGrid") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding()
        .frame(width: 320)
        .onAppear(perform: refreshCodex)
    }

    private func refreshCodex() {
        guard codex.start() else { return }
        Task {
            let windows = await CodexUsageReader.read()
            codex.finish(with: windows, at: Date())
        }
    }
}

struct CodexRefreshState {
    private(set) var windows: [CodexUsageWindow]?
    private(set) var isRefreshing = false
    private(set) var refreshFailed = false
    private(set) var lastUpdated: Date?

    mutating func start() -> Bool {
        guard !isRefreshing else { return false }
        isRefreshing = true
        refreshFailed = false
        return true
    }

    mutating func finish(with newWindows: [CodexUsageWindow]?, at date: Date) {
        guard isRefreshing else { return }
        isRefreshing = false
        if let newWindows {
            windows = newWindows
            lastUpdated = date
            refreshFailed = false
        } else {
            refreshFailed = true
        }
    }
}

private struct CodexWindowRow: View {
    let window: CodexUsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(window.label).font(.subheadline)
                Spacer()
                Text(window.usedPercentage, format: .number.precision(.fractionLength(0))) + Text("%")
            }
            ProgressView(value: window.usedPercentage, total: 100)
                .accessibilityLabel("Codex \(window.label) usage")
            Text(window.resetText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
