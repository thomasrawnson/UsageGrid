# UsageGrid

Native macOS menu-bar utility. Product behavior is specified in `docs/PRODUCT-SPEC.md`; the task queue is in `docs/EXECUTION.md`.

## Current development

Open `UsageGrid.xcodeproj` in Xcode 27 and run the shared `UsageGrid` scheme for the macOS 14+ menu-bar app. Its bundle identifier is `com.plutonightlabs.UsageGrid`; `LSUIElement` keeps it out of the Dock. Debug launches assert that `Bundle.main.bundleIdentifier` matches. The project builds the canonical files in `Sources/UsageGrid` and uses ad hoc local signing.

The Swift package remains for command-line `swift build` and `swift test` with the existing parser tests. It uses those same source files; its executable is not the distributable app bundle. To validate the app target, run `xcodebuild -project UsageGrid.xcodeproj -scheme UsageGrid -destination 'platform=macOS' -derivedDataPath DerivedData ARCHS=arm64 build`. `DerivedData` and Xcode user state are ignored by Git.

## Release / Beta Build

See the [Beta Guide](docs/BETA_GUIDE.md) for the tester-facing product walkthrough and checklist. The [Release Checklist](docs/RELEASE_CHECKLIST.md) records verified artifacts, automated evidence, signing blockers, and remaining release checks. The planned Lemon Squeezy licensing lifecycle and current non-functional foundation are documented in [Pro Licensing](docs/PRO_LICENSING.md).

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

Settings → Help → **Support diagnostics** provides a selectable plain-text snapshot with an explicit Copy action. It is available in Free and Pro, stays on the Mac unless the user copies it, and does not refresh usage, start Codex, request notification permission, or read logs or credentials. The report is built from a fixed allowlist: app/OS/architecture, categorized connection and error state, reading freshness and elapsed time, the known executable source category, notification authorization/presentation settings, local-history status, and effective access (including an explicit Debug-simulation label). Unknown state remains labelled unknown or unavailable. Raw errors, paths, account details, usage values, history samples, notification contents, and reset timestamps are excluded.

### First-run Codex setup

Before the first usable reading, the Codex panel shows compact connection guidance derived from the real refresh result: connecting, supported executable not found, sign-in required, connection/request failure, or connected with no supported usage window. Retry uses the same shared refresh coordinator. If `/Applications/ChatGPT.app` exists, the panel can open it, but UsageGrid does not download software, run login commands, change Codex configuration, or request credentials.

UsageGrid currently discovers Codex only at these existing locations:

- `/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex`
- `/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex`
- `/Applications/ChatGPT.app/Contents/Resources/codex`

Codex must be signed in, and UsageGrid reads quota windows through the local Codex app-server integration. The in-app guide remains available from Settings after connection. A first success automatically replaces setup with the normal meter; later failures retain the last reading and use the stale-data flow. Claude remains unavailable and is not enabled by Codex setup.

### Refresh and freshness

UsageGrid performs one Codex refresh at a time. Opening the panel, the regular 60-second refresh, manual Retry, and wake-from-sleep requests share the same coordinator, so overlapping triggers do not start competing app-server processes. Each refresh has one end-to-end timeout and always stops its child process on success, failure, timeout, or cancellation.

After a successful reading, a later failure retains the last known windows but labels them **Stale**, keeps **Last updated** fixed at the last successful time, and shows an actionable error with Retry. A successful retry replaces the entire reading and clears the stale state; if a newer response omits an optional window, that older window disappears. With no prior success, UsageGrid continues to show usage unavailable rather than zero or demo data. Duplicate wake notifications are coalesced and trigger a refresh without disrupting one already in progress.

### Menu-bar usage

Settings → Menu Bar controls whether the status item shows only its icon, the selected Codex window’s percentage used, or its percentage remaining. Icon only is the default. Primary and secondary window choices are persisted independently, and Settings uses the provider’s actual window-duration label whenever that window is available.

The menu-bar value comes from the same authoritative reading as the panel. A missing selected window displays `—` and never silently switches to another window. Retained data displays a compact `⚠︎` stale marker until a successful refresh replaces it. The accessible status-item label identifies Codex, the selected window, used or remaining value, and freshness. Preferences update the status item immediately and survive app restarts.

### Themes and Debug Pro simulation

Settings uses five native tabs so navigation stays visible while each tab’s form scrolls: **General** contains Launch at Login, menu-bar display, and Debug-only simulation; **Appearance** contains the theme gallery, isolated previews, and the concise Free/Pro comparison; **Usage & History** contains local recording, storage status, preview, and Clear History; **Alerts** contains permission status, threshold/reset controls, and the test notification; **Help** contains Codex connection guidance and the app version. Changing tabs is presentation-only and does not refresh usage, request notification permission, send notifications, clear history, or alter preferences.

Programming and Professional are Free themes. Settings includes a compact six-theme gallery and isolated previews for four reference-led Pro themes: 90s Retro, Anime, Zen Forest, and Space. Each preview is explicitly labelled as sample data and shows normal, stale, unavailable, and error states without changing the saved theme, fetching usage, or evaluating alerts.

The current visual mapping is: Programming → `IMG_7529.PNG`, Professional → `IMG_7530.PNG`, 90s Retro → `IMG_7525.PNG`, Anime → `IMG_7526.PNG`, Zen Forest → `IMG_7527.PNG`, and Space → `IMG_7528.PNG`. Christmas (`IMG_7531.PNG`) and Halloween (`IMG_7532.PNG`) remain as design references but are deferred from the current offering. Preview boards exported during visual verification are in [`docs/rendered-theme-previews`](docs/rendered-theme-previews).

Theme typography keeps expressive faces in headings and decorative presentation while usage percentages, reset copy, chart axes, timestamps, and session-change values use stable, legible numerals. This preserves each reference-led identity without allowing decorative typography to reduce the clarity of operational data.

UsageGrid Pro is planned as a one-off purchase through Lemon Squeezy hosted checkout and licence-key activation for the directly distributed signed/notarised app. The 30 September launch pack confirms £9.99 GBP one-time, up to three Macs, and no expiry for the purchased major version; future paid major upgrades may be separate. Seven-day offline grace is recommended pending explicit approval and implementation; see the [UG-P03 readiness gates](docs/UG_P03_READINESS.md). Purchasing and production activation are not available yet. Production builds remain Free: a saved premium theme identifier or stored credential is not proof of purchase, and premium features require future authoritative validation of the configured UsageGrid store/product identity. Legacy Midnight, Paper, Aurora, Christmas, and Halloween saved IDs fall back to Programming. Codex remains the only live usage integration; previews do not imply Claude support.

Debug builds now include an internal **Settings → General → Lemon Squeezy test licensing** section for UG-P02. It uses Lemon Squeezy’s client-safe License API with test Store `485681`, Product `1395768`, and Variant `2179685`; all three must match a successful remote response before test Pro access is granted. The key and returned instance ID use a dedicated test-only Keychain namespace. A restart validates the saved instance online once and never silently activates another instance. Validation failure removes test access without deleting preferences or history. This test path is distinct from the in-memory Debug simulation, and both the test configuration and controls are compiled out of Release. Licence keys, instance IDs, provider payloads, and raw provider errors are never logged or included in Support diagnostics.

Debug builds contain a clearly labelled **Settings → Developer testing → Simulate Pro access** toggle. It is off at every launch and exists only in memory: it is not written to UserDefaults, read from an environment variable or command-line argument, and is not a purchase or production entitlement. While active, Settings and the popup show **Developer Pro simulation**; 90s Retro, Anime, Zen Forest, and Space can be applied to live usage and real recorded history. Turning it off immediately restores Free presentation. A saved premium selection is retained but Programming is used as the safe fallback until effective Pro access returns. The Release configuration compiles out the toggle and simulation-enabling state.

### Local usage history

Settings → Usage History includes **Record usage history on this Mac**, off by default. It consumes only successful fresh readings already produced by the shared 60-second refresh coordinator; it adds no polling or provider processes and records only observation time, primary/secondary window type, actual duration, reset timestamp, and percentage used. Samples with absent or unusable reset metadata are skipped. Data is stored atomically in Application Support, retained for at most seven days and capped at 25,000 samples. Turning recording off retains unexpired history; **Clear History** removes both memory and disk data.

Charts keep primary and secondary windows separate and never join different reset windows. Segments also break across application runs, missing-window observations, gaps over three minutes, and percentage decreases. No readings are interpolated and window percentages are never added together. Session change means the current UsageGrid process run: after two continuous primary readings it reports percentage points observed since the first reading. Rollover, discontinuity, clearing, or disabling/re-enabling resets that baseline; stale refreshes label the last observation rather than claiming it is current.

Process-run and missing-window segment boundaries are stored with the local history document so restarting UsageGrid does not reconnect previously separated chart lines. Boundary records contain only observation time and window type. Actual history and session-change values remain Pro-gated in production; Free presentation shows recording status and the isolated sample preview without exposing the real comparison.

With effective Pro access, the popup places a compact real-history card beneath live usage and provides **View history** for the larger in-place chart. Both include a primary/secondary window selector, recording/collecting/missing/error states, and the current-process observed session change. Copy distinguishes recorded observations from the current live reading. When recording is off, the popup links to Settings but does not enable recording. Removing access while the large history page is visible returns safely to the Free usage page.

**Preview usage history** in the popup and Settings remains available and uses fixed, clearly labelled sample data. It never reads or writes recorded history, refreshes usage, or evaluates alerts. Recorded data and deletion remain accessible to the recording controller without treating a preference as entitlement. Rendered chart, gap, single-observation, and empty-state boards for all six current themes are in [`docs/rendered-history-previews`](docs/rendered-history-previews). Combined live/history fixture boards at default and constrained height are in [`docs/rendered-pro-panel`](docs/rendered-pro-panel); fixtures validate rendering, not actual mouse, keyboard, scrolling, dismissal, or focus interaction.

The menu-bar popup uses in-place preview navigation rather than presenting a sheet from the transient menu window. **Back to usage** and Escape return to the live panel; dismissing and reopening starts on live usage. Its root has a predictable non-zero height bounded to the screen containing the menu-bar pointer; the header stays fixed while the body scrolls. Loading and successful readings therefore use the same host size without intrinsic-content feedback. Settings preview sheets keep their Close controls outside their scrollable bodies and use width-adaptive headers for enlarged text.

To exercise the complete Debug flow: launch the Debug app, open Settings, enable **Developer testing → Simulate Pro access**, then choose **Use theme** on a premium theme. In **Usage History**, enable **Record usage history on this Mac** only when you intend to change that preference. Return to the popup and complete two successful refreshes (the normal minute refreshes or the refresh button); after the second continuous primary reading, inspect the compact **Recorded history** section and its observed session change, then choose **View history**. Debug simulation itself never changes the recording preference.

### Usage alerts

Settings → Usage Alerts can optionally notify when the Codex primary window reaches 80%, 90%, or 95% used; this existing Free alert remains off by default with a 90% default threshold. With effective Pro access, the same section adds an independent secondary-window toggle and threshold, also off by default at 90%. Actual duration labels are used when available, and an absent secondary window is shown as unavailable without changing its saved preference. Thresholds always mean percentage **used**, regardless of whether the menu bar displays used or remaining quota. Notification permission is requested only when an alert is enabled. If permission is denied, UsageGrid leaves that alert off and links to Notification Settings rather than repeatedly prompting.

Alerts are evaluated independently only after a successful fresh reading from the existing refresh coordinator, with no extra polling. Missing, stale, or failed readings never notify. Each primary or secondary reset window can alert at most once, independently, including across app restarts and settings changes. Existing primary receipts retain their original storage key. If Codex omits reset metadata, UsageGrid skips that window because it cannot safely deduplicate it; a missing secondary never suppresses a valid primary alert. Notification copy names the relevant window. Delivery failures are shown in Settings, recorded against that window to avoid retry spam, and do not affect usage refresh.

Losing effective Pro access immediately stops secondary delivery while retaining its preference for possible later reactivation. The Free primary alert continues normally. The controller rechecks Pro access and the enabled preference after asynchronous permission checks. Notification permission changes never enable either alert automatically.

With effective Pro access, each available usage-window group also offers an independent **Notify when window resets** option. Both reset options are off by default and are stored separately from threshold alerts. UsageGrid does not schedule a notification for the displayed reset time: the first fresh reading establishes an in-memory baseline, and a notification is sent only after a later fresh reading confirms that the prior reset time passed and Codex supplied a later reset timestamp for the same window type and duration. The body reports the freshly observed percentage remaining without claiming the allowance is full. Missing or invalid metadata and duration changes establish a new baseline; early metadata changes and percentage decreases do not notify. Relaunching, re-enabling, or regaining Pro access also starts with a fresh baseline, so missed resets are never replayed. Reset receipts are persisted separately per window to prevent duplicate delivery.

When notification permission is granted, Settings also offers **Send test notification** even if automatic usage alerts are off. The test is explicitly labelled and contains no quota values. It does not change alert preferences or threshold/reset deduplication, and repeated clicks are briefly rate-limited. “Test notification requested” means macOS accepted the request; Notification Settings or Focus may still suppress the visible banner. Returning to Settings refreshes permission status after changes in System Settings.

## T01 repository and Mac baseline

- Starting directory on 22 September 2026: planning documents and reference PNGs only; no `.git`, app code, project, tests, or `AGENTS.md`. No unrelated source changes were present.
- Host: Apple Silicon Mac mini, macOS 27.0.0 (Darwin 27.0.0, arm64).
- Active developer directory: `/Library/Developer/CommandLineTools`. Swift: Apple Swift 6.4 (`swiftlang-6.4.0.34.1`). macOS SDK: 27.0. Xcode app was not found in `/Applications`; `xcodebuild -version` fails because the active directory is Command Line Tools.
- Structure: `Package.swift` defines a macOS 14+ executable target and a test target. `Sources/UsageGrid` contains a placeholder SwiftUI app. `Tests/UsageGridTests` contains a target link smoke test. There are no third-party dependencies.

From this directory, run `swift build` and `swift test`. On this host, `swift build` passed (with Command Line Tools linker-search-path warnings). `swift test` compiled the app but failed compiling the test target because the Command Line Tools installation could not find `TestingMacros.TestDeclarationMacro`. The initial sandboxed test attempt also hit compiler-cache permissions; an unrestricted retry isolated the missing macro plugin. These checks establish a command-line executable build, not a packaged `.app` or Xcode build.

The full Xcode 27 toolchain was installed after this initial check. The current app target and commands are described above.
