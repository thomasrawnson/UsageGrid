# UsageGrid Release Checklist

Last verified: 28 September 2026

This record covers the Release artifacts built during UG-R07. Earlier Debug checks are supporting history only.

## Commands and artifacts

Run from the repository root:

```sh
swift test
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

- `swift test`: 33 tests passed.
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
- Source/build inspection found no Release mock or sample usage path. The only `DEBUG` block is a development bundle-ID assertion, and Release has no `DEBUG` compilation condition.
- Release compiler inputs include Settings, usage alerts, menu-bar display, and first-run setup guidance.
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

