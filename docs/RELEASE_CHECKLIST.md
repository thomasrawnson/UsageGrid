# UsageGrid publication review checklist

Status: review pending. This checklist does not authorise publication.

- [ ] Swift tests pass on a supported Mac.
- [ ] Debug and Release Xcode app builds pass; inspect the built app and launch it.
- [ ] All six themes, saved choices, full local history/session view, secondary threshold and observed-reset alerts work without entitlement.
- [ ] Existing history and UserDefaults survive upgrade; unrelated Keychain entries and provider authentication remain untouched.
- [ ] Codex setup and error states remain accurate. Claude remains labelled an experimental passive snapshot, including its local Refresh action and removal guide.
- [ ] Settings, popup navigation, notifications, large text, keyboard access, and VoiceOver receive manual Mac checks.
- [ ] App icon and included screenshot rights are confirmed or uncertain images are replaced/removed.
- [ ] Git history and current files receive a final sensitive-data and third-party licence review.
- [ ] README, privacy statements, MIT notice, and Pluto website listing agree with the tested build.
- [ ] If distributing a binary, Developer ID signing, notarisation, packaged-app runtime, and clean-Mac installation are verified. Current ad hoc builds are local development artifacts only.

Build locally with a derived-data directory chosen for the machine; do not use an absolute developer-specific path. Do not use Gatekeeper bypass commands.
