import SwiftUI
import AppKit

struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings

    private let providers = [
        ProviderUsage(name: "Codex", usedPercentage: 42, resetText: "Resets in 3h 20m"),
        ProviderUsage(name: "Claude", usedPercentage: 18, resetText: "Resets in 2h")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("UsageGrid")
                    .font(.headline)
                Spacer()
                Text("Mock data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(providers, id: \.name) { provider in
                UsageRow(usage: provider)
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
