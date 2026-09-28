# UsageGrid Pro Licensing

## Agreed commercial direction

UsageGrid is planned for direct distribution as a Developer ID signed and notarised Mac app. UsageGrid Pro is planned as a one-off purchase through Lemon Squeezy, using hosted checkout and licence-key activation. The initial design does not require a separate UsageGrid account.

The price and currency, number of permitted Macs, future major-version/update entitlement policy, and offline validation/grace-period duration are not yet decided. No device allowance should be advertised until it is agreed and implemented.

Existing Free capabilities remain Free: live supported-provider usage, menu-bar display, Programming and Professional themes, the primary threshold alert, setup guidance, and support diagnostics.

## Planned customer lifecycle

1. The customer opens a Lemon Squeezy hosted checkout from a signed UsageGrid build.
2. Lemon Squeezy completes the one-off purchase and supplies a licence key.
3. The customer enters the key in UsageGrid.
4. UsageGrid asks the licensing service to activate it and validates that the response belongs to the configured UsageGrid store and Pro product.
5. Only a verified response grants the shared Pro entitlement.
6. The licence key and activation identifier are stored in the macOS Keychain for later validation and deactivation.

Possessing a key-shaped string, a stored credential, or a user-editable preference is never sufficient. A stored credential must be validated before production access is granted. Merchant API secrets must not be embedded in the app; public product/store identifiers and the provider’s client-safe licence endpoints are the intended boundary.

## Local credential boundary

The Keychain item uses stable app-specific identifiers:

- Service: `com.plutonightlabs.UsageGrid.license`
- Account: `lemonsqueezy.pro-license`

Only the licence key and activation identifier are represented by the P01 credential model. Licence keys, purchase details, activation identifiers, raw licensing responses, and arbitrary licensing errors must not appear in application logs or Support diagnostics. Tests use injected in-memory storage and do not touch the real Keychain.

P01 includes the Keychain storage implementation but does not connect it to app launch or the production entitlement boundary. P02 will define when stored credentials are loaded and validated.

## Validation and offline policy

Every activation and validation result must match the configured UsageGrid store and Pro product before it can grant access. The real identifiers are intentionally not configured in P01.

Cached validation and offline operation are required design topics, but the grace duration and expiry behavior remain undecided. P01 does not implement or imply a grace period. P02 must test cache age, offline startup, provider outages, clock changes, revocation, and recovery against an owner-approved policy before production use.

## Deactivation, transfers, refunds, and revocation

Planned deactivation sends the stored activation identifier to the licensing service and removes the local Keychain credential only after the lifecycle outcome is handled. Device transfer will use deactivation followed by activation on another Mac, subject to the future permitted-Mac policy.

Refunded or revoked licences must stop granting Pro after authoritative validation. Losing entitlement must fall back to Free presentation without deleting recorded history, theme choices, alert preferences, or other user settings. Data review and deletion remain available. Failure to validate must be presented separately from a confirmed revocation; final retry and offline behavior belongs to the undecided policy.

## P01 implementation boundary

P01 adds:

- A small activation, validation, and deactivation service interface.
- Unavailable, inactive, activating, verified-active, and safe failure states.
- A credential-storage interface and macOS Keychain implementation.
- An isolated activation preview with secure licence entry, progress, safe feedback, duplicate-submit prevention, cancellation, and obsolete-completion protection.
- Injected tests for lifecycle and storage behavior.

Production purchasing and activation remain unavailable. The preview’s activation control is disabled in the production foundation, no checkout URL or network implementation exists, and the existing shared Pro-access controller remains unentitled. Debug Pro simulation remains a separate internal-only feature and is not connected to licensing.

The P02 integration point is deliberately narrow: after a real Lemon Squeezy test-mode service verifies the configured store/product identity and the approved validation policy, its verified entitlement can feed `ProAccessController`. Until then, feature checks remain unchanged.

## Delivery stages

- **UG-P01 — Licensing model, storage boundary, and isolated activation UI:** interfaces, state model, Keychain boundary, disabled production preview, documentation, and injected tests.
- **UG-P02 — Lemon Squeezy test-mode integration and lifecycle verification:** hosted test checkout, client-safe activation/validation/deactivation, configured test identity, restart/recovery/revocation/offline-policy tests, and connection to shared access only after verification.
- **UG-P03 — Live configuration and signed-artifact purchase testing:** owner-approved commercial policies, live product/store configuration, Developer ID signed and notarised artifact, clean-Mac purchase/activation/deactivation/transfer/refund testing, and final release approval.

No live product, payment, checkout, signing, or publishing work is part of P01.
