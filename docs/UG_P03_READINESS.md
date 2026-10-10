# UG-P03 — Policy, production licensing and signed-artifact gates

Documentation reconciliation: 10 October 2026. Baseline: main `1efb4d2b85ad77cb733f349693358d77d87d55ec` (UG-P02).
Status: **BLOCKED for production configuration/purchases and signed-artifact validation; documentation preparation complete.** No production activation or distribution readiness is claimed.

## Source decisions and remaining approvals

[PRO_LICENSING.md](PRO_LICENSING.md) records the source review and policy status. Carry forward £9.99 GBP one-time, up to three active Macs, and no expiry for the purchased major version; future paid major upgrades may be separate. Do not promise lifetime updates.

Seven days of offline grace remains a **recommendation**, not approval. Before implementing production behaviour, record owner approval of the duration and the technical semantics: elapsed time since last successful validation, launch/periodic validation cadence and backoff, secure persisted cache, clock rollback/forward handling, grace expiry, revocation precedence and online recovery. The non-expiring purchased-major-version licence does not mean indefinite offline validation.

Detailed support/refund terms, tax-inclusive/exclusive display and any non-GBP checkout presentation, major-version mapping and paid-upgrade handling remain unresolved. These do not reopen the confirmed base price, three-Mac allowance or purchased-major-version right. Do not invent discounts, support duration or future upgrade prices.

## What P02 actually provides

- `Sources/UsageGrid/ProLicensing.swift`: Debug-only Lemon Squeezy test service, test identity Store `485681` / Product `1395768` / Variant `2179685`, exact identity matching, separate test Keychain namespace and activation/validation/deactivation UI.
- Restart validates the stored instance online once; it never silently activates a new one. Offline/ambiguous failure removes test access. This is test isolation, not production outage behaviour.
- Credential model stores key and activation ID only. There is no persisted last-successful-validation timestamp, version-bound offline entitlement cache or production grace calculation.
- Controller `begin` and `finishFailure` clear test entitlement. Production must preserve a still-valid cached grant on transient failures under the approved policy, and remove it on authoritative revocation.
- `productionFoundation()` uses unavailable service/storage and nil identity; production activation remains disabled and Release Free.
- Test service maps general rejection to invalid/revoked and non-2xx to network failure. Production needs safe distinctions for activation-limit, definitive licence status, transport/5xx/throttling and ambiguous responses; do not display arbitrary provider errors.
- Secure-storage retry after remote activation uses an in-memory pending credential. Restart/crash recovery and ambiguous remote success require explicit reconciliation to avoid consuming another slot.
- Existing injected tests cover lifecycle, identity mismatch, restart online validation without activation, access loss, storage retry, deactivation retry and transport failures. They do not prove real merchant settings, three-Mac limit, transfer/refund, production offline recovery or a signed artifact. Existing test evidence in the release checklist is historical; no Swift tests were rerun for this documentation change.

## Prerequisites, in order

1. **Policy record:** retain confirmed terms; explicitly approve the remaining offline semantics and customer support/upgrade/refund wording before production implementation and claims.
2. **Production configuration evidence:** owner-reviewed store/product/variant identity and hosted checkout mapping for UsageGrid Pro/purchased major version; GBP £9.99 one-time, key generation, no expiry, activation limit 3; merchant/checkout availability and recovery via receipt/My Orders. Configuration must be verified independently of the test IDs. A key or a success flag is insufficient without exact identity and instance validation.
3. **Implementation gate:** client-safe production service and shared verified entitlement, purchase/recovery/deactivate UI, Keychain persistence, major-version identity mapping, approved offline cache/cadence and safe errors. Never embed merchant secrets. Keep test and production storage separate; no test-to-production credential migration or entitlement import.
4. **Recovery and security gate:** deterministic fixtures for outages/expiry/revocation, duplicate/cancellation/obsolete completion, Keychain failure and remote/local partial success; diagnostic and binary checks. Resolve unknown remote activation/deactivation outcomes without blindly retrying activation.
5. **Apple gate:** UG-APPLE-01 was Blocked, last reviewed 1 October, for Apple/D-U-N-S prerequisites. Current Apple status is **not independently verified**. Evidence active Pluto Night Labs organisation membership, correct Team, valid Developer ID Application certificate with usable private key on the build Mac, Release signing configuration and authorised notarisation access. Do not attempt signing with a missing identity or treat ad hoc signing as distribution proof.
6. **Artifact gate:** build/test on supported macOS, Developer ID sign with Hardened Runtime, notarise, staple where applicable, verify signature/Gatekeeper, and install the exact version/build/artifact on a clean supported Mac/profile. Record artifact hash, Team and sanitised evidence. No Gatekeeper bypass.
7. **Controlled validation and release gate:** after separate authorisation for production configuration/payment testing, validate the lifecycle below on the signed artifact. Public checkout, purchase enablement, download publication and release require approval of the exact artifact and truthful copy. Core Codex reliability, privacy/support and other existing release gates remain separate requirements.

This task authorises none of live setup, purchases, credentials, signing or publishing. Bounded documentation work and injected fixture design can proceed without Apple access.

## UG-P03 acceptance matrix — all pending evidence

Use injected deterministic tests for branches and boundaries; use controlled merchant/clean-Mac tests to prove remote settings and actual Keychain/signing behaviour. Do not mark either complete based solely on the other.

| Scenario | Required result / evidence |
| --- | --- |
| Exact production identity | Activation and validation require success plus expected store, product and variant, compatible purchased major version and valid instance. Test each wrong identity independently; missing metadata, mismatched instance and test identity never grant production Pro. Verify deactivation identity too. |
| Hosted checkout / receipt | Approved checkout maps to the correct production product/variant, £9.99 GBP one-time and disclosed tax/currency treatment. Cancelled checkout does not grant Pro. Receipt/My Orders recovery supplies the key; checkout return alone is not entitlement. Do not execute until authorised. |
| Fresh activation | One deliberate submission creates one instance, securely persists key/instance and verified grant, then unlocks shared Pro. Empty/malformed/unknown, disabled and wrong-product keys grant nothing. Duplicate clicks/cancellation/late completion cannot duplicate or resurrect entitlement. |
| Three-Mac limit | Macs 1–3 activate; Mac 4 is refused with actionable three-Mac copy and no local Pro grant. Actual provider settings and activation counts evidenced without keys in reports. |
| Restart online | Saved key plus instance validates; no activate call or extra slot. Merely saved, edited, corrupted or inaccessible credentials do not grant Pro. |
| Reinstall / Keychain | Surviving Keychain recovers the same instance and validates. Missing/inaccessible Keychain does not silently activate. After remote success/local save failure, retry persistence without another remote activation; crash/restart and ambiguous-success recovery cannot leak slots. |
| Offline startup | A never-validated key grants nothing. Previously verified, identity/version/instance-bound cache follows the approved grace. Retain credentials and show validation pending; no activate call. Cover restart and tampered/future/rolled-back timestamps. |
| Grace boundary / prolonged outage | Inject a clock; test before, exactly at and after the approved boundary, timeout, 5xx, throttling and malformed responses. Transient failure preserves access only within approved bounds; no failed request resets the last-successful-validation time or extends grace indefinitely. |
| Grace expiry and online recovery | After expiry, fall back to Free with “Connect to validate your licence”; preserve credentials and user data. Successful online validation of the same instance restores Pro and updates the cache, without activating again. |
| Deactivate successfully | Confirm remote deactivation for saved key/instance and identity; remove local credential/cache/grant and prove the slot freed. Local cleanup failure cannot leave a trusted cached grant; provide safe recovery. |
| Deactivate failure / unknown outcome | Failure/timeout/mismatch retains recovery credentials, does not claim a slot freed, and never silently reactivates. Reconcile remote-success/local-delete failure and timeout-after-remote-success with explicit retry/recovery and truthful local status. |
| Transfer / lost Mac | Deactivate old Mac, activate new Mac; old Mac loses Pro, slot counts remain within three. Test lost-Mac support reset and subsequent stale-instance rejection. Any offline detection delay is bounded by approved grace and disclosed. |
| Revocation / refund / expired or removed instance | Confirmed server invalid/disabled/expired or instance invalidation overrides cache immediately, restores Free and cannot be masked by grace. Evidence actual refund-to-licence behaviour; do not assume refund automatically revokes. Support procedure must explicitly disable/reset when needed. Offline clients can discover changes only on reconnection or grace expiry. |
| Major-version entitlement | Same purchased-major-version update/reinstall preserves rights; no expiry is introduced by validation refresh. A key cannot unlock an unpurchased paid major version. Future major upgrade cannot retroactively revoke the purchased version. Mapping/enforcement must be specified before claiming completion. |
| Free/data boundary | Core live usage, menu-bar display, Programming/Professional themes, primary alert, setup and safe diagnostics stay Free. Entitlement loss restores Free presentation without deleting history, saved themes or preferences; data review/deletion remain accessible. No preview or edited preference grants Pro. |
| Debug/Release isolation | Release contains no test IDs, test Keychain namespace, simulation or test controls; test key/storage never grants production access. Until UG-P03 is completed, Release remains unentitled. Later authorised production Release can use client-safe endpoints but never merchant secrets. |
| Privacy / errors | No keys, instance IDs, purchase data, raw responses or arbitrary provider errors in logs, screenshots or support diagnostics. Friendly fixed errors distinguish invalid key, wrong product, limit, outage, Keychain and revoked status. |
| Signed clean-Mac lifecycle | Exact signed/notarised artifact passes clean install, first launch, missing Codex handling, activation, restart, offline recovery, deactivation and transfer. Signature, Gatekeeper and Keychain persistence evidence are tied to artifact hash; mocked tests and ad hoc builds do not satisfy this row. |

## Evidence and handoff

For each row record NOT TESTED / PASS / FAIL, environment and app/build/commit, command or reproducible steps, expected/actual behaviour, sanitised evidence and unresolved blockers. Never include licence keys or activation identifiers. Link policy approval and production-setting evidence without adding credentials.

Documentation reconciliation is complete only when all active development documents stop describing the confirmed price/device/version terms as undecided. UG-P03 and distribution readiness remain incomplete until their separate evidence gates pass.

References: [Launch pack](https://app.notion.com/p/3ebda2049a6481a0957acfac8b718394), [Apple task](https://app.notion.com/p/3ecda2049a6481ccba17c80915dee2b9), [activate API](https://docs.lemonsqueezy.com/api/license-api/activate-license-key), [validate API](https://docs.lemonsqueezy.com/api/license-api/validate-license-key), [deactivate API](https://docs.lemonsqueezy.com/api/license-api/deactivate-license-key).
