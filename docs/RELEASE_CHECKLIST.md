# UsageGrid Release Checklist

Last verified: 28 September 2026

This record covers the Release artifacts built during UG-R07. Earlier Debug checks are supporting history only.

## Commands and artifacts

Run from the repository root:

```sh
swift test
xcodebuild -project UsageGrid.xcodeproj -scheme UsageGrid -configuration Debug -destination 'platform=macOS' -derivedDataPath DerivedData ARCHS=arm64 build
xcodebuild -project UsageGrid.xcodeproj -scheme UsageGrid -configuration Release -destination 'platform=macOS' -derivedDataPath DerivedData ARCHS=arm64 build
xcodebuild -project UsageGrid.xcodeproj -scheme UsageGrid -configuration Release -destination 'generic/platform=macOS' -archivePath DerivedData/T13-Universal/UsageGrid.xcarchive -derivedDataPath DerivedData archive
git diff --check
```

Artifacts:

- Local arm64 Release app: `DerivedData/Build/Products/Release/UsageGrid.app`
- Universal archive: `DerivedData/T13-Universal/UsageGrid.xcarchive`
- Universal archived app: `DerivedData/T13-Universal/UsageGrid.xcarchive/Products/Applications/UsageGrid.app`

The Release app launched for UG-R07 was:

`/Users/tomrawnson/Developer/UsageGrid/DerivedData/Build/Products/Release/UsageGrid.app`

## PASS

- `swift test`: 54 tests passed. Focused coverage includes stable screen-bounded popup sizing across loading/success states, Debug simulation off/on, shared theme/history access, access removal during premium history, safe premium-theme fallback without deleting the saved choice, process-local simulation reset, history isolation, and rendering the combined live/history panel across all six themes at default and constrained heights.
- Xcode arm64 Debug build completed successfully.
- Xcode arm64 Release build completed successfully.
- The configured generic macOS archive workflow completed successfully.
- `git diff --check` passed after the checklist changes.
- Both apps report bundle ID `com.plutonightlabs.UsageGrid`, version `0.1.0`, build `1`.
- Local Release executable architecture: `arm64`.
- Archived executable architectures: `x86_64 arm64`.
- `codesign --verify --deep --strict` passed for both apps.
- Both signatures have the Hardened Runtime flag. Both are ad hoc (`Signature=adhoc`, no Team identifier), so this is a local-runtime pass, not a distribution-signing pass.
- The exact local Release app path above launched and remained running. No installed app was overwritten and Launch at Login registration was not changed.
- The first configured bundled Codex path, `/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex`, initialized its app-server and returned supported primary usage-window field types through `account/rateLimits/read`. The redacted probe did not print usage values, account values, credentials, or raw payloads, and its launcher process exited afterward.
- Release has no `DEBUG` compilation condition. The developer simulation toggle, its mutable enabling state, status banner, and fixture-only renderer are all guarded by `#if DEBUG`.
- Release compiler inputs include Settings, usage alerts, menu-bar display, and first-run setup guidance.
- Release compiler inputs include the six-theme Free/Pro catalogue and isolated premium preview UI. Programming and Professional are Free; 90s Retro, Anime, Zen Forest, and Space are preview-only without entitlement. Christmas and Halloween are deferred. Purchasing and payment verification are not implemented.
- Release effective access uses the unchanged false verified-purchase placeholder. Source and built-product inspection found no developer-simulation control or enabling symbol in Release; there is no environment, argument, or UserDefaults bypass.
- Computed premium-preview text contrast against each theme surface passes WCAG AA for normal text: primary 9.48–16.56:1, secondary 5.01–9.41:1, and labelled success/warning/error text 4.77–12.58:1.
- Four current premium-theme boards were visually inspected against their source images. The boards contain normal, stale, unavailable, and error states with no observed clipping. See `docs/rendered-theme-previews/`.
- Local history is opt-in and uses fresh coordinator results without additional polling. The persisted JSON schema contains only observation time, window type, duration, reset time, and percentage used; retention is seven days and 25,000 samples. Chart/session previews use isolated sample data and production remains unentitled.
- Six history preview boards were rendered and visually inspected. An initial dark-theme axis contrast defect was fixed; the final chart, gap, single-observation, and empty states have readable 0–100% axes and no observed clipping. See `docs/rendered-history-previews/`.
- Popup/history and theme-sheet containers were rendered at default, reduced-height, and enlarged-text configurations. Their fixed headers and Back/Close controls remained visible; `ImageRenderer` did not render the contents of native `ScrollView`, so actual scrolling and interaction remain a manual check. See `docs/rendered-ui-fix/`.
- Combined live usage and recorded-history fixtures were rendered in all six themes at default and constrained heights and visually inspected. These renders do not prove mouse, keyboard, scrolling, Escape/Back, outside-dismissal, or reopening behavior. See `docs/rendered-pro-panel/`.
- Popup history preview navigation is now in-place, resets to live usage on dismissal, and maps Escape to Back before popup dismissal. No parent tap gesture or custom outside-click monitor exists; the removed sheet presentation was the only separate lifecycle attached to the transient `MenuBarExtra` window.
- The vertical `ViewThatFits` root was removed after it regressed native `MenuBarExtra` size negotiation. The root now has a deterministic 350-point width and screen-bounded 160–640-point height, with a fixed header and one scrolling body. Native-host interaction remains NOT TESTED because the automation service cannot attach to this menu-bar-only app.
- Application logging is limited to refresh stages, failure categories, and window counts. Codex stderr is discarded; credentials, account identifiers, environment contents, and raw usage payloads are not logged.

## FAIL

- None found during automated Release verification.

## NOT TESTED

These require hands-on interaction with the newly built Release menu-bar app:

- Menu-bar modes: icon only, percentage used, and percentage remaining; both window selections and missing-secondary behavior.
- Preference persistence after quitting and relaunching the same Release path.
- Sleep/wake refresh and duplicate-wake coalescing.
- A retained stale reading followed by successful recovery.
- Usage Alerts toggle for not-requested, granted, and denied notification permission states.
- Test notification submission and whether macOS/Focus presents the banner.
- First-run setup guide layout, Retry, Open ChatGPT, Settings access, and automatic transition after first usable reading.
- Visual layout, wrapping, keyboard access, and light/dark menu-bar legibility.
- Six-theme gallery and all four current reference-led Pro sample states; selected and Pro labels; Preview and Close keyboard access; text clipping and contrast in the actual Settings window.
- History opt-in, storage error, Clear History confirmation, actual-duration window labels, chart segmentation, and session freshness in the running app.
- Complete popup flow: open usage, enter history preview, interact with selector/chart/scroll background, Back or Escape to usage, outside-click dismiss, and reopen on usage. Confirm only one UsageGrid process remains.
- Confirm Release refuses to activate a premium theme from an edited saved preference. Purchasing remains unavailable by design.
- The Release app's panel-triggered refresh was not invoked by automation because `osascript` lacks Accessibility permission. The same bundled executable and request contract passed the privacy-redacted live probe above.

## BLOCKED

- External distribution signing: `security find-identity -v -p codesigning` reports zero valid identities. No valid Developer ID Application identity is available on this Mac.
- Team signing: Release build settings resolve no `DEVELOPMENT_TEAM`; the project deliberately uses `CODE_SIGN_IDENTITY = -` for local ad hoc signing.
- Notarisation: not attempted. It remains blocked until a valid Developer ID Application identity and Team are configured and the signed artifact is rebuilt and reverified.
- Automated menu-panel inspection: blocked by missing Accessibility permission for `osascript`; this does not block manual testing.

The current apps are locally runnable ad hoc builds with Hardened Runtime enabled. They are not Developer ID signed or notarised and must not be presented as ready for external distribution.

## Manual Release checks

Perform these against the exact Release path listed above and update each item to PASS or FAIL with notes:

- **NOT TESTED — Menu bar:** exercise all three display modes, primary/secondary selection, absent secondary data, stale indicator, and panel opening.
- **NOT TESTED — Persistence:** change menu-bar and alert preferences, quit, relaunch the same Release app, and confirm the choices persist.
- **NOT TESTED — Sleep/wake:** sleep and wake the Mac; confirm one coalesced refresh and no stuck loading state.
- **NOT TESTED — Stale recovery:** produce a temporary request failure after a success, confirm retained data is marked stale, then Retry and confirm freshness clears.
- **NOT TESTED — Alerts:** verify the toggle before permission, after Allow, after Deny, and after returning from System Settings; confirm no repeated permission prompt.
- **NOT TESTED — Test notification:** with permission granted, submit a test while automatic alerts are off and confirm the explicitly labelled notification or record the macOS/Focus suppression setting.
- **NOT TESTED — Setup guide:** inspect the panel and Settings guide, actionable error states, wrapping, keyboard access, and transition to the normal usage panel.
- **NOT TESTED — Theme previews in app:** inspect 90s Retro, Anime, Zen Forest, and Space in the actual Settings sheet; confirm sample labelling, Pro/selected labels, keyboard focus order, enlarged text, and Close behavior. Exported boards were inspected separately and passed for clipping/readability.
- **NOT TESTED — History UI:** inspect recording opt-in copy, Clear History confirmation, all chart empty/single/gap states, primary/secondary labels, storage-error copy, and sample-preview isolation in the running app.
- **NOT TESTED — Free/Pro boundary:** confirm Programming remains selectable and persistent, Preview never changes the active theme or live usage, and the Release app cannot permanently activate a premium theme without verified entitlement.
- **NOT TESTED — Debug Pro simulation:** enable the Debug-only toggle, apply each premium theme, confirm live/history styling changes together, view real history after two successful refreshes, disable simulation while viewing history, and confirm the popup immediately returns to Free usage with Programming fallback. Quit/relaunch and confirm simulation is off.
