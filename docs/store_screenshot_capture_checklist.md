# Store Screenshot Capture Checklist

Use the internal `/screenshot-demo` route for 1.7.0 screenshot capture.

## Capture Story

1. Landing: role choice and trust promise.
2. Customer Home: one clear next action.
3. Browse Pros: verified contractors and save/compare behavior.
4. Quote Comparison: price, ETA, warranty, scope, proof, and escrow trust.
5. Job Command Center: chat, photos, invoice, escrow, timeline, and review.
6. Contractor Home: account health, tools, jobs, payouts, and escrow.
7. Tools: tier-aware contractor operating system.
8. Leads: lead credits, filters, payout readiness, and next action.
9. Invoice: branded invoice creation and payment link path.
10. Escrow: protected payment state and release/refund visibility.

## Capture Rules

- Use the same branch on Windows and Mac.
- Capture English first, then Spanish if store listing requires localized shots.
- Use a clean Pixel-sized Android emulator and one iPhone-sized simulator.
- Hide real customer contact details, payment identifiers, and private chat data.
- Prefer realistic internal/test data over empty states.
- Do not enable demo mode in public production builds.

## Build Flag

Demo capture is available in debug builds or with:

```bash
--dart-define=PROSERVE_DEMO_MODE=true
```
