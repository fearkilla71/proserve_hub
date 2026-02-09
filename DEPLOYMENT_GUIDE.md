# ProServe Hub - Deployment Guide

## Pre-Deployment Checklist

### 1. Code Quality
- [x] `flutter analyze` passes with no issues
- [x] All features tested locally
- [ ] All unit tests passing (if applicable)
- [ ] Integration tests passing (if applicable)

### 2. Firebase Configuration
- [ ] Firestore security rules deployed
- [ ] Firebase Storage rules updated (if needed)
- [ ] Firestore composite indices created (check console for prompts)
- [ ] Firebase project limits reviewed (free tier vs paid)

### 3. App Configuration
- [ ] Version number updated in `pubspec.yaml`
- [ ] Build number incremented
- [ ] Environment variables set (if any)
- [ ] API keys secured (not in version control)

### 4. Testing
- [ ] Test on real Android device
- [ ] Test on real iOS device (if applicable)
- [ ] Test offline functionality
- [ ] Test image uploads/compression
- [ ] Test messaging real-time updates
- [ ] Test bidding workflow end-to-end
- [ ] Test profile completion tracker
- [ ] Test onboarding tutorial

---

## Deployment Steps

### Step 1: Deploy Firestore Security Rules

```bash
# Make sure you're in the project directory
cd c:\Users\Carvic\Documents\proserve_hub

# Deploy only Firestore rules (safer than deploying everything)
firebase deploy --only firestore:rules

# Verify in Firebase Console → Firestore Database → Rules
```

**Expected Output:**
```
✔  Deploy complete!
Project Console: https://console.firebase.google.com/project/YOUR_PROJECT/overview
```

**Verification:**
- Go to Firebase Console
- Navigate to Firestore Database → Rules
- Confirm last deployed timestamp is recent
- Review rules in console match local `firestore.rules` file

---

### Step 2: Create Firestore Indices (if needed)

Some queries require composite indices. If you see errors like "The query requires an index", follow these steps:

1. **Check for index requirements:**
   - Run the app and perform all actions (messaging, bidding, etc.)
   - Watch the console for index creation links
   - OR check Firebase Console → Firestore Database → Indexes

2. **Common indices needed for Phase 1:**

   **Bids Collection:**
   - Fields: `jobId` (Ascending), `createdAt` (Descending)
   - Fields: `contractorId` (Ascending), `status` (Ascending)
   - Fields: `customerId` (Ascending), `status` (Ascending)

   **Conversations Collection:**
   - Fields: `participantIds` (Array), `lastMessageTime` (Descending)

   **Messages Subcollection:**
   - Fields: `conversationId` (Ascending), `timestamp` (Descending)

3. **Create indices:**
   - Click the index creation link in console error message, OR
   - Go to Firebase Console → Firestore Database → Indexes → Create Index
   - Fill in collection, fields, and sort order
   - Click "Create Index" and wait for completion (can take several minutes)

---

### Step 3: Update Firebase Storage Rules (Optional)

If you need to update Storage rules for image uploads:

```bash
firebase deploy --only storage
```

**Default Storage Rules (already in place):**
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

---

### Step 4: Build Release APK (Android)

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build release APK
flutter build apk --release

# OR build App Bundle (preferred for Play Store)
flutter build appbundle --release
```

**Output locations:**
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- Bundle: `build/app/outputs/bundle/release/app-release.aab`

**APK size optimization (optional):**
```bash
# Build split APKs by architecture (smaller file sizes)
flutter build apk --release --split-per-abi
```
This creates separate APKs for arm64-v8a, armeabi-v7a, and x86_64.

---

### Step 5: Build Release for iOS (if applicable)

```bash
# Make sure you have valid provisioning profile and certificates
flutter build ios --release

# OR build IPA for distribution
flutter build ipa
```

**Note:** iOS builds require:
- Mac with Xcode installed
- Apple Developer account
- Valid provisioning profile
- App ID registered in Apple Developer portal

---

### Step 6: Test Release Build

**Android:**
```bash
# Install release APK on connected device
adb install build/app/outputs/flutter-apk/app-release.apk

# OR use Flutter command
flutter install --release
```

**iOS:**
- Open Xcode
- Select release scheme
- Build and run on physical device
- Test all features

**Test these critical features:**
1. User authentication (signup/login)
2. Create job with photos (verify compression)
3. Submit bid as contractor
4. View bids as customer
5. Accept bid (verify job claiming)
6. Send messages (text + images)
7. Check read receipts
8. Verify offline banner appears when offline
9. Test onboarding (delete app, reinstall)
10. Test profile completion tracker

---

### Step 7: Upload to App Stores

#### Google Play Store

1. **Prepare listing:**
   - Create app on Google Play Console
   - Fill in app details (title, description, screenshots)
   - Upload app icon (512x512 PNG)
   - Add privacy policy URL (required)

2. **Upload build:**
   - Go to Play Console → Release → Production
   - Create new release
   - Upload `app-release.aab` (App Bundle preferred)
   - Review release notes
   - Set rollout percentage (optional, start with 10%)
   - Click "Review release" → "Start rollout"

3. **Store listing screenshots needed:**
   - Phone: 2-8 screenshots (1080x1920 or 1080x2340)
   - Tablet: 2-8 screenshots (1200x1920)
   - Feature graphic: 1024x500
   - Recommended: Show messaging, bidding, job flow

#### Apple App Store (if applicable)

1. **Prepare listing:**
   - Create app on App Store Connect
   - Fill in app details
   - Upload screenshots (per device type)
   - Upload app icon (1024x1024)

2. **Upload build:**
   - Use Xcode → Archive → Distribute App
   - OR use Transporter app
   - Upload IPA file
   - Wait for processing (can take 30+ minutes)

3. **Submit for review:**
   - Select build in App Store Connect
   - Fill in review information
   - Submit for review
   - Wait for approval (typically 1-3 days)

---

## Post-Deployment Monitoring

### Firebase Console Monitoring

1. **Firestore Usage:**
   - Go to Firebase Console → Usage & Billing
   - Monitor daily reads/writes
   - Check for unexpected spikes
   - Free tier limits:
     - 50K reads/day
     - 20K writes/day
     - 1GB storage

2. **Storage Usage:**
   - Monitor uploaded images
   - Check compression is working (files should be < 1MB)
   - Free tier: 5GB storage, 1GB download/day

3. **Authentication:**
   - Monitor user signups
   - Check for suspicious activity
   - Free tier: unlimited (but review rate limits)

### Performance Monitoring

**Set up Firebase Performance Monitoring:**
```bash
# Add to pubspec.yaml
firebase_performance: ^0.9.0

# Import in main.dart
import 'package:firebase_performance/firebase_performance.dart';

# Initialize
await Firebase.initializeApp();
await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
```

**Set up Crashlytics:**
```bash
# Add to pubspec.yaml
firebase_crashlytics: ^3.4.0

# Import in main.dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

# Initialize
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
```

---

## Rollback Plan

If critical issues are discovered post-deployment:

### Option 1: Quick Fix
1. Identify and fix the issue in code
2. Build new release with incremented version
3. Upload to stores (expedited review if critical)

### Option 2: Revert Firestore Rules
```bash
# Revert to previous version in Firebase Console → Firestore → Rules → History
# OR redeploy from backup
firebase deploy --only firestore:rules
```

### Option 3: Disable Features
- Use remote config to disable problematic features
- Add feature flags in app settings
- Deploy backend changes without app update

### Option 4: Full Rollback (Last Resort)
- Revert Git repository to previous stable commit
- Rebuild and redeploy previous version
- Communicate issue to users via in-app message

---

## Version Numbering

Follow semantic versioning: `MAJOR.MINOR.PATCH`

**Current version (Phase 1):** `1.1.0`

- **MAJOR**: Breaking changes, major features
- **MINOR**: New features, backwards compatible
- **PATCH**: Bug fixes, small improvements

**Update in `pubspec.yaml`:**
```yaml
version: 1.1.0+2
# Format: version+buildNumber
# Increment buildNumber for each build
```

---

## Hotfix Process

For urgent production issues:

1. **Create hotfix branch:**
   ```bash
   git checkout -b hotfix/issue-description
   ```

2. **Fix the issue:**
   - Make minimal changes
   - Test thoroughly
   - Update version (increment PATCH)

3. **Build and test:**
   ```bash
   flutter build apk --release
   # Test on device
   ```

4. **Deploy:**
   ```bash
   # Deploy backend changes if needed
   firebase deploy --only firestore:rules
   
   # Upload to stores
   # Request expedited review if critical
   ```

5. **Merge back:**
   ```bash
   git checkout main
   git merge hotfix/issue-description
   git push
   ```

---

## Support Contacts

- **Firebase Support:** https://firebase.google.com/support
- **Flutter Issues:** https://github.com/flutter/flutter/issues
- **Play Console Support:** https://support.google.com/googleplay/android-developer
- **App Store Connect Support:** https://developer.apple.com/support/app-store-connect/

---

## Changelog

### v1.1.0 (Phase 1) - December 2024
**New Features:**
- Real-time messaging system with photo sharing
- Competitive bidding system with counter-offers
- Onboarding tutorial for new users
- Profile completion progress tracker
- Automatic image compression
- Offline detection banner
- Smooth page transitions

**Technical:**
- Added Firestore collections: bids, conversations, messages, reviews, portfolios
- Updated security rules for new collections
- Added dependencies: shared_preferences, image_picker, flutter_image_compress, connectivity_plus
- Created ConversationService helper
- Enhanced job detail page with bid/message integration

**Bug Fixes:**
- None (initial Phase 1 release)

### v1.0.0 - November 2024
**Initial Release:**
- AI-powered photo estimates
- Smart contractor matching
- Stripe escrow integration
- Basic job posting and claiming flow
- User authentication (customer/contractor)
- Firebase backend integration

---

## Additional Resources

- **PHASE_1_FEATURES.md** - Detailed feature documentation
- **PHASE_1_SUMMARY.md** - Implementation summary and architecture
- **QUICK_START.md** - User guide for customers and contractors
- **README.md** - Project overview and setup instructions
- **firestore.rules** - Security rules with comments
- **pubspec.yaml** - Dependencies and configuration

---

## Success Criteria

Post-deployment, consider Phase 1 successful if:

- ✅ No critical crashes (Crashlytics)
- ✅ < 5% error rate on key operations (messaging, bidding)
- ✅ Average message response time < 2 seconds
- ✅ Image compression reduces upload size by > 50%
- ✅ Onboarding completion rate > 70%
- ✅ Profile completion rate > 50% within 24 hours
- ✅ Bid submission rate > 20% on unclaimed jobs
- ✅ User ratings remain above 4.0 stars

Monitor these metrics in:
- Firebase Analytics
- Google Play Console (Android)
- App Store Connect (iOS)
- Firestore usage statistics

---

## Final Checklist Before Going Live

- [ ] All code merged to main branch
- [ ] Version number updated
- [ ] Firestore rules deployed and tested
- [ ] Indices created for all required queries
- [ ] Release build tested on real devices
- [ ] Screenshots updated for app stores
- [ ] Privacy policy published
- [ ] Terms of service published
- [ ] Support email/contact set up
- [ ] Monitoring and analytics configured
- [ ] Backup of current production state taken
- [ ] Team notified of deployment
- [ ] Rollback plan prepared
- [ ] Documentation up to date

**Once checklist complete:**
🚀 Deploy to production!

---

Last updated: December 2024
