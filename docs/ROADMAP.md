# UsageGrid roadmap

Status: free utility conversion. Earlier paid-release plans are retired; historical design decisions remain in Git history.

## Current baseline

Native macOS 14+ menu-bar app with Codex usage, six selectable themes, optional local history and session view, primary/secondary threshold and observed-reset alerts, and privacy-safe diagnostics. Claude Code is an **experimental passive snapshot** integration; it does not independently refresh usage. All implemented app features are free.

## Next review gates

1. Run Swift tests and Debug/Release Xcode builds on a supported Mac outside restricted tooling.
2. Inspect app launch, menu-bar/settings navigation, theme persistence, history, alert permissions, Claude wording, keyboard access, and large text on a physical Mac.
3. Preserve the owner-reported image provenance record in ASSET_RIGHTS.md; review any newly discovered third-party or personal content.
4. Review a signed/notarised distribution path only if a public download is later authorised.

Potential deeper metrics or provider work requires its own supported-source evidence and scope approval. No release or public download is authorised by this roadmap.
