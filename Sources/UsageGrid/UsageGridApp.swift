import SwiftUI
import AppKit

@main
struct UsageGridApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("UsageGrid", systemImage: "square.grid.3x3") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)

        Settings {
            Text("UsageGrid Settings")
                .padding()
        }
    }
}
