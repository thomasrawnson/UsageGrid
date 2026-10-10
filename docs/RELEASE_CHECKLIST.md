# UsageGrid Release Checklist

Last verified: 28 September 2026

This record covers the Release artifacts built during UG-R07. Earlier Debug checks are supporting history only.

## Current readiness summary

- **PASS — UG-C07 owner review:** the user confirmed that UG-C07 looks good. This is confirmation of the reviewed presentation only; it does not establish VoiceOver coverage, every keyboard path, exact clipboard behavior, or other checks still listed as NOT TESTED.
- **PASS — Beta documentation:** the tester-facing [Beta Guide](BETA_GUIDE.md) reflects the current Codex-only Free feature set, keeps internal Debug Pro checks separate, and does not describe ad hoc artifacts as externally distributable.
- **BLOCKED — External beta artifact:** no Developer ID Application identity or Development Team is configured, and notarisation has not been performed.
- **NOT TESTED — Signed installation:** installation, Gatekeeper acceptance, first launch, menu-bar appearance, and first Codex connection must be tested using the eventual signed and notarised artifact.

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
- UG-C04 focused alert/permission/access filter: 19 tests passed, covering independent thresholds, missing secondary data, per-window and restart deduplication, primary-state migration, Pro loss during permission lookup, and permission-refresh preference isolation. Notification delivery was injected; no real alert was sent.
- UG-C05 focused alert/access filter: 27 tests passed, including confirmed rollover, baseline and restart behavior, early metadata changes, percentage decreases, missing metadata, duration changes, stale gaps, independent windows, disable/re-enable, Pro loss, permission races, denied permission, delivery failure, and independent threshold/reset receipts. Notification delivery and observation times were injected; no real alert was sent.
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
- UG-C07 support-diagnostics tests cover known and unknown states, every Codex reader error category, Debug-simulation labelling, and a sensitive raw-error sentinel that cannot enter the allowlisted report. The Help report performs only a read-only notification-settings query; it does not start Codex, refresh usage, request permission, read logs, or inspect configuration.
- UG-C07 combined usage/history fixtures were rendered and visually inspected for Programming, Professional, 90s Retro, Anime, Zen Forest, and Space. Essential quota numerals, reset copy, chart axes/timestamps, and session-change values now use stable data typography while theme-specific headings, shapes, artwork, and framing remain intact. Premium normal/stale/unavailable/error boards were also inspected for status contrast and clipping.
- Popup history preview navigation is now in-place, resets to live usage on dismissal, and maps Escape to Back before popup dismissal. No parent tap gesture or custom outside-click monitor exists; the removed sheet presentation was the only separate lifecycle attached to the transient `MenuBarExtra` window.
- The vertical `ViewThatFits` root was removed after it regressed native `MenuBarExtra` size negotiation. The root now has a deterministic 350-point width and screen-bounded 160–640-point height, with a fixed header and one scrolling body. Native-host interaction remains NOT TESTED because the automation service cannot attach to this menu-bar-only app.
- Application logging is limited to refresh stages, failure categories, and window counts. Codex stderr is discarded; credentials, account identifiers, environment contents, and raw usage payloads are not logged.
- Usage alerts preserve the existing Free primary preference and receipt keys. Effective Pro access adds an off-by-default secondary toggle, independent threshold, window-labelled notification copy, separate reset receipt, and access recheck after asynchronous permission lookup. Missing secondary data does not affect primary delivery.
- Pro reset notifications are independently off by default for primary and secondary windows. They use only successful fresh readings, establish a process-local baseline without catch-up, require a passed prior reset plus a later same-duration reset timestamp, and persist separate per-window delivery receipts. No reset-time scheduling or extra refresh process was added.
- UG-P01 adds only an isolated licensing foundation: activation/validation/deactivation interfaces, fixed safe states, and a Keychain credential boundary. Eight focused tests passed for the unavailable production state, stored-credential validation, success/failure, duplicate prevention, obsolete completion, storage failure, store/product identity matching, secret-safe errors/diagnostics, and isolated activation-view rendering. Debug and Release arm64 builds passed. Release binary inspection found the unavailable activation copy and stable Keychain identifiers, but no injected test key/identity or Debug simulation copy. No Lemon Squeezy network service, checkout URL, product/store configuration, or production entitlement connection exists; the shared production Pro boundary remains Free.
- UG-P02 adds a Debug-only test License API client and Settings controls. Test responses must match Store `485681`, Product `1395768`, and Variant `2179685`; saved test credentials require online validation after restart. Test Keychain storage is separate from future production credentials, and Debug simulation remains independent. Release inspection for this slice must confirm the endpoint, test IDs, test namespace, and controls are absent and production remains unentitled.

## FAIL

- None found during automated Release verification.

## NOT TESTED

These require hands-on interaction with the newly built Release menu-bar app:

- Menu-bar modes: icon only, percentage used, and percentage remaining; both window selections and missing-secondary behavior.
- Preference persistence after quitting and relaunching the same Release path.
- Sleep/wake refresh and duplicate-wake coalescing.
- A retained stale reading followed by successful recovery.
- Usage Alerts toggle for not-requested, granted, and denied notification permission states.
- Pro secondary alert toggle, independent thresholds, missing-window status, separate reset-window deduplication, Pro-loss behavior, and preference retention using Debug simulation.
- Pro primary/secondary reset toggles, baseline-only first reading, no notification for early metadata changes, and fresh confirmed-rollover copy using Debug simulation.
- Test notification submission and whether macOS/Focus presents the banner.
- First-run setup guide layout, Retry, Open ChatGPT, Settings access, and automatic transition after first usable reading.
- Visual layout, wrapping, keyboard access, and light/dark menu-bar legibility.
- Support diagnostics in the native Settings window: selection, scrolling, exact Copy result, VoiceOver order, and layout at the smallest window and enlarged text. Confirm that refreshing the snapshot changes no usage, history, alert, or permission preference.
- Six-theme gallery and all four current reference-led Pro sample states; selected and Pro labels; Preview and Close keyboard access; text clipping and contrast in the actual Settings window.
- History opt-in, storage error, Clear History confirmation, actual-duration window labels, chart segmentation, and session freshness in the running app.
- Complete popup flow: open usage, enter history preview, interact with selector/chart/scroll background, Back or Escape to usage, outside-click dismiss, and reopen on usage. Confirm only one UsageGrid process remains.
- Confirm Release refuses to activate a premium theme from an edited saved preference. Purchasing remains unavailable by design.
- The Release app's panel-triggered refresh was not invoked by automation because `osascript` lacks Accessibility permission. The same bundled executable and request contract passed the privacy-redacted live probe above.
- Installation and first launch of a future Developer ID signed and notarised beta on a clean supported Mac, including menu-bar discovery, Codex connection guidance, notification permission, persistence, quit, and reopen.
- Manual Lemon Squeezy test-key activation, Pro-boundary review, restart validation, and deactivation in the Debug app. Automated mocked lifecycle coverage does not replace this private-key check. Transfer/refund behavior, production recovery/offline policy, and signed-artifact purchase testing remain UG-P03.

## BLOCKED

- External distribution signing: `security find-identity -v -p codesigning` reports zero valid identities. No valid Developer ID Application identity is available on this Mac.
- Team signing: Release build settings resolve no `DEVELOPMENT_TEAM`; the project deliberately uses `CODE_SIGN_IDENTITY = -` for local ad hoc signing.
- Notarisation: not attempted. It remains blocked until a valid Developer ID Application identity and Team are configured and the signed artifact is rebuilt and reverified.
- Signed-artifact installation: blocked until signing and notarisation are complete. When a signed beta exists, follow its release-specific installation instructions and verify a clean first launch; do not distribute the current ad hoc app or direct testers around Gatekeeper.
- Production Pro licensing: blocked pending UG-P03 live configuration and signed-artifact lifecycle testing, plus explicit approval of offline grace (seven days recommended), secure cache/cadence and detailed upgrade/support rules. £9.99 GBP one-time, three Macs and purchased-major-version entitlement are already confirmed requirements. See [UG_P03_READINESS.md](UG_P03_READINESS.md) for the full prerequisite and acceptance matrix. Apple status described above is historical local evidence, not a fresh account/identity check. UG-P02 test IDs are not production configuration.
- Automated menu-panel inspection: blocked by missing Accessibility permission for `osascript`; this does not block manual testing.

The current apps are locally runnable ad hoc builds with Hardened Runtime enabled. They are not Developer ID signed or notarised and must not be presented as ready for external distribution.

## Manual Release checks

Perform these against the exact Release path listed above and update each item to PASS or FAIL with notes:

- **NOT TESTED — Menu bar:** exercise all three display modes, primary/secondary selection, absent secondary data, stale indicator, and panel opening.
- **NOT TESTED — Persistence:** change menu-bar and alert preferences, quit, relaunch the same Release app, and confirm the choices persist.
- **NOT TESTED — Sleep/wake:** sleep and wake the Mac; confirm one coalesced refresh and no stuck loading state.
- **NOT TESTED — Stale recovery:** produce a temporary request failure after a success, confirm retained data is marked stale, then Retry and confirm freshness clears.
- **NOT TESTED — Alerts:** verify the toggle before permission, after Allow, after Deny, and after returning from System Settings; confirm no repeated permission prompt.
- **NOT TESTED — Pro per-window alerts:** with Debug Pro simulation enabled, configure different primary and secondary thresholds, confirm actual duration labels and missing-secondary copy, then disable simulation and confirm secondary controls/delivery stop while the Free primary preference remains active.
- **NOT TESTED — Pro reset notifications:** with Debug Pro simulation enabled, toggle primary and secondary reset notifications independently and confirm preferences persist; use injected automated coverage rather than waiting for a real rollover. Confirm the Settings explanation says delivery follows a fresh observed reset and may be later than the displayed time.
- **NOT TESTED — Test notification:** with permission granted, submit a test while automatic alerts are off and confirm the explicitly labelled notification or record the macOS/Focus suppression setting.
- **NOT TESTED — Setup guide:** inspect the panel and Settings guide, actionable error states, wrapping, keyboard access, and transition to the normal usage panel.
- **NOT TESTED — Theme previews in app:** inspect 90s Retro, Anime, Zen Forest, and Space in the actual Settings sheet; confirm sample labelling, Pro/selected labels, keyboard focus order, enlarged text, and Close behavior. Exported boards were inspected separately and passed for clipping/readability.
- **NOT TESTED — History UI:** inspect recording opt-in copy, Clear History confirmation, all chart empty/single/gap states, primary/secondary labels, storage-error copy, and sample-preview isolation in the running app.
- **NOT TESTED — Free/Pro boundary:** confirm Programming remains selectable and persistent, Preview never changes the active theme or live usage, and the Release app cannot permanently activate a premium theme without verified entitlement.
- **NOT TESTED — Debug Pro simulation:** enable the Debug-only toggle, apply each premium theme, confirm live/history styling changes together, view real history after two successful refreshes, disable simulation while viewing history, and confirm the popup immediately returns to Free usage with Programming fallback. Quit/relaunch and confirm simulation is off.
