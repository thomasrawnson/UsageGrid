# UsageGrid

Native macOS utility. The current baseline is a minimal SwiftUI app executable and one unit-test target. Product behavior is specified in `docs/PRODUCT-SPEC.md`; the task queue is in `docs/EXECUTION.md`.

## T01 repository and Mac baseline

- Starting directory on 22 September 2026: planning documents and reference PNGs only; no `.git`, app code, project, tests, or `AGENTS.md`. No unrelated source changes were present.
- Host: Apple Silicon Mac mini, macOS 27.0.0 (Darwin 27.0.0, arm64).
- Active developer directory: `/Library/Developer/CommandLineTools`. Swift: Apple Swift 6.4 (`swiftlang-6.4.0.34.1`). macOS SDK: 27.0. Xcode app was not found in `/Applications`; `xcodebuild -version` fails because the active directory is Command Line Tools.
- Structure: `Package.swift` defines a macOS 14+ executable target and a test target. `Sources/UsageGrid` contains a placeholder SwiftUI app. `Tests/UsageGridTests` contains a target link smoke test. There are no third-party dependencies.

From this directory, run `swift build` and `swift test`. On this host, `swift build` passed (with Command Line Tools linker-search-path warnings). `swift test` compiled the app but failed compiling the test target because the Command Line Tools installation could not find `TestingMacros.TestDeclarationMacro`. The initial sandboxed test attempt also hit compiler-cache permissions; an unrestricted retry isolated the missing macro plugin. These checks establish a command-line executable build, not a packaged `.app` or Xcode build.

Mac follow-up: install a full Xcode release whose Swift compiler matches its macOS SDK, select it with `xcode-select`, run `xcodebuild -version`, `swift build`, and `swift test`, then open `Package.swift` in Xcode and build/run the `UsageGrid` scheme. Confirm launch and window display before treating the app baseline as fully verified. Menu-bar behavior belongs to T05.
