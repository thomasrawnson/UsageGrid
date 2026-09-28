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

### Refresh and freshness

UsageGrid performs one Codex refresh at a time. Opening the panel, the regular 60-second refresh, manual Retry, and wake-from-sleep requests share the same coordinator, so overlapping triggers do not start competing app-server processes. Each refresh has one end-to-end timeout and always stops its child process on success, failure, timeout, or cancellation.

After a successful reading, a later failure retains the last known windows but labels them **Stale**, keeps **Last updated** fixed at the last successful time, and shows an actionable error with Retry. A successful retry replaces the entire reading and clears the stale state; if a newer response omits an optional window, that older window disappears. With no prior success, UsageGrid continues to show usage unavailable rather than zero or demo data. Duplicate wake notifications are coalesced and trigger a refresh without disrupting one already in progress.

### Menu-bar usage

Settings → Menu Bar controls whether the status item shows only its icon, the selected Codex window’s percentage used, or its percentage remaining. Icon only is the default. Primary and secondary window choices are persisted independently, and Settings uses the provider’s actual window-duration label whenever that window is available.

The menu-bar value comes from the same authoritative reading as the panel. A missing selected window displays `—` and never silently switches to another window. Retained data displays a compact `⚠︎` stale marker until a successful refresh replaces it. The accessible status-item label identifies Codex, the selected window, used or remaining value, and freshness. Preferences update the status item immediately and survive app restarts.

### Usage alerts

Settings → Usage Alerts can optionally notify when the Codex primary window reaches 80%, 90%, or 95% used; alerts are off by default and 90% is the default threshold. The threshold always means percentage **used**, regardless of whether the menu bar displays used or remaining quota. Notification permission is requested only when alerts are enabled. If permission is denied, UsageGrid leaves alerts off and links to Notification Settings rather than repeatedly prompting.

Alerts are evaluated only after a successful fresh reading from the existing refresh coordinator. Missing, stale, or failed readings never notify. Each identifiable primary reset window can alert at most once, including across app restarts and settings changes. A new reset timestamp starts a new eligible window. If Codex omits reset metadata, UsageGrid skips alert delivery because it cannot safely deduplicate that window. Delivery failures are shown in Settings and do not affect usage refresh.

When notification permission is granted, Settings also offers **Send test notification** even if automatic usage alerts are off. The test is explicitly labelled and contains no quota values. It does not change alert preferences or reset-window deduplication, and repeated clicks are briefly rate-limited. “Test notification requested” means macOS accepted the request; Notification Settings or Focus may still suppress the visible banner. Returning to Settings refreshes permission status after changes in System Settings.

## T01 repository and Mac baseline

- Starting directory on 22 September 2026: planning documents and reference PNGs only; no `.git`, app code, project, tests, or `AGENTS.md`. No unrelated source changes were present.
- Host: Apple Silicon Mac mini, macOS 27.0.0 (Darwin 27.0.0, arm64).
- Active developer directory: `/Library/Developer/CommandLineTools`. Swift: Apple Swift 6.4 (`swiftlang-6.4.0.34.1`). macOS SDK: 27.0. Xcode app was not found in `/Applications`; `xcodebuild -version` fails because the active directory is Command Line Tools.
- Structure: `Package.swift` defines a macOS 14+ executable target and a test target. `Sources/UsageGrid` contains a placeholder SwiftUI app. `Tests/UsageGridTests` contains a target link smoke test. There are no third-party dependencies.

From this directory, run `swift build` and `swift test`. On this host, `swift build` passed (with Command Line Tools linker-search-path warnings). `swift test` compiled the app but failed compiling the test target because the Command Line Tools installation could not find `TestingMacros.TestDeclarationMacro`. The initial sandboxed test attempt also hit compiler-cache permissions; an unrestricted retry isolated the missing macro plugin. These checks establish a command-line executable build, not a packaged `.app` or Xcode build.

The full Xcode 27 toolchain was installed after this initial check. The current app target and commands are described above.
