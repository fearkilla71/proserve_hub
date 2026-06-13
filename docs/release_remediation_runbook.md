# ProServe Hub Release Remediation Runbook

This runbook covers fixes that require dashboard owner/admin access after the
repo changes are deployed.

## Stripe

1. Create a live webhook destination in Stripe Workbench.
2. Endpoint URL: the deployed Firebase `stripeWebhook` HTTPS URL.
3. Subscribe at minimum to:
   - `checkout.session.completed`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `account.updated`
   - `charge.dispute.created`
   - `charge.refunded`
4. Copy the signing secret into Firebase:
   `firebase functions:secrets:set STRIPE_WEBHOOK_SECRET`
5. Send a test event and confirm the function returns `200`.

## Google Play Billing

1. Create a Pub/Sub topic named `play-billing-rtdn` in the Firebase/GCP project.
2. Grant Google Play permission to publish to that topic.
3. In Play Console, enable Real-time developer notifications.
4. Set the topic name to `projects/proserve-hub-ada0e/topics/play-billing-rtdn`.
5. Send a test notification and confirm `googlePlayBillingRtdn` logs receipt.
6. Confirm the Firebase service account has Android Publisher API access.

## Firebase App Check and API Keys

1. Register Android package `com.verohue.proservehub` with Play Integrity.
2. Register iOS bundle `com.verohue.proservehub` with DeviceCheck/App Attest.
3. Restrict Firebase API keys:
   - Android: package name plus Play/upload SHA-256 fingerprints.
   - iOS: bundle ID.
   - Browser: `proservehub.app`, Firebase Hosting domains, and Netlify domain if still used.
4. After app versions with valid App Check are released, enforce App Check for
   Firestore, Storage, Authentication where available, and callable/HTTP
   Functions.

## Android App Links

1. Replace `REPLACE_WITH_PLAY_APP_SIGNING_SHA256` in
   `public/.well-known/assetlinks.json` with the Play App Signing SHA-256.
2. Deploy Hosting.
3. Verify `https://proservehub.app/.well-known/assetlinks.json` is publicly
   reachable with `Content-Type: application/json`.
4. Confirm Play Console deep-link validation passes for `proservehub.app`.

## Apple

Verified in App Store Connect on 2026-06-13:

- The rejected submission `693c8e6d-ac4a-40ed-bd6f-f6d334ade061` submitted
  only `iOS App 1.5.0`; it did not include the subscription products.
- Paid Apps Agreement is still `New` and must be accepted from Business before
  paid subscriptions can be approved/sold.
- Digital Services Act / EU trader status is `Active`.
- Subscription group `contractor_subscriptions` exists with both products:
  `contractor_pro_monthly_11_99` and
  `contractor_enterprise_monthly_29_99`.
- Both subscription products show pricing, English localization, review
  screenshot, all-region availability, and `Waiting for Review` status.
- Lead consumables `lead_ne_1` and `lead_ex_1` also exist and show
  `Waiting for Review`.
- `APP_STORE_SHARED_SECRET` exists in Firebase Functions secrets.

1. Account Holder accepts the updated Apple Developer Program License Agreement.
2. Complete EU trader status.
3. Confirm `APP_STORE_SHARED_SECRET` is set in Firebase Functions secrets.
4. Confirm the Paid Apps Agreement is active in App Store Connect Business.
5. Confirm both auto-renewable subscriptions are complete and available:
   - `contractor_pro_monthly_11_99`
   - `contractor_enterprise_monthly_29_99`
6. Download the two attached App Review `.ips` crash logs and symbolicate them
   against the archive used for the submitted build:
   ```sh
   xcrun crashlog path/to/crashlog.ips \
     --archive ios/build/Runner.xcarchive
   ```
   If `xcrun crashlog` is unavailable, open the `.ips` in Xcode Organizer with
   `ios/build/Runner.xcarchive` available locally.
7. Use a fresh contractor review account:
   - Email and phone already verified.
   - No active subscription.
   - No existing lead credits.
8. Update App Review notes with deterministic paths for:
   - Pro subscription.
   - Enterprise subscription.
   - Restore purchases.
   - Normal lead purchase.
   - Exclusive lead purchase.
   - Customer non-IAP flow.
9. On the next review submission, add the app version/build and include both
   subscription products in the submitted items. Apple rejected build 10 with
   only the app version in `Items Submitted`.
10. Use manual or phased release until payment and entitlement reconciliation are
   verified in production.

Suggested App Review reply after the fixed build is uploaded:

> Thank you for the detailed review. We addressed the crash reported when
> tapping "Upgrade with Card" by removing the card/Stripe subscription path from
> the iOS app. Pro and Enterprise upgrades now use Apple In-App Purchase only.
> We also hardened purchase and restore handling so StoreKit errors and receipt
> verification failures are shown clearly, and successful sandbox purchases
> immediately verify server-side and update the contractor entitlement. The
> attached crash logs were reviewed against the submitted archive, and the
> reported trigger is no longer present in the iOS subscription flow.
>
> Review steps:
> 1. Sign in with the provided contractor review account.
> 2. Open Subscription Plans.
> 3. Tap Subscribe with Apple for Pro, complete the sandbox purchase, and verify
>    the plan updates to Pro.
> 4. Repeat with the Enterprise plan if needed.
> 5. Use Restore Purchases to verify restored subscriptions update the plan.

## GitHub

1. Enable Dependabot alerts and security updates.
2. Enable code scanning alerts for CodeQL.
3. Add a branch ruleset for `main` requiring CI and CodeQL checks.
4. Set the default `GITHUB_TOKEN` permission to read-only.
