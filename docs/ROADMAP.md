# UsageGrid — Implementation roadmap

Version 1.0 • 21 September 2026 • All slices initially NOT STARTED

Read UsageGrid-Product-Specification.md first. Complete one slice at a time. Estimates are focused developer-days including review, not guaranteed elapsed time; do not commit a launch date until S0 passes. Allow additional time for signing, checkout approval and beta feedback.

## Release sequence

| Slice | Deliverable | Depends on | Estimate | Gate |
| --- | --- | --- | --- | --- |
| S0 | Both-provider integration and distribution feasibility | None | 2–3 days | Real sanitized quota responses from Codex and Claude or explicit blocker |
| S1 | Native shell and deterministic demo | S0 platform decision | 1–2 days | Menu bar/expand behavior works on Mac |
| S2A | Reliable real Codex meter, Free | S0, S1 | 2–3 days | Accurate live data, no invented values |
| S2B | Reliable real Claude Code meter, Free | S0, S1 | 2–4 days | Accurate live data and independent provider switching |
| S3 | Shared design system and six current themes | S1; integrate S2 | 2–4 days | Visual acceptance and accessibility |
| S4 | Local history, forecasts and alerts | S2, S3 | 2–4 days | Deterministic calculations and dedupe |
| S5 | Pro purchase and entitlement | S3, owner commercial choices | 2–4 days | Verified purchase/recovery/offline cases |
| S6 | Hardening, beta feedback and release | S2–S5 | 2–4 days plus beta | Signed tested build and owner release approval |
| S7 | Optional deeper metrics and additional providers | Independent source approval, S6 | Spike first | Supported integration or defer |

S2 means both S2A and S2B in dependencies below. Private beta can begin after S3 with demo Pro entitlements in non-release builds; no charging until S5/S6. The current catalogue contains six themes; the Christmas and Halloween concepts are deferred for later consideration. Both Codex and Claude Code must work in Free before the planned two-provider beta/launch. An internal Codex-only prototype is allowed but is not completion of that release requirement.

## S0 — Prove the data path

Goal: establish that the core promise can be delivered on the target Mac without unsupported credential access.

Tasks:

- Inspect repository, AGENTS.md, OS and Xcode/Swift toolchain before changing anything. If no repo exists, propose a minimal Xcode app plus testable domain package.
- Check current official app-server protocol and locally installed Codex version. Record versioned documentation links and exact reproducible read-only test steps.
- Verify initialization, account status, quota read and update notifications where supported. Capture redacted fixtures for normal, missing-window, error and multi-bucket cases.
- Separately establish which summary/token capabilities exist; no token-per-minute claims based on daily data.
- Evaluate local process access, signing and distribution approach; do not choose payment vendor or acquire credentials on the user's behalf.
- Independently investigate Claude Code's supported usage source using current official Anthropic documentation, authorized authentication and a real target account. Do not assume Codex endpoints apply to Claude. Record supported plans, windows, source coverage and limitations.
- Write docs/INTEGRATION-FEASIBILITY.md with supported/unsupported/unknown matrix for both providers, security boundaries and go/no-go result.

Acceptance:

- A real quota percentage and its available reset metadata are observed from authorized target accounts for both providers; optional fields documented accurately. Either provider's unproven quota source blocks the two-provider release.
- No prompt run, charge, reset-credit consumption or credential extraction occurs.
- App-server minimum tested version and OS/toolchain are recorded, not guessed.
- If no Mac/authenticated target exists, report S0 BLOCKED with exact manual verification steps. A fixture demo is not integration proof. Owner can authorize UI-only work while this remains blocked.

Handoff: evidence report, sanitized fixtures, chosen architecture decision and next smallest task. No full UI build in S0.

## S1 — Native shell and mock vertical slice

Tasks: app lifecycle; menu-bar item; compact view; one expanded window; mock ProviderAdapter; normalized domain types; settings skeleton; Programming/Professional themes; centralized mock entitlement service in debug only.

Acceptance:

- Deterministic 62% fixture lights exactly 62/100 cells in both views and labels used/remaining consistently.
- Menu click, Escape, outside-click, Expand and close follow specification; app stays alive when full view closes.
- Window/provider selection persists; changing mock state updates both surfaces.
- Demo badge is always visible; no alerts, network requests or live-data claims.
- Tests cover boundaries, fractional rounding, unavailable data and display labels.

Exclude real provider integration, billing SDK, charts and eight separate screen implementations.

## S2A — Reliable Codex connection, included in Free

Tasks: version-aware adapter and read-only transport; connection onboarding; dynamic buckets/windows; freshness; countdowns; polling/backoff; wake/reconnect; safe local current cache.

Acceptance:

- On a configured Mac, a fresh value and reset display agree with the matching provider bucket/window at comparable timestamps; discrepancies are investigated.
- A missing weekly window is unavailable, never 0% or fabricated. Multiple buckets remain separate.
- Signed-out, missing executable, unsupported auth/version, offline, malformed response and rate-limited states are distinct and recoverable.
- Past reset time triggers refresh, not optimistic quota clearing. Wake causes one refresh, not a request storm.
- Secrets never appear in logs, fixtures or database. Only UsageGrid-owned processes are stopped on quit.
- All DTO mapping and lifecycle tests pass on supported macOS toolchain.

Gate: working Codex vertical slice. If integration fails, stop dependent features; do not hide failure behind demo data. Complete S2B before calling the two-provider free product ready.

## S2B — Reliable Claude Code connection, included in Free

Tasks: implement the independently verified Claude adapter, onboarding, usage windows, reset metadata, refresh/error states and local cache. Reuse normalized UI/domain components, not provider-specific transport assumptions.

Acceptance:

- A Free user can connect Claude Code without connecting Codex, purchasing Pro or entering payment details.
- The meter and reset metadata agree with the supported Claude source for the same account/window; unsupported fields remain unavailable.
- A Free user can connect both providers and switch between them; selection, cache, history scope and reset metadata never mix.
- One provider's outage/sign-out does not disable the other. Missing install/auth, unsupported plan, expired login, throttling and malformed responses have safe recovery paths.
- Adapter contract tests and real Mac/account checks pass; no credential scraping, unapproved private endpoint or invented quota data.
- Repeat S2A freshness, reset, wake, privacy and lifecycle checks for Claude. Forecast/history capabilities may differ, but core provider access never depends on entitlement.

Gate: both-provider Free MVP. If Claude quota access cannot be supported legitimately, stop and ask the owner; do not downgrade this requirement silently.

## S3 — Theme-led experience

Tasks: reusable visual tokens; theme gallery with previews/locks; four current Pro themes; compact/expanded layout polish; accessible semantic colors; licensed type/art; screenshot regression fixtures. Preserve the Christmas and Halloween source references as deferred concepts, not current catalogue entries.

Acceptance:

- All six current themes match the source-reference character while sharing component order and behavior.
- At 62%, every theme lights the same 62 cells. Changing theme never changes source/window/data.
- Theme choice persists; locked preview cancels cleanly; invalid stored theme falls back safely.
- No phone/chat controls from screenshots are copied. No misleading “time to limit / until reset” combination remains.
- VoiceOver summarizes matrix once; keyboard focus, contrast, enlarged text and reduced-motion checks pass.
- Screenshot review covers compact and expanded views at 0/62/100%, stale and error states.

Gate: private beta UI. Get owner visual approval before expensive further polishing.

## S4 — Useful local Pro features

Tasks: versioned SQLite observations, retention/CSV/delete, quota estimator, usage activity view, notifications with persistent threshold receipts. Keep optional token/session sources disabled unless separately proven.

Acceptance:

- Records are partitioned by account/provider/bucket/window; switching account cannot leak or mix history.
- Forecast tests cover 12 percentage points/hour example, flat data, insufficient samples, reset before limit, reset changes, decreases, stale data and collection gaps.
- Forecast copy states estimated; reset countdown remains a separate fact.
- Alerts request permission only on opt-in and fire once per crossed threshold per reset cycle, including restart and multi-threshold jump cases. The existing primary alert remains Free; effective Pro access adds an independently configured secondary-window alert with separate persisted receipts. Optional Pro reset notifications are observation-based rather than scheduled: the first fresh reading is a baseline, and only a later fresh reading confirming a same-duration rollover can notify, once per window and new reset timestamp.
- No quota alert from demo, stale data or a first-sample catch-up burst.
- Retention, migration, export and confirmed delete work; no fabricated historical sessions appear.

Gate: useful Pro behavior without billing. Beta feedback must confirm predictions help more than they mislead; otherwise ship “learning/unavailable” states and defer forecasting with transparent product-copy changes.

## S5 — Monetization, not a second platform

Current commercial-foundation UI: Settings is organised into native General, Appearance, Usage & History, Alerts, and Help tabs. A single compact comparison reflects the implemented boundary: live Codex usage, menu-bar display, Programming/Professional themes, the primary threshold alert, and privacy-safe support diagnostics remain Free; premium themes, real history/session views, the secondary threshold alert, and confirmed reset notifications require effective Pro access. Local history recording remains explicit opt-in. Debug simulation is clearly separate from a future verified purchase, and production access remains unchanged. Purchasing is not yet available. Support diagnostics use an explicit field allowlist and fixed error categories; they never expose raw provider errors, paths, identifiers, usage values, history samples, or credentials.

Owner gate: approve seller identity, final price, payment/distribution service, license/offline policy and support terms. Do not proceed with live commercial setup without those choices.

Tasks: one-time purchase adapter; centralized verified entitlement; purchase/recovery UI; offline verification policy; release/debug separation; clear privacy and upgrade copy. Use vendor-managed checkout/licensing where suitable rather than building a bespoke account server.

Acceptance:

- Test-mode purchase grants Pro only after valid verification; cancellation/failure never unlocks it.
- Recovery/restore after reinstall, offline previously-verified purchase, verification outage and revocation are tested against documented policy.
- Free core remains usable; Pro preview never permanently unlocks a theme.
- Non-release mock unlock paths are absent from production builds.
- Upgrade text lists shipped Pro features only. Codex and Claude access are explicitly Free; token/session breakdown and “all future services” are not sold as guarantees.
- Data remains exportable/deletable after entitlement loss. License logs are redacted.

Gate: checkout ready, not automatic permission to publish or charge users.

## S6 — Beta, hardening and signed release

Tasks: recruit 5–10 consenting beta users; run installation/reconnection and sleep/wake checks; fix critical issues; performance measurement; code signing/notarization; release notes; support/privacy pages; recovery/update checklist. Publishing requires owner approval.

Acceptance:

- Real Mac build, unit/UI tests and clean-profile install pass. Cross-platform static checks are not a substitute.
- No unresolved critical accuracy, credential, purchase or data-loss bugs.
- Each theme passes owner review; measured performance documented, including provider child-process costs.
- At least one extended workday test plus sleep/restart/account-change scenarios completed.
- Documentation states local-only history, external-service dependency and unsupported capabilities truthfully.
- Signed/notarized artifact and tested recovery procedure exist; owner approves exact release artifact and copy.

Suggested beta questions: Can you read usage at a glance? Do dots mean used or left? Is reset clearly different from estimate? Would you keep it installed? Which theme would you pay for? What caused confusion?

## S7 — Deeper metrics and later backlog

For additional providers or deeper token/model/session metrics, first run a bounded source/terms/auth spike. Record what can be accessed legitimately, which plans work and how updates survive provider changes. If valid, extend capabilities and repeat connection/reset/privacy tests. If not, defer the optional feature; do not scrape a web login. This deferral rule does not remove the required free Codex and Claude meters.

Later priorities, in order of evidence: additional theme packs; observed token/model/session views; desktop widget; additional providers beyond Codex and Claude; richer local trends. Cloud/team subscriptions, mobile/watch and sync require a separate product brief, threat model and commercial decision.

## Working protocol for every slice

1. Read current repo instructions and the relevant specification section. Inspect the worktree; preserve unrelated changes.
2. State the slice and a short implementation/test plan. Complete only that slice unless explicitly asked to continue.
3. Implement a smallest working vertical increment; maintain dependency boundaries and deterministic fixtures.
4. Run relevant tests. Record commands, outcomes and unavailable checks. Never say tests passed if they were not run.
5. Update docs/ROADMAP.md status and docs/BUILD-LOG.md with date, changes, test evidence, decisions, blockers and next slice.
6. Stop for meaningful scope changes, unverified integrations, billing decisions or release authorization. Do not publish, push, buy, or change provider account state without permission.

Definition of done: acceptance criteria met with evidence, no fabricated data in live paths, errors/accessibility checked, documentation updated and owner-facing handoff provided. Use NOT STARTED / IN PROGRESS / BLOCKED / DONE; no percentage-complete guesses.
