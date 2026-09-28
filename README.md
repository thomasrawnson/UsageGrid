# UsageGrid

Native macOS menu-bar utility. Product behavior is specified in `docs/PRODUCT-SPEC.md`; the task queue is in `docs/EXECUTION.md`.

## Current development

Open `UsageGrid.xcodeproj` in Xcode 27 and run the shared `UsageGrid` scheme for the macOS 14+ menu-bar app. Its bundle identifier is `com.plutonightlabs.UsageGrid`; `LSUIElement` keeps it out of the Dock. Debug launches assert that `Bundle.main.bundleIdentifier` matches. The project builds the canonical files in `Sources/UsageGrid` and uses ad hoc local signing.

The Swift package remains for command-line `swift build` and `swift test` with the existing parser tests. It uses those same source files; its executable is not the distributable app bundle. To validate the app target, run `xcodebuild -project UsageGrid.xcodeproj -scheme UsageGrid -destination 'platform=macOS' -derivedDataPath DerivedData ARCHS=arm64 build`. `DerivedData` and Xcode user state are ignored by Git.

## Release / Beta Build

From the repository root, with Xcode 27 selected:

```sh
xcodebuild -project UsageGrid.xcodeproj -scheme UsageGrid -configuration Debug -destination 'platform=macOS' -derivedDataPath DerivedData ARCHS=arm64 build
swift test
xcodebuild -project UsageGrid.xcodeproj -scheme UsageGrid -configuration Release -destination 'platform=macOS' -derivedDataPath DerivedData ARCHS=arm64 build
xcodebuild -project UsageGrid.xcodeproj -scheme UsageGrid -configuration Release -destination 'generic/platform=macOS' -archivePath DerivedData/T13-Universal/UsageGrid.xcarchive -derivedDataPath DerivedData archive
```

The Release app is `DerivedData/Build/Products/Release/UsageGrid.app`; the archive contains `Products/Applications/UsageGrid.app` with both arm64 and x86_64 slices. Both output locations are ignored by Git. Release has Hardened Runtime enabled, but this Mac currently has no valid Developer ID Application identity or configured Development Team, so builds remain ad hoc signed. No entitlements or App Sandbox are configured. It is suitable for local testing; it is not yet signed or notarised for external distribution. Once a valid Developer ID Application identity and Team are available, configure Release signing in Xcode, then repeat the Release build, archive, signature checks, and packaged-app runtime checks before notarisation. Store future notarisation credentials in the macOS Keychain or an external secure system, never in this repository. Live Codex usage uses the ChatGPT app's bundled Codex executable. Current releases place its launcher at `/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex`; UsageGrid also recognizes the native executable inside that bundle and the legacy `Resources/codex` location. Claude live usage is not supported.

### Troubleshooting Codex usage

- **Executable not found:** update or reinstall ChatGPT in `/Applications`. UsageGrid does not silently switch to an unrelated shell `PATH` executable.
- **Signed out:** run `codex /status` in Terminal and sign in there if requested. UsageGrid inherits the normal user environment and Codex configuration location; it does not copy or log credentials.
- **Initialization failed/timed out:** quit and reopen ChatGPT and UsageGrid, then retry. Check Console.app for the `com.plutonightlabs.UsageGrid` / `CodexUsage` category.
- **Request rejected/timed out:** confirm `codex /status` works for the same macOS user, then retry.
- **No supported usage windows:** update UsageGrid if `/status` still displays usage. Unknown plan metadata and absent optional windows are ignored, but at least one valid usage window must be present; missing usage is never shown as zero.

Diagnostic logging records only failure categories and window counts. It does not record tokens, credentials, account identifiers, or complete provider payloads.

## T01 repository and Mac baseline

- Starting directory on 22 September 2026: planning documents and reference PNGs only; no `.git`, app code, project, tests, or `AGENTS.md`. No unrelated source changes were present.
- Host: Apple Silicon Mac mini, macOS 27.0.0 (Darwin 27.0.0, arm64).
- Active developer directory: `/Library/Developer/CommandLineTools`. Swift: Apple Swift 6.4 (`swiftlang-6.4.0.34.1`). macOS SDK: 27.0. Xcode app was not found in `/Applications`; `xcodebuild -version` fails because the active directory is Command Line Tools.
- Structure: `Package.swift` defines a macOS 14+ executable target and a test target. `Sources/UsageGrid` contains a placeholder SwiftUI app. `Tests/UsageGridTests` contains a target link smoke test. There are no third-party dependencies.

From this directory, run `swift build` and `swift test`. On this host, `swift build` passed (with Command Line Tools linker-search-path warnings). `swift test` compiled the app but failed compiling the test target because the Command Line Tools installation could not find `TestingMacros.TestDeclarationMacro`. The initial sandboxed test attempt also hit compiler-cache permissions; an unrestricted retry isolated the missing macro plugin. These checks establish a command-line executable build, not a packaged `.app` or Xcode build.

The full Xcode 27 toolchain was installed after this initial check. The current app target and commands are described above.
