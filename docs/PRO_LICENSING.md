# UsageGrid Pro Licensing

## Agreed commercial direction

UsageGrid is distributed outside the Mac App Store as a Developer ID signed and notarised Mac app. UsageGrid Pro costs **£9.99 GBP** as a one-time purchase through Lemon Squeezy, using hosted checkout and licence-key activation. It is not a subscription, and the initial design does not require a separate UsageGrid account.

One licence may have no more than **three activated Macs** at a time. A purchase covers the UsageGrid major version sold by its configured Lemon Squeezy product and variant. It does not promise entitlement to every future major version; a future major version may require a new purchase. A successfully verified production entitlement may be used offline for no more than **seven days** under the rules below.

Existing Free capabilities remain Free: live supported-provider usage, menu-bar display, Programming and Professional themes, the primary threshold alert, setup guidance, and support diagnostics.

## Production customer lifecycle

1. The customer opens a Lemon Squeezy hosted checkout from a signed UsageGrid build.
2. Lemon Squeezy completes the one-off purchase and supplies a licence key.
3. The customer enters the key in UsageGrid.
4. UsageGrid asks Lemon Squeezy to activate this Mac. Lemon Squeezy enforces the maximum of three active instances.
5. UsageGrid verifies that the response belongs to the configured live store, product and variant, and that the product is eligible for the running app's major version.
6. Only a successful authoritative verification grants the shared Pro entitlement.
7. The licence key, activation identifier and minimum verified-entitlement evidence required for offline validation are stored securely for later validation and deactivation.
8. While online, UsageGrid periodically revalidates the stored activation. A confirmed refund, disabled or revoked key, expired licence, instance mismatch or ineligible major version removes Pro access.

Possessing a key-shaped string, a stored credential, or a user-editable preference is never sufficient. A stored credential must be validated before production access is granted. Merchant API secrets must not be embedded in the app; public product/store identifiers and the provider’s client-safe licence endpoints are the intended boundary.

## Local credential boundary

The Keychain item uses stable app-specific identifiers:

- Service: `com.plutonightlabs.UsageGrid.license`
- Account: `lemonsqueezy.pro-license`

Only the licence key and activation identifier are represented by the P01 credential model. The production offline cache will additionally require authenticated or integrity-checked entitlement evidence and validation timestamps; its exact schema and storage split remain an implementation decision for UG-P03C. Licence keys, purchase details, activation identifiers, raw licensing responses, customer details, and arbitrary licensing errors must not appear in application logs or Support diagnostics. Tests use injected in-memory storage and do not touch the real Keychain.

UG-P02 uses a separate Debug-only test namespace: service `com.plutonightlabs.UsageGrid.license.test`, account `lemonsqueezy.test-pro-license`. Automated tests inject memory storage and never touch either real Keychain namespace.

## Identity, major-version eligibility, and offline policy

Every activation and validation result must match the configured UsageGrid store, product, and variant before it can grant access. Production product or variant identity must map immutably to the major versions it licenses; it must not be selected through UserDefaults, environment variables, command-line arguments, remote copy, or other user-editable state. A licence for major version 1 grants Pro in compatible `1.x` releases but does not by itself grant Pro in `2.x`. Minor and patch updates within the purchased major version remain covered. The exact live IDs and the representation of the immutable major-version mapping remain unresolved until the live Lemon Squeezy product is configured.

UG-P02’s confirmed test-only identity is Store `485681`, Product `1395768`, Variant `2179685`. It is compiled out of Release and is not production configuration.

UG-P02 grants test access only after a successful online activation or validation in the current process. On restart, a stored key and instance ID are validated once; launch never creates a new activation. Offline or ambiguous test validation failures do not grant access and are not automatically retried. This online-only test policy remains unchanged.

Production uses these offline rules:

- The seven-day grace period begins at the recorded time of the most recent successful authoritative production activation or validation for the same stored activation, live product identity, and eligible app major version.
- Merely entering or storing a key never starts or renews the grace period. A failed, cancelled, malformed, mismatched, or incomplete response never advances the last-success time.
- A launch should attempt online validation. A definite authoritative denial immediately removes Pro access and overrides any remaining grace period. A transient inability to reach or complete validation may use cached entitlement only while the cache is valid and no more than seven elapsed days old.
- Successful validation replaces the cached evidence and restarts the seven-day period. The implementation must define a bounded online revalidation cadence so a continuously running app does not rely indefinitely on launch-only checks.
- When seven days have elapsed without successful validation, UsageGrid falls back to Free until online validation succeeds. It retains the credential for retry and does not delete history, preferences, or other user data.
- Cache contents must be bound to the stored activation, live product identity, and eligible major version. Missing, undecodable, internally inconsistent, altered, or unsupported cache data is treated as no offline entitlement.
- If the current wall clock is earlier than the trusted last-success time, or moves backwards beyond an implementation-defined small tolerance, offline entitlement is denied until authoritative online validation succeeds. Clock rollback never extends the grace period.
- The exact monotonic-clock support, rollback tolerance, validation retry schedule, cache integrity mechanism, and user-visible countdown threshold remain unresolved implementation details for UG-P03C.

## Deactivation, recovery, transfers, refunds, and revocation

Deactivation sends the stored activation identifier to Lemon Squeezy. After confirmed deactivation, UsageGrid removes the local credential and cached entitlement and returns to Free. If deactivation cannot be confirmed, it retains the credential for retry but does not claim that the remote activation was released.

A normal device transfer is deactivation on the old Mac followed by activation on the new Mac. With fewer than three active Macs, a customer may activate the new Mac first and then deactivate the old one. At the three-Mac limit, an existing instance must be deactivated before another can activate. Reinstalling on the same Mac must validate or recover the existing activation without silently creating repeated instances; the exact stable instance naming and reinstall-matching strategy remain unresolved for UG-P03B.

If the old Mac is lost, erased, or unavailable, UsageGrid must provide clear recovery guidance rather than bypassing the activation limit. The operational route for owner/support-assisted instance removal in Lemon Squeezy, and whether customers receive any self-service instance management, remain unresolved for UG-P03D. Recovery must never require a merchant API secret in the app.

Refunded purchases must have their Lemon Squeezy licence disabled or otherwise made invalid through the approved operational process. A disabled, revoked, expired, refunded, mismatched, or invalid licence stops granting Pro immediately when authoritatively confirmed; the seven-day grace period does not override that response. Until the next successful contact, an already verified installation may continue only under the ordinary seven-day offline rules. The app must not claim real-time refund enforcement while it is offline.

Losing entitlement falls back to Free presentation without deleting recorded history, theme choices, alert preferences, or other user settings. Data review, export where implemented, and deletion remain available. The credential is retained for recoverable network/service failures and removed only after confirmed deactivation or an explicit, clearly described local removal action. Exact automated retry timing and whether confirmed permanent denial retains the credential for support/recovery remain unresolved for UG-P03C and UG-P03D.

## Failure handling and customer messages

Customer-facing copy must distinguish these outcomes without exposing raw provider errors:

| Condition | Entitlement result | Required message intent |
| --- | --- | --- |
| Empty or malformed entry | No change | Enter a valid licence key. |
| Purchase cancelled or payment failed | Existing rights unchanged | Purchase was not completed; no charge or entitlement should be implied. |
| Activation succeeded and secure storage failed | Do not repeat activation; no durable entitlement yet | Activation succeeded, but UsageGrid could not save it securely. Offer secure-storage retry. |
| Three-Mac limit reached | No new entitlement | The licence is already active on three Macs. Deactivate another Mac or follow recovery guidance. |
| Offline or Lemon Squeezy unavailable, valid grace remains | Cached Pro continues | Validation is temporarily unavailable and state when online validation will be required. |
| Offline or unavailable, grace expired | Free until verified | Connect to the internet to verify UsageGrid Pro. No purchase-loss claim. |
| Clock rollback or corrupted cache | Free until verified | Stored verification could not be trusted; connect to verify again. |
| Wrong product or major version | No entitlement in this build | This licence does not cover this UsageGrid major version. |
| Confirmed disabled, revoked, expired, or refunded licence | Free | The licence is no longer active; provide recovery or support guidance. |
| Deactivation failed | Access removed for the current operation; remote slot not claimed as released | Deactivation was not confirmed; retain credentials and offer retry. |

Exact final UI wording, support URL, accessibility announcements, and localization remain UG-P03D implementation details. Messages must never include licence keys, activation IDs, customer data, raw payloads, or secrets.

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
- **UG-P02 — Lemon Squeezy test-mode integration and lifecycle verification:** hosted test checkout, client-safe activation/validation/deactivation, configured test identity, restart/recovery/revocation/offline-policy tests, and connection to shared access only after verification.
- **UG-P03A — Production licensing policy:** approved commercial terms, lifecycle, offline, version, recovery, refund, failure, and delivery policy.
- **UG-P03B — Production service and identity:** production Lemon Squeezy service, immutable live identity and major-version eligibility, timeouts/status handling, and safe instance identity.
- **UG-P03C — Offline entitlement and reliability:** secure cache, seven-day grace, clock rollback/corruption handling, revalidation/retry policy, and deterministic tests.
- **UG-P03D — Production purchase and licence UI:** hosted checkout, activation, validation, recovery, deactivation, failure copy, and accessibility.
- **UG-P03E — Live Lemon Squeezy lifecycle verification:** live product configuration and controlled purchase, three-Mac, transfer, reinstall, refund, revocation, and recovery evidence.
- **UG-P03F — Signed release candidate:** Developer ID archive, notarisation, stapling, clean-Mac lifecycle checks, Release-binary inspection, and owner approval.

No live product, payment, checkout, signing, or publishing work is part of P02. UG-P03A changes policy documentation only and does not make production licensing available.

## UG-P03B through UG-P03F checklist

### UG-P03B — Production service and identity

- [x] Create a production-only service using the client-safe Lemon Squeezy licence endpoints with no merchant API secret.
- [ ] Compile immutable live store/product/variant identity and purchased-major eligibility into Release-safe configuration.
- [x] Keep test IDs, test Keychain namespace, Debug simulation, and test controls out of Release.
- [x] Add bounded timeouts, cancellation, response/status classification, instance matching, and secret-safe diagnostics.
- [x] Define stable, privacy-preserving instance naming and reinstall behavior.
- [x] Add focused tests without real keys or requests.

UG-P03B implements production service infrastructure but deliberately leaves `ProductionProLicenseConfiguration.current` absent until owner-approved live store, product, and variant IDs exist. An absent configuration or ineligible running major version fails before any network request. The service is not connected to the Release entitlement controller, checkout, or production UI.

The production activation name uses a random installation UUID stored in a device-only Keychain item and sends only a shortened opaque label such as `UsageGrid Mac abcdef123456`. It does not read a hardware serial number, account name, email address, hostname, or other personal identifier. Restart reuses the stored Lemon Squeezy activation ID and validates it instead of activating again. A normal reinstall should reuse the opaque installation identity and licence credential when macOS preserves those Keychain items. Erasing the Keychain, migrating to another Mac, or otherwise losing those items cannot be matched locally and may require deactivating the old Lemon Squeezy instance through the recovery process defined for UG-P03D/UG-P03E; the app must not silently create repeated activations at the three-Mac limit.

### UG-P03C — Offline entitlement and reliability

- [ ] Implement integrity-checked cached evidence bound to credential, activation, product identity, and major version.
- [ ] Enforce the seven-day last-success window, expiry boundary, rollback denial, corruption denial, and authoritative-revocation precedence.
- [ ] Define and test launch validation, running-app revalidation, bounded retry/backoff, sleep/wake, cancellation, and concurrent-operation behavior.
- [ ] Confirm Keychain accessibility and cache migration behavior in signed builds.
- [ ] Test time boundaries deterministically without changing the real system clock.

### UG-P03D — Production purchase and licence UI

- [ ] Add the exact hosted live checkout link and truthful £9.99 one-time, three-Mac, major-version copy.
- [ ] Implement activation, validation status, offline/grace state, deactivation, transfer, reinstall, and lost-device recovery guidance.
- [ ] Implement the safe failure-message matrix above, final support route, accessibility, and localization review.
- [ ] Preserve Free functionality and user data through cancellation, failures, expiry, and entitlement loss.

### UG-P03E — Live Lemon Squeezy lifecycle verification

- [ ] Configure the live one-time GBP product, licence generation, three-activation limit, hosted checkout, and customer licence delivery.
- [ ] Record and independently verify live IDs without committing credentials or customer data.
- [ ] Test successful purchase, cancellation/failure, three Macs, fourth-Mac rejection, deactivation/transfer, reinstall, lost-device recovery, refund, disablement, revocation, and eligible/ineligible major versions.
- [ ] Verify operational refund and activation-recovery procedures and redact all evidence.

### UG-P03F — Signed release candidate

- [ ] Configure Developer ID signing with Hardened Runtime and no Debug entitlement or `get-task-allow` leakage.
- [ ] Archive, notarise, staple, verify signature/Gatekeeper status, and inspect the Release binary for test-only licensing material.
- [ ] Run purchase, restart, offline-grace, deactivation, reinstall, and Free-fallback checks on clean supported Macs using the exact candidate.
- [ ] Update release documentation with evidence and blockers.
- [ ] Obtain explicit owner approval for the exact artifact and commercial copy before distribution or charging customers.
