import SwiftUI
import AppKit

struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings
    @State private var codex = CodexRefreshState()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("UsageGrid")
                        .font(.headline)
                    Spacer()
                    if codex.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 24, height: 24)
                            .accessibilityLabel("Refreshing Codex usage")
                    } else {
                        Button(action: refreshCodex) {
                            Image(systemName: "arrow.clockwise")
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Refresh usage")
                        .help("Refresh Codex usage")
                    }
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

            if let codexWindows = codex.windows {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Codex")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    ForEach(codexWindows, id: \.id) { window in
                        CodexWindowRow(window: window)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Codex")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(codex.refreshFailed ? "Usage unavailable" : "Loading usage…")
                        .foregroundStyle(.secondary)
                    if codex.refreshFailed {
                        Text("Could not read Codex usage")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 5) {
                Text("Claude")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Usage unavailable")
                    .font(.callout)
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
        .padding(14)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(window.label).font(.callout)
                Spacer()
                (Text(window.usedPercentage, format: .number.precision(.fractionLength(0))) + Text("%"))
                    .monospacedDigit()
            }
            ProgressView(value: window.usedPercentage, total: 100)
                .accessibilityLabel("Codex \(window.label) usage")
                .accessibilityValue("\(Int(window.usedPercentage.rounded())) percent used")
            Text(window.resetText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
