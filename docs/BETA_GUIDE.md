# UsageGrid tester guide

UsageGrid is a free macOS 14+ menu-bar utility. There is currently no signed or notarised public build; use a locally built copy for testing. The app is independent of OpenAI and Anthropic.

## Setup

Install ChatGPT in /Applications and sign in to Codex for the same macOS user. Open the UsageGrid menu-bar icon; Settings → Help explains connection errors. Codex is the only independently refreshed source. The Claude tab is an **experimental passive snapshot**: see [Claude Usage Integration](CLAUDE_USAGE_INTEGRATION.md) for opt-in setup, coexistence with an existing status line, and removal. Its Refresh action rereads the local file only.

## What to check

1. Open all five Settings tabs. Select each of the six themes, quit and reopen, and confirm the selected theme persists.
2. Choose a menu-bar display mode and window. Confirm missing data is unavailable and stale data is labelled.
3. If desired, enable local history; after two fresh Codex readings, view the compact card and full chart. Confirm Clear History asks before deleting.
4. If desired, enable primary and secondary threshold or reset alerts. Notification permission is requested on opt-in. A reset alert requires a later fresh reading that confirms rollover.
5. Use Support diagnostics, review the snapshot before copying, and confirm it contains no raw credentials, account details, paths, or usage values.
6. Check Claude's experimental/missing/stale guidance without assuming a missing snapshot identifies a specific cause.

Record the macOS/Xcode versions, app build, exact steps, and expected/actual result. Do not include credentials, raw provider payloads, or private usage history in a report. Automated tests and rendered fixtures do not establish physical-device interaction, accessibility, or release approval.
