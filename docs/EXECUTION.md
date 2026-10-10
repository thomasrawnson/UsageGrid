# UsageGrid — lead review and Codex task queue

21 September 2026 · Planning review, not an implementation audit

## Start here

Place this file at `docs/EXECUTION.md` in the UsageGrid repository. Keep the existing product specification at `docs/PRODUCT-SPEC.md`, roadmap at `docs/ROADMAP.md`, and screenshots in `docs/design-references/`.

This document replaces the broad S0–S6 execution prompts in the previous handoff. It refines their implementation order; the product specification remains authoritative for product behavior. In particular, mock UI work may proceed after the platform check while real-provider feasibility remains blocked. Both real providers remain a beta/release gate. No original planning files were edited by this review.

All tasks below are initially NOT STARTED. Neither provider has been verified by this review, and no application code or Mac build has been inspected. The review covers the three existing UsageGrid planning documents and the requested article; it does not constitute a new visual inspection of the source screenshots.

## Lead assessment

The product is appropriately small if we keep the architecture proportional to it. The strongest existing decisions are two free providers, explicit unknown/stale states, consistent used-percentage semantics, one themeable UI and local data. Preserve them.

| Finding | Decision |
| --- | --- |
| S0 combines environment, two integrations and distribution research | Separate them into three evidence tasks and a short architecture decision. |
| S1 combines domain, lifecycle, rendering, themes and preferences | Build and inspect these as separate increments. |
| Proposed modules could become many packages/services | Start with one app target and one unit-test target; folders are sufficient boundaries. Extract a package only for a demonstrated need. |
| A broad adapter interface anticipates optional analytics | Start with quota snapshots and connection state. Add optional capabilities when a verified source and consuming feature exist. |
| SQLite and entitlement infrastructure are described before their features | Add history storage and purchase verification at their own tasks. Early demo entitlement is debug-only. |
| Mandatory full-document reading and a growing build log inflate context | Use this task queue for status; read only task-relevant sections. Keep decisions beside the evidence that justifies them. |
| Eight themes can multiply implementation and QA | One shared layout, semantic tokens and static decorations; deliver themes in pairs. |
| Launch depends on Claude access that is still unverified | Treat this as the principal feasibility risk. Never substitute token totals for quota or hide it with demo data. |
| Forecasts can appear more precise than their source | Keep them late, deterministic and suppressible; require actual beta evidence before selling them. |
| “Lifetime” can overpromise maintenance | Preserve permanent purchased-feature rights and define support/update terms before sales. |

The beta scope stays: both real free meters, resets and connection states, compact/expanded Mac UI and eight themes available for testing. Paid 1.0 adds verified entitlements, history/export, defensible forecasts and opt-in alerts. No subscription backend, companion system, ContextTrim integration, shared SDK, plugin architecture or project-cost attribution belongs in this build.

## Applying the article

OpenAI's [Rethinking skills and prompts for GPT-6 Astra](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra) recommends narrowly triggered skills, selective document loading, revisiting always-loaded instructions, and explicit completion boundaries. It also cautions against procedural guidance that causes unnecessary work.

For UsageGrid, that means a short repository guide, task-specific context and one completed increment per request. No mandatory skills bundle, repeated repo-wide audit or full-suite run for every cosmetic change. The task's acceptance criteria define completion; Codex should fix failures within that scope before returning. These are project execution choices, not claims that the article prescribes this architecture.

## Architecture to implement

Use the specification's proposed Swift/SwiftUI macOS 14+ baseline, confirmed by T01. Start with one native application; use AppKit only where native menu/window behavior requires it. Do not add a web runtime.

The data path is provider-specific transport → validated quota snapshot → application state → shared views. Persistence subscribes to valid observations when history is implemented. Forecasts consume history; alerts consume fresh observations. Views never parse provider payloads.

Use simple folders as needed: App, Usage, Providers, Views, Themes, History, Purchases. Do not create empty folders or protocols for later features. One small provider boundary is justified by two real providers and a deterministic demo; a generic service container/event bus is not.

The initial quota snapshot needs provider, opaque account partition, bucket/window identity, optional duration/reset time, raw used percentage, observation time and provenance. Keep connection status separate from the last valid snapshot. Unknown or invalid usage must not become zero. Missing optional fields remain absent. If account identity is unavailable, start a new local connection partition rather than merging accounts speculatively.

Only verified provider mappings determine window labels and identity. A reset timestamp change or percentage decrease invalidates the forecast segment. Do not assume these alone reliably identify every provider reset cycle: record the verified provider semantics before implementing alert deduplication.

Keep one refresh owner per provider, with coalescing, cancellation and isolated errors. Use the specification's refresh/freshness defaults, subject to verified provider throttling. Store harmless preferences in UserDefaults. Add SQLite at T20; do not persist credentials or full provider payloads.

## Ownership and review

Tom owns product priorities, price, commercial commitments and publication. The lead owns architecture, integration acceptance, scope and review decisions. Codex implements the selected task, resolves routine coding choices and returns evidence.

For each task, return: task ID; concise changes; checks actually run and result; unavailable checks/blockers; commit ID if one exists, otherwise changed-file list. Provide screenshots for visible changes and sanitized source comparisons for integrations. Never include credentials. A polished summary alone is not proof of completion.

Review outcomes: ACCEPTED, CHANGES REQUIRED, or BLOCKED. Review checks task acceptance, data correctness and whether added complexity was necessary. Small findings become a bounded repair task. Do not reopen unrelated architecture on every review.

Stop at the selected task after completing and validating it, because that is the requested unit of work. Do not pause between routine edits or local checks. External sales/publication decisions remain separate. When a missing Mac/account blocks a check, complete the useful offline work and state the exact remaining check; do not report the task as verified.

## Task index

Each row is one reviewable change, usually a focused coding session; these are not time guarantees. If a task reveals a separate unknown, record it and split that work before broadening scope. All dependencies refer to accepted results, except explicitly permitted demo work.

| Task | Deliverable | Depends on | Original slice |
| --- | --- | --- | --- |
| T01 | Repository and Mac toolchain baseline | — | S0 |
| T02 | Codex quota proof | T01 | S0 |
| T03 | Claude quota proof | T01 | S0 |
| T04 | Integration/distribution decision | T02, T03 evidence, including blockers | S0 |
| T05 | Native menu-bar shell | T01 | S1 |
| T06 | Quota model and matrix semantics | T05 | S1 |
| T07 | Compact demo meter | T06 | S1 |
| T08 | Single expanded window | T07 | S1 |
| T09 | Two free themes and preferences | T08 | S1/S3 |
| T10 | Codex transport | T02 pass, T04, T06 | S2A |
| T11 | Codex mapping and live meter | T10, T07 | S2A |
| T12 | Claude transport | T03 pass, T04, T06 | S2B |
| T13 | Claude mapping and live meter | T12, T07 | S2B |
| T14 | Refresh, freshness and reset lifecycle | T11, T13 | S2 |
| T15 | Connection onboarding and isolation | T14 | S2 |
| T16 | Theme gallery and preview | T09 | S3 |
| T17 | Retro and Anime | T16 | S3 |
| T18 | Zen Forest and Space | T16 | S3 |
| T19 | Christmas, Halloween and theme QA | T17, T18 | S3 |
| T20 | Local observation storage | T15, T16 | S4 |
| T21 | History, export and delete | T20, T08 | S4 |
| T22 | Pure forecast estimator | T20 | S4 |
| T23 | Forecast presentation | T22, T08 | S4 |
| T24 | Threshold detection and receipts | T20 | S4 |
| T25 | Opt-in notification delivery | T24 | S4 |
| T26 | Commercial implementation decision | T04 | S5 |
| T27 | Verified entitlement adapter | T26, T16 | S5 |
| T28 | Purchase, recovery and feature gates | T27, T19, T21, T23, T25 | S5 |
| T29 | Beta reliability and performance | T15, T19; repeat affected checks after T28 | S6 |
| T30 | Signed release candidate | T28, T29 | S6 |

### T01 — Establish the actual starting point

Inspect the existing repository, applicable instructions, worktree and Mac/Swift/Xcode availability. Record only actual build commands, versions and current structure in a short README section. If empty, establish the minimum native app/test target setup; no dependency bundle or generated service layers.

Done: reproducible baseline build on Mac, or an explicit unavailable-toolchain result with precise Mac follow-up. Preserve existing code and unrelated changes. Do not claim Linux static inspection proves a Mac build. Context: specification §1; existing repo instructions.

### T02 — Prove Codex quota access

Use current official documentation and the installed version to make an authorized read-only quota request. Record initialization, supported auth path, version, actual bucket/window semantics, reset metadata and data coverage in `docs/INTEGRATION-FEASIBILITY.md`, Codex section. Save a minimal sanitized real response. Clearly separate synthetic error fixtures from real observations.

Done: quota compared with the matching provider/account/window at comparable timestamps; commands and limitations recorded. No coding turn, credential extraction or quota-changing action. If target access is absent, mark BLOCKED and give the exact local proof still needed. Do not build the UI here. Context: specification §3.

### T03 — Prove Claude quota access

Independently investigate current official Anthropic documentation and validate a permitted source on the target account. Record source, auth, supported versions/plans, observation timing, account identity and reset semantics in the Claude section of the same evidence file. Do not assume that a local token log measures subscription quota.

Done: real quota/reset evidence and sanitized fixture, or a concrete blocker with possible next investigation. No cookie/credential scraping or invented private API. UsageGrid Free support remains required; it does not imply that Anthropic itself offers free service access. Context: specification §3.

### T04 — Resolve the minimal integration architecture

Use T02/T03 evidence to document the chosen transport per provider and assess direct distribution versus Mac App Store constraints. Recommend one route with evidence about required process/file/network access. Do not install billing dependencies yet. Keep the decision in the feasibility file.

Done: each provider has a supported/blocked status, source coverage, auth ownership and minimum tested version; packaging constraints are explicit. If either proof is blocked, adapters depending on it and the two-provider release stay blocked. T05–T09 and theme work may still proceed in demo mode. Context: feasibility evidence; specification §§3,7,8.

### T05 — Build only the native shell

Create a menu-bar item, transient panel with placeholder content, accessible Quit and standard lifecycle behavior. Use native APIs; do not add providers, a database or billing.

Done: launch, toggle, Escape/outside-close and Quit work on the target Mac without duplicate status items. Provide one panel screenshot and a short manual check result. Context: specification §4, menu-bar/compact behavior.

### T06 — Define quota values and presentation math

Add the minimal normalized snapshot/status types and a pure percentage-to-cell presentation function. Preserve raw precision. Match the specification's whole-percent rounding and reject non-finite/out-of-range input before treating it as valid. Drawing must remain bounded.

Done: focused tests for 0,1,62,99,100, fractional ties, missing/invalid values and stable account/window keys. Exactly 62 cells for 62% used. No transport or persistence. Context: specification §5 and domain fields in §7.

### T07 — Render the compact demo meter

Wire deterministic demo snapshots to the shared 100-cell matrix, provider/window selection, used/left labels, reset and freshness display. Show both demo providers, including a missing-window case. Keep demo provenance visible.

Done: 20×5 cells; unavailable data is not a zero reading; provider/window labels match selected data; reset expiry shows refreshing rather than clearing usage. Verify at 62%, unavailable and exhausted. No live requests or alerts. Context: specification §§4–5.

### T08 — Add the reusable expanded window

Open/focus a single expanded window from the panel. Share application state and matrix components. Include the theme-control location and space for later features without fake charts, sessions or statistics.

Done: repeated Expand reuses the window; close leaves the menu app running; selection stays synchronized; small-window scrolling works. Provide compact/expanded screenshots. Context: specification §4 expanded view.

### T09 — Add the two free themes

Implement Programming and Professional through a small token definition and the existing components. Persist selected provider/window, theme and icon/text preference. Invalid saved selections fall back safely. Use system fonts initially where licensed assets are unavailable.

Done: switching theme does not change usage; preference restoration works; menu icon remains readable in macOS light/dark appearance. VoiceOver reads one matrix summary. No separate screens per theme. Context: specification §6 and relevant two reference images.

### T10 — Implement the proven Codex transport

Implement only the protocol demonstrated in T02, including initialization, message framing/IDs, bounded timeouts, cancellation and safe diagnostics. Resolve the executable without shell interpolation. Own and clean up only UsageGrid-created processes.

Done: fixture-driven framing/error tests cover fragmented messages, unknown fields, disconnect and timeout as applicable to the verified protocol; one real read succeeds. No generic multi-provider transport abstraction unless both verified protocols actually require it. Context: Codex evidence; specification §7 transport.

### T11 — Connect the Codex meter

Map real Codex payloads into normalized state and render them in Free. Preserve distinct buckets/windows, absent fields, provider errors and provenance. Implement only manual refresh initially; T14 owns scheduling.

Done: live screen matches corresponding source reading; missing windows remain absent; multi-bucket fixture does not combine percentages; login and malformed-data failures do not become demo data. Context: Codex evidence; specification §§3–5.

### T12 — Implement the proven Claude transport

Build the independently verified T03 access mechanism with bounded reads, cancellation and safe errors. Reuse small utilities only when justified by the real mechanism.

Done: one authorized real quota read plus focused transport failure tests. No Codex protocol assumptions or token-to-quota inference. If the source fails, report the integration blocker rather than changing the product promise. Context: Claude evidence; specification §3.

### T13 — Connect the Claude meter

Map Claude quota into the same UI/domain and keep it available in Free with Codex disconnected. Preserve source-specific windows/reset metadata and separate account partitions.

Done: real source comparison and mapping tests; one provider's failure cannot blank the other; switching preserves correct selections and scopes. No payment checks on provider access. Context: Claude evidence; specification §§3–5.

### T14 — Make refresh and time behavior reliable

Add one refresh coordinator per provider. Follow verified source limits and specification defaults for polling, coalescing, stale age, backoff and wake. Keep the last valid value visibly stale on failure. Expired resets trigger a refresh, not fabricated zero usage.

Done: deterministic clock tests for simultaneous requests, backoff, stale transition, reset expiry and wake. Old in-flight responses cannot overwrite a newer connection/account. Provider failures remain isolated. No real sleeps in unit tests. Context: specification §5 countdown and §7 polling.

### T15 — Complete connection onboarding

Add connect/reconnect guidance and independent missing-install, signed-out, unsupported and unavailable states based on proven capabilities. Keep Try demo explicit and separate from live state. Add safe current-cache handling if needed; cached startup values are stale until refreshed.

Done: Codex-only, Claude-only and both-provider Free flows work; sign-out/account switch cannot show another account's cached quota; refresh errors have actionable recovery. Validate on a Mac. This is the Free MVP review gate. Context: specification §4 first run and §7 partitioning.

### T16 — Build one theme gallery

Add eight theme entries, free application and explicitly labelled Pro sample preview. Use one central debug entitlement seam; no purchase SDK. Preview does not overwrite the user's applied theme or show sample data as live.

Done: preview/close returns to prior state; free themes always apply; debug Pro permits testing paid themes. Release configuration cannot use the debug override. Context: specification §§2,6.

### T17 — Add Retro and Anime

Implement these two token/decorative sets using shared components and relevant reference images. Keep body text readable and use original/licensed visual assets.

Done: compact and expanded 62% screenshots, legible warning/error states, keyboard focus and reduced effects. No new behavior or independent layout hierarchy. Context: specification §6; these two images only.

### T18 — Add Zen Forest and Space

Implement the two themes through existing tokens, with static forest/lake or star decoration where appropriate. Avoid continuous particle rendering.

Done: compact/expanded screenshots, readable inactive cells and text, reduced-effects behavior and identical matrix meaning. Context: specification §6; these two images only.

### T19 — Add seasonal themes and complete visual QA

Implement Christmas and Halloween. Check all eight themes against specification §6 and the existing UI acceptance matrix. Reuse deterministic states; inspect representative combinations first and expand checks where a defect suggests risk.

Done: all themes have reviewed compact/expanded output; normal, empty, exhausted, stale/error, enlarged text, focus and contrast cases covered. No unlicensed assets. With T15 accepted, this opens private beta; forecasts and purchases are not beta prerequisites.

### T20 — Store local observations

Introduce versioned SQLite storage with serialized writes for valid quota observations and reset/account partition keys. Enable history only under the central Pro/debug entitlement. Free keeps its minimal current-state cache, not hidden full history.

Done: restart persistence, account/window isolation, duplicate handling, migration and retention tests. Start history at enablement; never backfill invented samples. No raw payload, prompt or secret storage. Context: specification §7.

### T21 — Show history and control its data

Add a simple local usage history/activity view, CSV export and confirmed delete, using T20. Apply 7/30/90-day retention options. Label observations as observations, not coding sessions.

Done: UTC export fields and escaping validated; retention/delete work; previously collected data remains exportable/deletable after entitlement loss. Empty history explains when collection starts. No advanced analytics dashboard. Context: specification §§4,7.

### T22 — Implement the pure quota forecast

Implement specification §5's estimator as a pure function over scoped samples and a supplied clock. No new fitting library. Cover sample count/span, gaps, freshness, minimum change, reset/account changes, decreases and reset-before-limit behavior.

Done: the 50→56% example gives 12 percentage points/hour and 3h40m remaining at 56%, subject to reset timing. Insufficient/flat/stale samples return explanatory non-numeric states. Exact algorithm stays in the specification, not duplicated here.

### T23 — Display forecasts honestly

Bind T22 results to Pro estimate cards. Keep reset fact separate; use “Estimate at recent pace.” Suppress unsupported predictions and clearly distinguish percentage points/hour from tokens.

Done: screenshot for learning, estimate, reset-first and stale states; no forecast from demo presented as live; feature availability follows entitlement. Collect forecast usefulness feedback in beta before paid release. Context: specification §5.

### T24 — Detect threshold crossings

Implement a pure crossing detector and persisted dedupe receipts using the verified provider reset identity. Baseline first readings, combine multi-threshold jumps and isolate account/window state. No OS notification code yet.

Done: tests for restart dedupe, reset cycle, first sample, stale/demo data, entitlement transition and multi-threshold jumps. If a source lacks a trustworthy cycle identifier, document a conservative behavior and block unsupported reset-aware claims rather than guessing. Context: specification §5 alerts; provider evidence.

### T25 — Deliver opt-in notifications

Connect T24 to native notifications with threshold settings and permission requested only when enabling alerts. Use the central entitlement state; disabling alerts/Pro stops future delivery without deleting history.

Done: allow/deny/off scenarios tested on Mac, no first-run permission interruption, no duplicate delivery after restart and no promise of delivery while asleep. Context: specification §5 alerts.

### T26 — Choose the commercial route

Record the selected distribution/payment direction, unresolved commercial policies, supported offline verification, recovery/refund handling and update/support terms. Verify current vendor capabilities before integration. Show the exact proposed live configuration to Tom before account setup or sales.

Current decision: direct signed/notarised distribution with a one-off UsageGrid Pro purchase through Lemon Squeezy hosted checkout and licence-key activation, without a separate UsageGrid account initially. The 30 September launch pack confirms £9.99 GBP one-time, up to three Macs and no expiry for the purchased major version (future paid major upgrades may be separate). Seven-day offline grace remains a recommendation pending explicit approval. Resolve production cache/cadence, upgrade/support details, live identity and Apple prerequisites through `docs/UG_P03_READINESS.md`; do not reopen confirmed terms merely because older implementation text omitted them. Do not build multiple payment adapters or a bespoke account server. Context: specification §§2,8; `docs/PRO_LICENSING.md`.

### T27 — Verify entitlements

Implement the selected vendor's sandbox verification and persistence behind the existing central boundary. Keep verified rights separate from transient verification failure. Implement the approved offline policy.

Done: verified purchase, invalid evidence, cancellation, offline verified purchase, verification outage and revocation cases tested. Secrets remain outside ordinary preferences. Do not trust a saved Pro boolean. Context: T26 decision; specification §2.

### T28 — Complete purchase and feature gating

Wire upgrade and recovery/restore UI to T27. Apply central gates to paid themes, history collection, forecast and alerts. Keep both provider meters and expanded view free. Preserve user access to export/delete existing history.

Done: sandbox purchase/recovery on Mac; entitlement loss falls back to a free theme; failed/cancelled purchases leave rights intact; release build excludes debug unlock. Copy describes shipped features only. No live charges or publication. Context: specification §2.

### T29 — Validate the beta build

Measure actual install/onboarding, sleep/wake, reconnect, account change and extended-workday behavior for both providers. Profile hidden idle CPU, app and child-process memory, and panel-opening time against the specification's proposed budgets. Prepare beta instructions and questions; do not contact testers without authorization.

Done: evidence from target Mac(s), supported configurations and a prioritized defect list. Fix task-local failures; split unrelated defects into bounded repair tasks. Block release on unresolved quota accuracy, credential, data-loss or purchase defects. Repeat only checks affected by later changes. Context: specification §8 and roadmap S6.

### T30 — Produce the release candidate

With approved signing/distribution configuration, prepare a signed/notarized candidate, clean-profile installation/recovery evidence, release notes, privacy/support copy and update/rollback instructions. Request necessary unavailable signing access only after preparing everything possible.

Done: exact artifact/version and remaining limitations are reviewable; all release gates recorded. Publication and charging await Tom's approval of that concrete candidate. No unsupported provider or future lifetime-service promises. Context: specification §8; T26; T29 evidence.

## Review gates

| Gate | Required evidence | Work it unlocks |
| --- | --- | --- |
| Source proof | T02/T03 separately accepted | Each corresponding real adapter |
| Demo design | T05–T09 screenshots and Mac behavior | Theme implementation confidence |
| Free MVP | T15, both real source comparisons | Two-provider reliability review |
| Private beta | T15 + T19 | Consent-based beta testing |
| Commercial decision | T26 | Selected payment integration |
| Paid release | T20–T30 acceptance, useful forecasts or explicit owner-approved scope revision | Candidate approval, then authorized publication |

## Suggested small AGENTS.md content

Merge only missing project-specific facts into existing instructions; do not overwrite a repository's guide. This is a suggested guide, not a new skill.

```markdown
# UsageGrid
Native macOS menu-bar utility. Codex and Claude core meters are Free.
Filled matrix cells mean USED quota. Unknown data is never zero.
Demo data must remain visibly labelled and cannot trigger alerts.
Provider auth stays provider-owned; never collect prompts or credentials.

Use docs/EXECUTION.md for the assigned task and dependencies.
Use relevant PRODUCT-SPEC sections for behavior, INTEGRATION-FEASIBILITY
for provider changes, and design references only for visual work.
Keep one shared themed UI and provider-specific payload mapping.
Complete the assigned task and resolve failures within its scope.
Report evidence and unavailable checks; do not label fixtures as live proof.
```

Add actual build/test commands once T01 establishes them. Do not add long model-persona prompts, routine coding advice or a requirement to load all docs. A task row/status note is sufficient progress tracking; do not maintain a duplicate narrative BUILD-LOG for each edit.

## Copy-paste prompts

First task, after placing the documents in the repository:

```text
Implement T01 from docs/EXECUTION.md for UsageGrid. Follow the repository's
applicable instructions and preserve unrelated work. Establish the actual
repository and Mac build baseline; complete only T01. Record commands and
results, including unavailable checks, and return a concise review handoff.
Do not build provider integrations or the full application yet.
```

Later task:

```text
Implement T07 from docs/EXECUTION.md. Read its relevant specification sections
and existing code as needed. Complete and validate the task, fixing failures
within scope. Return changed files, checks/results and any blocker. Stop after
the task is complete; do not expand into the next task.
```

Replace T07 with the selected dependency-ready task. Do not paste this whole document into every Codex chat. Ask the lead to review the diff and evidence at each meaningful increment; a task is accepted based on those results, not on elapsed time or a completion claim.
