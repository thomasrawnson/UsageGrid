import SwiftUI
import AppKit

struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings
    @State private var codexUsage: ProviderUsage?
    @State private var isReadingCodex = true

    private let claudeUsage = ProviderUsage(name: "Claude", usedPercentage: 18, resetText: "Resets in 2h")

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("UsageGrid")
                    .font(.headline)
                Spacer()
                Text("Claude: mock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let codexUsage {
                UsageRow(usage: codexUsage)
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

            UsageRow(usage: claudeUsage)

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
            codexUsage = nil
            isReadingCodex = true
            Task {
                codexUsage = await CodexUsageReader.read()
                isReadingCodex = false
            }
        }
    }
}

private struct UsageRow: View {
    let usage: ProviderUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(usage.name)
                    .fontWeight(.medium)
                Spacer()
                Text(usage.usedPercentage, format: .number.precision(.fractionLength(0)))
                    + Text("%")
            }

            ProgressView(value: usage.usedPercentage, total: 100)
                .accessibilityLabel("\(usage.name) usage")

            Text("\(usage.statusText) · \(usage.resetText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
