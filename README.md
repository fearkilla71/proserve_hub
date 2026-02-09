# ProServe Hub

Marketplace app that connects customers with contractors for service jobs.

This README is primarily a “feature memory” doc so you can come back later and quickly remember what the app does and what infrastructure/security is in place.

## Platforms

- Flutter (Windows desktop + Android + iOS + Web scaffolding)
- Firebase (Auth, Firestore, Storage, Cloud Functions, FCM)
- Stripe (Escrow-style payments via PaymentIntents + Connect)

## Roles

- **Customer**: posts jobs, chats, pays escrow, reviews
- **Contractor**: browses/claims jobs, submits bids, chats, gets paid
- **Admin**: dashboard + analytics

## Feature List

### Authentication & Account

- Email/password auth (Firebase Auth)
- Role-based routing: customer portal vs contractor portal vs admin dashboard
- Onboarding flow (tracked locally via `shared_preferences`)

### Customer Features

- Create job/service requests
- View/manage your own job requests
- View job details
- Receive contractor bids
- Chat with contractors
- Escrow payments (fund escrow, then release on completion)
- Leave reviews (only after completed jobs)

### Contractor Features

- Contractor portal/dashboard
- Browse available unclaimed jobs
- Claim/accept jobs
- Submit bids
- Chat with customers
- Stripe Connect onboarding (connect payout account)
- Receive payout when escrow is released

### Admin Features

- Admin dashboard
- Analytics tab (tracks completed jobs + commission calculations)

### Messaging & Notifications

- Real-time chat (Firestore conversations + messages)
- Push notifications via FCM
- Notification deep links into:
	- Chat thread
	- Job detail
	- Job/bid status events

### Media & Attachments

- Job images (Storage)
- Chat images (Storage)
- Chat file attachments (Storage)
- Review photos (Storage)

### Payments (Stripe)

- Escrow PaymentIntent creation (manual capture)
- Platform fee: **7.5%** application fee on escrowed amount
- Contractor payout via Stripe Connect destination transfer
- Checkout session support (web payment flow)
- Stripe webhook endpoint

## Security & Abuse Prevention (Implemented)

### Firestore Rules

- Conversations: participants-only read/write
- Messages: participants-only read; create-only (immutable after send)
- Bids: contractor create validation; customer updates limited to status changes
- Reviews: customer can create only for their own completed jobs; immutable after creation
- Job discovery privacy:
	- Customers can read their own jobs
	- Contractors can read unclaimed jobs + jobs they claimed
	- Admins can read everything

### Storage Rules

- Job images: uploader-only access (size + content-type limited)
- Chat images/files: conversation participants only (size + content-type limited)
- Review photos: limited to eligible job requester (size + content-type limited)

### Firebase App Check

- Client wiring is enabled.
- Server enforcement is enabled for critical callable Cloud Functions.

Notes:
- App Check is not supported on Windows/Linux desktop.
- Android uses Play Integrity in release mode.
- iOS uses DeviceCheck in release mode.

### Rate Limiting (Cloud Functions)

Firestore-backed per-user rate limiting is enforced on:

- `estimateJob`: 10/hour
- `createEscrowPayment`: 20/day
- `releaseEscrow`: 30/day

## Repository Structure (Quick Pointers)

- Flutter app entry: [lib/main.dart](lib/main.dart)
- Main UI screens: [lib/screens/](lib/screens/)
- Services (FCM, admin guard, logging): [lib/services/](lib/services/)
- Cloud Functions: [functions/index.js](functions/index.js)
- Firestore rules: [firestore.rules](firestore.rules)
- Storage rules: [storage.rules](storage.rules)

## Local Dev

### Flutter

- `flutter pub get`
- `flutter run -d windows`

### Firebase emulators (optional)

The app supports a compile-time flag:

- `--dart-define=USE_FIREBASE_EMULATORS=true`

## Deployment Notes

- PowerShell deploy requires quotes when using comma-separated `--only`:
	- `firebase deploy --only "functions,firestore:rules" --non-interactive --force`

## Extra Documentation

- Security setup and App Check console steps: [SECURITY_SETUP.md](SECURITY_SETUP.md)
