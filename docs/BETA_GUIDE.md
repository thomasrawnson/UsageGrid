# UsageGrid Beta Guide

UsageGrid is a macOS 14 or later menu-bar app that reads Codex usage windows through the local Codex app-server integration and presents them as a compact meter. It does not send prompts or upload usage data. Claude usage is currently unavailable.

External distribution is not ready yet. Use these instructions only with a future UsageGrid build that has been Developer ID signed and notarised. The current ad hoc development builds are for local development and must not be distributed as beta releases.

## Before you begin

UsageGrid needs ChatGPT installed in `/Applications` with a supported bundled Codex executable at one of these existing locations:

- `/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex`
- `/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex`
- `/Applications/ChatGPT.app/Contents/Resources/codex`

Codex must already be signed in. UsageGrid does not ask for credentials, run login commands, or search for unrelated executables on your shell path. If Codex usage does not connect, check that `codex /status` works for the same macOS user.

When a future signed beta is supplied, install and open it using the accompanying release instructions. Do not use Gatekeeper bypass commands. UsageGrid is a menu-bar-only app, so it does not remain in the Dock after launch; look for its grid icon in the menu bar.

## First launch and connection

1. Open UsageGrid and select its menu-bar icon.
2. While the first request is running, the panel shows **Connecting**.
3. If setup is needed, follow the panel’s specific guidance. It distinguishes a missing supported executable, required Codex sign-in, a connection/request failure, and connected-but-unavailable usage data.
4. Choose **Retry** after correcting the reported issue. The first usable reading automatically replaces setup guidance with the live meter.

Choose **Settings** at the bottom of the popup to open the General, Appearance, Usage & History, Alerts, and Help tabs. The setup guide remains available under Settings → Help.

## Reading usage

The popup shows provider-supplied usage windows, their percentage used, reset information when available, and the time of the last successful update. Missing windows remain unavailable; UsageGrid never substitutes zero or sample data for a live reading.

Settings → General → Menu bar display offers:

- **Icon only**
- **Icon + usage used**
- **Icon + usage remaining**

Percentage modes can use the primary or secondary window. If the selected window is absent, the menu bar shows `—` and does not switch to another window.

If a refresh fails after a successful reading, UsageGrid retains the last reading but marks it **Stale**. **Last updated** continues to refer to the last successful reading, and the menu-bar value has a stale indicator. Choose **Retry** to request a fresh reading. A successful retry replaces the retained data and clears the stale state.

## Free and Pro presentation

The current production experience is Free. It includes live Codex usage, all menu-bar display modes, Programming and Professional themes, the primary-window threshold alert, setup guidance, and support diagnostics.

Settings → Appearance also provides clearly labelled sample previews for the planned Pro themes: 90s Retro, Anime, Zen Forest, and Space. Sample previews do not replace live data or change the saved theme. A sample history preview is also available.

Purchasing and production Pro activation are unavailable. **Debug Pro simulation** is an internal development tool, not a purchase or beta entitlement, and is compiled out of Release builds.

## Optional local history

Settings → Usage & History contains **Record usage history on this Mac**. Recording is off by default and consumes only successful readings from UsageGrid’s existing refresh cycle. Data stays in local Application Support, is retained for up to seven days, and is capped at 25,000 samples.

Turning recording off stops new samples but retains unexpired data. **Clear History** asks for confirmation and removes recorded history from memory and disk. Free users can inspect the clearly labelled sample preview; viewing real history and session change is a planned Pro feature and is unavailable for production activation today.

## Notifications

The Free primary-window threshold alert is optional and off by default. Enabling it requests macOS notification permission if permission has not already been decided. A denied permission is not repeatedly requested; Settings provides guidance for changing it in System Settings. Thresholds mean percentage **used**, regardless of the menu-bar display preference.

With permission granted, **Send test notification** submits an explicitly labelled test without fetching usage or changing alert preferences. **Test notification requested** means macOS accepted the request. It does not confirm that a banner was visible: Notification settings, Focus, or delivery to Notification Centre without a banner can affect presentation.

Secondary threshold alerts and confirmed reset alerts are Pro features and cannot be production-activated yet. Reset alerts are observation-based: they require UsageGrid to receive a fresh reading that confirms a window rollover. A countdown reaching zero alone never triggers one, and the first valid reading only establishes a baseline.

## Support diagnostics

Settings → Help → Support diagnostics shows a selectable, privacy-safe plain-text snapshot. Review it before copying. It includes categorized app, connection, freshness, notification, history, and access state, but excludes credentials, account identifiers, raw errors, paths, usage percentages, history samples, notification contents, and reset timestamps. Nothing is uploaded or sent automatically.

## Quit and reopen

Choose **Quit UsageGrid** at the bottom of the menu-bar popup. To reopen a future installed beta, open UsageGrid again from the location specified by its signed release instructions. If Launch at Login is enabled in Settings → General, macOS can open it when you sign in.

## External Free beta checklist

Do not sign out, alter Codex configuration, delete application files, or deliberately manufacture a failure. Record naturally occurring failures instead.

- [ ] Obtain the first successful Codex reading and confirm its window labels and values are plausible beside `codex /status` at a comparable time.
- [ ] Try all three menu-bar display modes. If no secondary window exists, confirm selecting it shows `—` rather than `0%` or the primary value.
- [ ] Open and dismiss the popup at least five times. Scroll it, open a sample history/theme preview, and confirm Back or Escape returns to live usage before outside-click dismissal.
- [ ] Visit all five Settings tabs. Change only preferences you are comfortable changing, quit/reopen, and confirm those choices persist.
- [ ] Select Programming and Professional. Open each clearly labelled Pro sample preview and confirm live data and the saved Free theme do not change.
- [ ] After a normal sleep/wake, confirm UsageGrid refreshes and does not remain stuck loading. If a temporary failure occurs naturally, confirm retained data is marked stale and later recovers.
- [ ] With notification permission granted, use **Send test notification** with Settings open and closed. Record separately whether submission succeeded and whether a banner or Notification Centre entry appeared.
- [ ] Open Support diagnostics, review the snapshot, select some text, then use Copy and confirm the pasted snapshot matches what was displayed.

## Internal Debug Pro checks

These checks are for repository Debug builds only and are separate from the external Free beta. Debug simulation is not evidence of purchase or Release entitlement.

- [ ] Enable **General → Developer testing → Simulate Pro access** and confirm it is clearly labelled as simulation.
- [ ] Exercise premium theme selection, real history/session views, independent secondary thresholds, and primary/secondary reset controls.
- [ ] Disable simulation and confirm Pro delivery and real-history presentation stop while saved preferences are retained.
- [ ] Quit and reopen the Debug build and confirm simulation starts off.

## Bug-report template

Copy this template into whichever communication channel the beta coordinator provides. No support address, issue tracker, or upload destination is currently designated.

```text
UsageGrid beta bug report

App version/build:
macOS version:

Steps to reproduce:
1.
2.
3.

Expected behaviour:

Actual behaviour:

Frequency: once / sometimes / every time
Does it continue after quitting and reopening UsageGrid? yes / no / not tested

Optional support diagnostics:
[Review Settings → Help → Support diagnostics before pasting.]

Optional screenshot:
[Hide account details, notifications, filenames, menu-bar items, or other personal information before sharing.]
```
