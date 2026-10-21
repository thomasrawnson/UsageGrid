# UsageGrid product specification

Status: current free utility as of UG-OSS-02. Earlier commercial plans are retired; Git history preserves their context.

UsageGrid is an independent, local-first macOS 14+ menu-bar app that displays coding quota as a 100-cell grid. All six implemented themes, real local history/session views, and primary/secondary threshold and observed-reset alerts are available without entitlement. No UsageGrid account or payment is required. Provider subscriptions and eligibility remain separate.

Codex is refreshed through ChatGPT's local bundled Codex executable. A missing or invalid window is unavailable, never zero. Later failures retain the last reading with a stale label. Claude is an **experimental passive snapshot** captured through an opt-in Claude Code status line. It does not independently refresh usage, change Claude settings, or establish official provider support. Menu-bar usage, alerts, and history currently track Codex only.

History recording is off by default and stores observation time, window type/duration, reset time, and percentage used locally for up to seven days and 25,000 samples. It is cleared by the user. Alerts request macOS permission only when enabled; reset notifications require a confirmed rollover in fresh observed readings. Support diagnostics use a fixed allowlist and require an explicit copy action.

Current themes: Programming, Professional, 90s Retro, Anime, Zen Forest, and Space. Legacy saved identifiers fall back to Programming. Theme previews are isolated sample data and do not change the saved selection. There are no paid themes or feature gates.

Out of scope: cloud sync, hosted usage storage, scraping provider websites, credential extraction, unsupported quota inference, and additional provider capabilities without source evidence. The owner-reported provenance and limits of the app icon and rendered images are documented in ASSET_RIGHTS.md.
