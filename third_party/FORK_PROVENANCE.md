# Third-Party Fork Provenance

This file documents the dependency overrides listed in `pubspec.yaml` that
point to local forks under `third_party/`.

## cloud_firestore v6.1.1

| Field | Value |
|-------|-------|
| Path | `third_party/flutterfire_forks/cloud_firestore` |
| Upstream | `firebase/flutterfire` – `packages/cloud_firestore/cloud_firestore` |
| Version | 6.1.1 (unmodified snapshot) |
| First committed | `6956839` (Initial commit) |
| Reason | Pinned to avoid breaking changes in upstream pub releases during development. No local patches applied. |
| Upgrade plan | Remove override once pub-hosted 6.1.x is confirmed compatible; run `flutter pub upgrade cloud_firestore`. |

## firebase_auth v6.1.3

| Field | Value |
|-------|-------|
| Path | `third_party/flutterfire_forks/firebase_auth` |
| Upstream | `firebase/flutterfire` – `packages/firebase_auth/firebase_auth` |
| Version | 6.1.3 (locally patched) |
| First committed | `6956839` (Initial commit) |
| Patches | `1ce7d4f` – macOS keychain fix: calls `useUserAccessGroup:nil` so keychain works without team-based code signing. Added diagnostic `NSLog` lines for sign-in errors. File: `macos/.../FLTFirebaseAuthPlugin.m`. |
| Reason | macOS simulator and keychain issues not yet fixed upstream. |
| Upgrade plan | Check upstream for `useUserAccessGroup` keychain fix. If merged, remove override and delete fork. |

## image_gallery_saver v2.0.3

| Field | Value |
|-------|-------|
| Path | `third_party/plugins/image_gallery_saver` |
| Upstream | `hui-z/image_gallery_saver` |
| Version | 2.0.3 (unmodified snapshot) |
| First committed | `6956839` (Initial commit) |
| Reason | Upstream pub package was stale; local copy ensures Gradle/AGP compatibility. No local patches applied. |
| Upgrade plan | Switch back to pub once upstream publishes a compatible release, or migrate to `gal` / `saver_gallery`. |
