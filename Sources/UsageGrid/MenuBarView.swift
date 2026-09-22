import SwiftUI
import AppKit

struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings
    @State private var codexWindows: [CodexUsageWindow]?
    @State private var isReadingCodex = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UsageGrid")
                .font(.headline)

            if let codexWindows {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Codex").fontWeight(.medium)
                    ForEach(codexWindows, id: \.id) { window in
                        CodexWindowRow(window: window)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Codex").fontWeight(.medium)
                    Text(isReadingCodex ? "Reading Codex usage…" : "Usage unavailable")
                        .foregroundStyle(.secondary)
                    if !isReadingCodex {
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
        .onAppear {
            codexWindows = nil
            isReadingCodex = true
            Task {
                codexWindows = await CodexUsageReader.read()
                isReadingCodex = false
            }
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
