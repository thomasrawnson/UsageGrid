# UsageGrid Pro Licensing

## Agreed commercial direction

UsageGrid is planned for direct distribution as a Developer ID signed and notarised Mac app. UsageGrid Pro is planned as a one-off purchase through Lemon Squeezy, using hosted checkout and licence-key activation. The initial design does not require a separate UsageGrid account.

The 30 September 2026 [Notion Launch Readiness Pack](https://app.notion.com/p/3ebda2049a6481a0957acfac8b718394) records £9.99 GBP one-time, up to three Macs per licence, and no expiry for the purchased major version; future paid major upgrades may be separate. These remain the commercial requirements found in the source review of 10 October 2026. Seven days of offline validation grace is a recommended default, not an approved duration. Production policy details and configuration gates are tracked in [PRO_LICENSING.md](PRO_LICENSING.md) and [UG_P03_READINESS.md](UG_P03_READINESS.md).

### Policy status and authority

| Policy | Status | Requirement / remaining decision |
| --- | --- | --- |
| Price and currency | Confirmed commercial requirement | £9.99 GBP, one-time; no subscription at launch. |
| Devices | Confirmed commercial requirement | Up to three active Macs per licence; configure and prove the provider limit before customer-facing availability. |
| Entitlement | Confirmed commercial requirement | No expiry for the purchased major version. Future paid major upgrades may be separate; do not promise lifetime updates or all future products. |
| Distribution and licensing | Confirmed direction | Direct Developer ID signed, Apple-notarised download; Lemon Squeezy hosted checkout/licensing; no separate Pluto account or custom backend. |
| Offline grace | Recommended default | Seven days since the last successful validation. Duration still requires explicit owner approval before production implementation/claims. |
| Validation schedule and cache | Unresolved technical policy | Approve schedule/backoff, secure cache format, version/identity/instance binding, clock handling and grace expiry/recovery semantics. |
| Upgrade and support details | Unresolved commercial details | Major-version mapping/enforcement, any major-upgrade discounts, support/refund terms and advertised tax/currency presentation. None reopen the confirmed £9.99 GBP requirement. |
| Production configuration | Unverified prerequisite | Actual store/product/variant IDs, hosted checkout and provider settings must be evidenced; test IDs are not production approval. |
| Apple access | Unverified external prerequisite | UG-APPLE-01 was Blocked at its 1 October review. Current organisation membership, Team and Developer ID identity have not been independently verified. |

The launch pack is natively **unverified** in Notion; its explicit “Locked launch decisions” establishes the commercial intent, not proof of implementation or release approval. The Notion product roadmap (30 September) corroborates three-Mac licensing. The 25 September bundle document's £12.99 standalone figure is explicitly an illustrative, unagreed hypothesis and is superseded for launch by the £9.99 decision. Review covered the launch pack, product roadmap, project record (3 October), Apple task (1 October), bundle strategy, accessible later decision context, repository main and pull requests. No newer superseding commercial decision or explicit seven-day approval was found in those sources; absence in search is not proof none exists. Repository main remains `1efb4d2b85ad77cb733f349693358d77d87d55ec`, UG-P02.

This reconciliation changes documentation only. It does not authorize live product setup, purchases, credentials, signing or distribution.

Existing Free capabilities remain Free: live supported-provider usage, menu-bar display, Programming and Professional themes, the primary threshold alert, setup guidance, and support diagnostics.

## Planned customer lifecycle

1. The customer opens a Lemon Squeezy hosted checkout from a signed UsageGrid build.
2. Lemon Squeezy completes the one-off purchase and supplies a licence key.
3. The customer enters the key in UsageGrid.
4. UsageGrid asks the licensing service to activate it and validates that the response belongs to the configured UsageGrid store and Pro product.
5. Only a verified response grants the shared Pro entitlement.
6. The licence key and activation identifier are stored in the macOS Keychain for later validation and deactivation.

Possessing a key-shaped string, a stored credential, or a user-editable preference is never sufficient. A stored credential alone never grants production access. Initial access requires authoritative validation; any future offline access must derive from a previously validated, securely stored and bounded entitlement under the approved UG-P03 policy. Merchant API secrets must not be embedded in the app; public product/store identifiers and the provider’s client-safe licence endpoints are the intended boundary.

## Local credential boundary

The Keychain item uses stable app-specific identifiers:

- Service: `com.plutonightlabs.UsageGrid.license`
- Account: `lemonsqueezy.pro-license`

Only the licence key and activation identifier are represented by the P01 credential model. Licence keys, purchase details, activation identifiers, raw licensing responses, and arbitrary licensing errors must not appear in application logs or Support diagnostics. Tests use injected in-memory storage and do not touch the real Keychain.

UG-P02 uses a separate Debug-only test namespace: service `com.plutonightlabs.UsageGrid.license.test`, account `lemonsqueezy.test-pro-license`. Automated tests inject memory storage and never touch either real Keychain namespace.

## Validation and offline policy

Every activation and validation result must match the configured UsageGrid store, product, and variant before it can grant access. UG-P02’s confirmed test-only identity is Store `485681`, Product `1395768`, Variant `2179685`. It is compiled out of Release and is not production configuration.

UG-P02 grants test access only after a successful online activation or validation in the current process. On restart, a stored key and instance ID are validated once; launch never creates a new activation. Offline or ambiguous validation failures do not grant access and are not automatically retried. The production cache is not implemented; seven days is the recommended grace duration pending explicit approval for UG-P03. Debug failure behaviour must not be mistaken for the intended production outage policy.

## Deactivation, transfers, refunds, and revocation

Planned deactivation sends the stored activation identifier to the licensing service and removes the local Keychain credential only after the lifecycle outcome is handled. Device transfer will use deactivation followed by activation on another Mac, subject to the confirmed three-active-Mac limit.

Refunded or revoked licences must stop granting Pro after authoritative validation. Losing entitlement must fall back to Free presentation without deleting recorded history, theme choices, alert preferences, or other user settings. Data review and deletion remain available. Failure to validate must be presented separately from a confirmed revocation; retry cadence, cache semantics and grace duration approval remain UG-P03 work. A confirmed revocation must invalidate any cached grant and must not be masked by offline grace.

## P01 implementation boundary

P01 adds:

- A small activation, validation, and deactivation service interface.
- Unavailable, inactive, activating, verified-active, and safe failure states.
- A credential-storage interface and macOS Keychain implementation.
- An isolated activation preview with secure licence entry, progress, safe feedback, duplicate-submit prevention, cancellation, and obsolete-completion protection.
- Injected tests for lifecycle and storage behavior.

Production purchasing and activation remain unavailable. The preview’s activation control is disabled in the production foundation, no checkout URL or network implementation exists, and the existing shared Pro-access controller remains unentitled. Debug Pro simulation remains a separate internal-only feature and is not connected to licensing.

## P02 Debug test integration

Debug Settings contains a clearly labelled internal test section with secure key entry, activation, explicit validation, deactivation, progress, cancellation, and safe errors. It calls the official client-safe `POST /v1/licenses/activate`, `/validate`, and `/deactivate` endpoints using form fields documented by Lemon Squeezy; it embeds no merchant API secret and has no checkout link. Successful responses must match all three test identity values before feeding the shared `ProAccessController`.

Official API references used for this implementation: [Activate a license key](https://docs.lemonsqueezy.com/api/license-api/activate-license-key), [Validate a license key](https://docs.lemonsqueezy.com/api/license-api/validate-license-key), and [Deactivate a license key](https://docs.lemonsqueezy.com/api/license-api/deactivate-license-key).

Debug simulation and verified test licensing remain independent and their active source is shown in Settings. Test access loss immediately restores existing Free boundaries without clearing themes, alerts, history, or preferences. Remote activation followed by Keychain failure exposes an explicit **Retry secure storage** action and does not repeat activation. A failed deactivation retains credentials for retry. Release contains neither this service, its identifiers, nor its controls and remains unentitled.

## Delivery stages

- **UG-P01 — Licensing model, storage boundary, and isolated activation UI:** interfaces, state model, Keychain boundary, disabled production preview, documentation, and injected tests.
- **UG-P02 — Lemon Squeezy test-mode integration and lifecycle verification:** implemented Debug-only client-safe activation/validation/deactivation, exact test identity, online restart validation, failure/recovery tests and shared test entitlement. No in-app checkout or production offline grace was implemented; real-key/manual verification remains separate evidence.
- **UG-P03 — Live configuration and signed-artifact purchase testing:** carry forward the confirmed commercial terms, approve remaining offline/upgrade/support details, evidence production configuration and Apple prerequisites, then implement and validate the lifecycle on a Developer ID signed and notarised artifact. See [UG_P03_READINESS.md](UG_P03_READINESS.md) for gates and acceptance tests. Production remains unavailable until those gates and separate release approval.

No live product, payment, checkout, signing, or publishing work is part of P02. £9.99 GBP, three Macs and purchased-major-version entitlement are confirmed requirements; production offline behaviour has a seven-day recommendation with approval and implementation still outstanding.
