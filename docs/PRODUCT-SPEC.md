# UsageGrid — Product specification

Version 1.0 • 21 September 2026 • Build brief for Codex

Status: planned, not implemented. Product owner: Tom. This document defines the proposed build baseline; technical spikes must verify integration feasibility before commercial promises are made.

## 1. Product and scope

UsageGrid is a local-first macOS menu-bar app that makes AI coding quota visible through a themed 100-cell Usage Matrix. Tagline: “AI coding usage, at a glance.” UsageGrid is the product; Usage Matrix is its visualization. It is an independent utility, not an official OpenAI or Anthropic product.

Primary job: “Show how much Codex or Claude Code capacity I have used, when it resets, and whether my current pace could reach the limit.” Secondary job: make that information enjoyable to keep open through expressive themes. Owner clarification: both providers' core meters must work in the free version; provider access is not a Pro gate.

Build a small native utility, not a web dashboard. Proposed baseline: Swift and SwiftUI, macOS 14+, Apple Silicon first; verify platform/toolchain compatibility in slice S0. Use AppKit only where menu-bar and window behavior needs it. No hosted usage database, UsageGrid account, prompt capture, or AI inference calls.

### Release boundaries

| Stage | Required scope |
| --- | --- |
| Working prototype | Mock data, menu-bar panel, accurate grid, two free themes |
| Private beta | Real Codex and Claude Code adapters, reset countdowns, honest error states, all eight themes available for testing |
| Paid 1.0 | Eight polished themes, Free/Pro entitlement, local history, defensible forecasts, opt-in alerts, tested purchase/restore and signed distribution |
| Conditional extension | Token breakdowns and actual session logs only after separate feasibility approval |
| Later | Desktop WidgetKit widget, more providers/themes, richer analytics |

Out of scope for 1.0: Windows/Linux, mobile/watch app, cloud sync, team dashboards, hosted alerts, custom theme editor, autonomous quota resets, automatic credit purchases, model switching, scraping provider websites, and reading prompt/source-code content. An expandable menu-bar panel is not a WidgetKit widget.

## 2. Commercial model

Planning price: £14.99 one-time Pro; optional £9.99 launch offer. No recurring subscription in 1.0. Prices are product proposals, not validated willingness-to-pay findings. Do not enable charges before the owner approves the checkout/distribution provider and final terms.

| Capability | Free | Pro |
| --- | --- | --- |
| Codex and Claude Code current usage and available quota windows | Both providers | Both providers |
| Reset countdown, freshness and connection errors | Yes | Yes |
| Menu bar, compact panel, expanded view | Yes | Yes |
| Programming and Professional themes | Yes | Yes |
| Retro, Anime, Zen Forest, Space, Christmas, Halloween | Preview only | Apply and persist |
| Local usage history and CSV export | No history UI | Yes |
| Quota burn-rate estimate and time-to-limit forecast | No | Yes, when sufficient data |
| Configurable threshold notifications | No | Yes |
| Switch between Codex and Claude Code | Yes | Yes |

All six paid themes form one Pro bundle; no separate seasonal payment in 1.0. Preview means a clearly labeled sample preview, not an unlocked live theme. Closing preview restores the previous theme. Free users always retain a fully usable meter.

Pro grants permanent use of purchased features, not a guarantee that external providers will maintain compatibility forever. Publish precise update/support terms before selling; do not promise every future provider or cloud service for life. No ads, tracking-based monetization, or recurring upsell modal.

Entitlements must be centralized, not scattered UI booleans. Implement a replaceable EntitlementService with free, pro, checking, and verification-error states. Persist verifiable purchase evidence securely; never ship a hard-coded unlock key or trust a preferences flag. Previously verified purchases must have a documented offline policy. Purchase cancellation/failure leaves existing rights unchanged. Revocation falls back to a free theme without deleting history. Export/delete of a user's already-collected data remains available after entitlement loss.

## 3. Data truth and integration gates

Official documentation checked on 21 September 2026: [Codex App Server](https://learn.chatgpt.com/docs/app-server). It documents `account/rateLimits/read`, `account/rateLimits/updated`, and `account/usage/read`. Rate-limit data can contain multiple buckets and optional windows; token summaries/daily buckets may be absent. These are distinct data types: quota percentage is not a token allowance. Documentation does not establish that every installed client/account supports every field.

S0 must validate the installed Codex version, initialization handshake, authorized authentication path, actual response shape, and account coverage. Record sanitized fixtures and evidence. Do not infer missing API availability from screenshots or this specification.

Use a read-only adapter through the supported local app-server interface, with the user's existing authorized Codex installation. Do not extract/copy credentials, cookies, browser sessions or authentication files. Let the provider manage its login. UsageGrid must never initiate a coding turn merely to measure usage, spend credits, consume reset credits, or send provider emails.

The adapter must expose capability flags independently: quota windows, daily token totals, timestamped token events, session metadata. A summary/daily endpoint is not proof of real-time tokens/minute, model attribution, or per-session history. These optional features remain disabled until a suitable source and semantics are demonstrated.

Support arbitrary provider-returned window durations. Show “5-hour” or “Weekly” only for a verified corresponding window; otherwise show its actual duration or neutral provider label. Never hard-code Monday resets or fabricate a weekly bucket. Preserve separate model/product buckets when returned; do not add percentages or treat an arbitrary bucket as account-wide.

Claude is a required S0 feasibility task: verify an authorized, permitted, maintainable data source on the target plan, using current official Anthropic documentation and real target-account evidence. Its data source is not yet verified by this planning task. No private endpoint assumptions. If unsuccessful, block the two-provider launch and ask the owner for direction; do not silently ship Codex-only or move Claude behind Pro. Provider subscriptions, installations and supported-plan prerequisites are separate from UsageGrid's free tier: UsageGrid does not grant free access to either coding service.

## 4. UX and behavior

### First run

1. Explain local data handling and each provider's verified installation/sign-in prerequisites.
2. Offer Connect Codex, Connect Claude Code and Try demo. Users can connect either or both; neither connection requires Pro. Demo is explicitly labeled everywhere; it never sends quota alerts.
3. Detect installation or let the user select the executable; do not silently install software.
4. Read connection status. Guide missing installation, signed-out, unsupported version and unsupported auth separately.
5. Show the first supported window; offer optional launch-at-login after successful setup.

No UsageGrid purchase is needed to see real supported Codex or Claude Code usage. Each provider connects independently; a failure in one must not suppress the other. No notification permission prompt until the user enables alerts.

### Menu-bar item

Default text: compact grid icon plus `62% used`. User may choose icon-only. Tooltip/accessibility label names provider, bucket/window, used percentage and freshness. Default selected window is the shortest supported window; selection persists per provider. The other windows remain visible in the panel, including a clear warning if another window is exhausted.

Unknown data displays an em dash, not 0%. Stale data gets a visible status marker. Do not silently switch from used to remaining. Menubar icon should remain legible using macOS light/dark menu-bar appearance rather than adopting unreadable theme colors.

### Compact panel

Target width 380 pt, content-led height around 450–560 pt; fit within the available display. Header: UsageGrid, status, settings. Then provider selector when more than one provider is supported, bucket/window control, Usage Matrix, percentage label, reset countdown, secondary-window summary and last-updated status. Footer: Expand, Refresh and accessible Quit via menu/settings. Pro can include a small estimate row without crowding the meter.

Click menu-bar item to toggle. Escape/outside click closes the transient panel. Keyboard focus order follows visual order. Refresh does not steal focus or resize the panel unexpectedly.

### Expanded view

Expand opens one reusable window, initial size about 620 × 760 pt, minimum 520 × 600 pt. Reopening focuses the existing window; it never creates duplicates. Closing it leaves monitoring active in the menu bar.

Order: compact theme selector → UsageGrid/Usage Matrix heading → provider → quota window → matrix → reset row → Burn rate and Estimated time to limit cards → Usage activity/history → footer status. Theme selector can open an eight-item gallery rather than consuming three rows permanently. Use scrolling for lower content at small sizes. Compact and expanded views share state and data.

The reference “Session log” becomes “Usage activity” initially. Show real observation/reset/connection events, not invented model or session records. Rename it to Session log only if actual session semantics are verified later. Omit the decorative live seconds clock; last successful update is more useful.

### Settings

General: launch at login, menu-bar display mode, preferred window, polling defaults. Appearance: theme, reduce effects; honor OS Reduce Motion. Pro: history retention, alert thresholds and export. Connection: status/version and reconnect instructions. Privacy: delete local history, diagnostics consent. Purchase: current entitlement, upgrade/restore or license recovery. About: version, support, licenses, independent-product notice.

## 5. Matrix and time semantics — mandatory

Latest screenshots override the earlier “remaining dots” concept: filled cells mean USED quota in every theme. Use 100 cells, 20 columns × 5 rows, left-to-right then top-to-bottom. Each cell represents one percentage point. The shape may change; the meaning cannot.

Keep raw precision in the domain model. Display nearest whole percent, ties rounded up; fill the same count of cells. At 62%, show exactly 62 filled cells. No half-lit cell unless a later approved fractional design changes both legend and tests. Legend: “1 cell = 1%”; label “62% used · 38% left.” Clamp drawing to 0–100 but report invalid source values diagnostically rather than treating malformed data as valid. Missing/invalid input shows a neutral unavailable state.

Reset countdown is `max(0, resetsAt - now)` using absolute UTC timestamps, formatted for local display. At expiry, show “Refreshing reset…” and fetch; do not assume usage has become zero. Missing reset time displays “Reset time unavailable.” Handle clock changes, DST and sleep/wake. Reset time and limit prediction must never share misleading labels.

### Forecast v1 (Pro)

Use quota percentage points per hour, not inferred tokens/minute. Proposed deterministic estimator: last 30 minutes, at least six valid samples spanning at least 15 minutes, latest sample no older than two minutes, no inter-sample gap over five minutes. All samples must have the same provider, account scope, bucket, window and reset epoch. Any quota decrease, reset timestamp change, account switch or invalid sample ends the estimator segment.

Burn rate = positive total percentage-point increase divided by elapsed hours in that segment. Require at least two percentage points of change to reduce integer-quantization noise. ETA = (100 − current used percentage) / burn rate. Label “Estimate at recent pace,” not a guarantee. Below thresholds display “Learning your pace”; flat usage displays “No recent measurable usage,” with no finite ETA. At 100% show “Limit reached.” Stale inputs suppress predictions. If the reset is earlier than the predicted limit, show “Reset expected first”; if reset time is unknown, disclose that comparison is unavailable. Suppress numeric forecasts beyond 24 hours as “More than 24h at recent pace.” Revalidate estimator quality during beta; do not manufacture confidence percentages.

Example test: 50% to 56% over 30 minutes gives 12 percentage points/hour; at 56%, ETA is 3h 40m unless reset occurs sooner. A daily token total must never be relabeled as tokens/minute.

### Alerts (Pro)

Defaults when enabled: 25%, 10%, 5% remaining, plus exhausted. Fire only on a fresh observed threshold crossing. If one sample crosses several thresholds, emit the most urgent one and mark all crossed thresholds handled. Dedupe by local account scope/provider/bucket/window/reset epoch/threshold and persist across app restarts. Baseline the first sample without sending a burst; the UI still shows current risk. Reset detection starts a new alert cycle. No alerts from demo, stale data, disconnected sources or forecast alone. Respect OS permissions and notification settings. Do not promise delivery while the Mac is asleep or the app is stopped.

## 6. Visual design system

All eight supplied PNGs were inspected. Their app content is the style reference; phone status bars, chat header, close/share icons and screenshot dimensions are not part of the macOS app. Palette values below are proposed implementation tokens, not sampled exact colors.

| Theme / reference | Tier | Canvas / surface / accent | Design language |
| --- | --- | --- | --- |
| Programming / IMG_7529.png | Free, default | #1E1E1E / #252526 / #4EC9B0 | Monospaced, square cells, syntax accents, restrained borders |
| Professional / IMG_7530.png | Free | #F3F4F6 / #FFFFFF / #2F6FED | Native system type, blue squares, subtle shadows |
| 90s Retro / IMG_7525.png | Pro | #190D29 / #25123B / #00E5DC | Cyan/magenta, square cells, pixel heading, faint grid and offset shadow |
| Anime / IMG_7526.png | Pro | #FFF1F7 / #FFFFFF / #F36BAD | Rounded pills, pink circles, restrained sparkles, dark readable body copy |
| Zen Forest / IMG_7527.png | Pro | #E8EFE7 / #F5F8F2 / #477E65 | Sage circles, thin borders, serif heading, optional faint forest/lake silhouette |
| Space / IMG_7528.png | Pro | #070A13 / #0E1426 / #80B8FF | Blue glowing circles, sparse static stars, geometric heading |
| Christmas / IMG_7531.png | Pro | #0C2B1B / #123925 / #F2CA49 | Gold circles, evergreen, red selected controls, restrained snow |
| Halloween / IMG_7532.png | Pro | #100B17 / #1B1327 / #FF9114 | Orange squares, purple borders, display heading, subtle pumpkin accent |

Theme tokens: canvas, surface, border, primary/secondary text, active/inactive cells, accent, warning, critical, focus ring, heading/body/metric font, cell shape/radius, card radius, shadow/glow, decoration. Semantic warning colors remain distinguishable from decorative accent colors and always include text/icons.

Use one component tree and eight token sets, not eight independent screens. Spacing scale: 4/8/12/16/24 pt. Compact panel padding 16 pt; expanded 24 pt. Default body 13–14 pt, labels at least 12 pt, primary metric 28–32 pt. Monospaced digits prevent layout shift. Decorative fonts belong in headings, not all tiny labels; fall back to system fonts. Ship only commercially licensed fonts and original/licensed art, never unlicensed anime characters.

Accessibility: target text contrast 4.5:1, large text/control boundaries 3:1 where applicable; test actual token pairs. Do not copy low-contrast labels from references. Focus rings and selected states must work without color alone. Expose the grid as one accessible summary, not 100 focus stops. Support VoiceOver, keyboard operation, text enlargement, Reduce Motion and increased contrast. Disable nonessential animation while hidden. Avoid continuous particle effects in 1.0; use static decoration and brief state transitions.

## 7. Architecture and local data

Proposed modules: AppShell; Domain; ProviderAdapters/Codex; ProviderAdapters/ClaudeCode; Persistence; Themes; Entitlements; Forecasting; Notifications; Tests. SwiftUI view models consume normalized domain state, never raw provider JSON. ProviderAdapter exposes status, capability discovery, fetch and optional update stream. Use a mock adapter for deterministic UI development. Keep provider-specific authentication and refresh logic independent; never reuse Codex protocol assumptions for Claude.

Transport: version-aware app-server client with documented initialization, framed message parsing, request IDs, timeout/cancellation, stderr redaction and owned child-process cleanup. Invoke an explicitly resolved executable without shell interpolation. Never kill the user's other Codex processes or open a network listener as a shortcut. Do not log raw authentication exchanges.

| Domain object | Minimum fields |
| --- | --- |
| ProviderStatus | providerId, state, capabilities, installedVersion, lastSuccessAt, safeError |
| QuotaWindow | accountScopeId, providerId, bucketId, windowId, durationMinutes?, usedPercent?, resetsAt?, observedAt, provenance, validity |
| UsageSample | id, scope/window keys, observedAt, usedPercent, resetEpoch, adapterVersion |
| ActivityEvent | id, scope, timestamp, kind, safeSummary; no prompt/code content |
| ThemeDefinition | stableId, displayName, requiredTier, visualTokens |
| AlertReceipt | scope/window/reset keys, threshold, firedAt |
| Entitlement | tier, source, checkedAt, verificationState; secrets outside ordinary preferences |

Use an opaque local account partition; never merge different accounts. Persistence proposal: SQLite with schema versioning, serialized writes and migrations. UserDefaults for harmless settings; Keychain for necessary app-owned secrets/license material. Usage storage contains numeric samples only. Default Pro history retention 30 days; optional 7/90 days. Free retains only current cache plus minimal operational alert/status state; enabling Pro starts history then, with no fabricated backfill. Official daily totals, if used later, remain separately labeled from observations collected by UsageGrid.

Startup reads cached data as stale until refreshed. Proposed polling: 60 seconds while running, refresh on open if cache older than 30 seconds, coalesce simultaneous requests. Supported notifications can update immediately. Apply provider throttling, exponential failure backoff to 15 minutes, no overlapping fetches, and debounce manual refresh. On wake, fetch once; do not replay missed ticks. Mark stale after two minutes without successful data; preserve last value with timestamp but disable forecasts/alerts. Signed-out/unsupported errors have explicit actionable states rather than infinite retries.

Provide CSV export with UTC times, provider, bucket/window, percentage, reset time and provenance; no credentials or source content. Escape values safely. Delete history requires confirmation and leaves provider login untouched. App removal/privacy instructions must explain any remaining local files.

## 8. Quality and release gates

Required tests: 0/1/62/99/100% and rounding, absent/invalid windows, multi-bucket mapping, UTC/DST/reset boundary, stale cache, account switch, app-server disconnect/timeout, parsing unknown fields, forecast segmentation, alert dedupe, entitlement preview/apply/restore/revocation, SQLite migration/retention/export/delete.

UI verification: every theme at normal, empty, exhausted, stale and error states; keyboard and VoiceOver; small-screen fit; menu-bar light/dark; multi-monitor and sleep/wake; repeat expand/close without duplicate windows. Use sanitized fixtures, not live user secrets in CI. Run Swift unit tests and macOS UI/build checks on a Mac runner; Linux-only checks are not proof the app builds.

Proposed performance budgets: cached panel visible within 200 ms on target Mac; hidden idle average CPU under 1% over ten minutes; memory under 150 MB app-only with separately measured provider child process; no continuous animation while hidden. Record actual measurements and revise budgets explicitly if needed.

Release requires owner approval for distribution/payment choice, signing credentials, final price/support terms, privacy notice and asset licenses. Prefer direct signed/notarized distribution initially if external local-process integration makes store constraints unsuitable; S0 must assess this, not assume store acceptance. No automatic publishing or purchases by Codex. Test on a clean Mac/user profile; confirm missing Codex is handled, purchase recovery works, usage stays local, and update/rollback procedures exist.

## 9. Success criteria and open decisions

Private beta: recruit 5–10 volunteer Mac/Codex users; seek a first real reading in under three minutes for already-configured users; record whether values agree with the provider at comparable times; verify users understand used vs remaining and reset vs forecast. Collect feedback manually or opt-in, not through default analytics. Review repeat use and theme purchase interest before widening scope.

Owner decisions before sales: £14.99/launch discount confirmation; purchase provider; offline licensing policy; support/update promise; minimum macOS version after spike. Technical decisions before real integration: supported installed Codex and Claude Code versions/accounts, distribution constraints and actual capability matrix. Both free integrations are required for launch; unverified Claude access is a launch blocker, not permission to remove it from Free.
