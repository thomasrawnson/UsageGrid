import SwiftUI

@main
struct UsageGridApp: App {
    init() {
        #if DEBUG && !SWIFT_PACKAGE
        assert(Bundle.main.bundleIdentifier == "com.plutonightlabs.UsageGrid")
        #endif
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
