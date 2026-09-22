import SwiftUI
import AppKit

struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UsageGrid")
                .font(.headline)

            HStack {
                Text("Codex")
                Spacer()
                Text("Usage unavailable")
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
    }
}
