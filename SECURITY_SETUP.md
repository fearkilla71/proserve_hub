# Security Hardening Setup Guide

This guide covers the three security enhancements implemented:

1. **Firebase App Check** - Blocks scripted abuse from non-app clients
2. **Rate Limiting** - Prevents spam/DoS attacks on Cloud Functions
3. **Job Discovery Privacy** - Limits who can see job postings

---

## 1. Firebase App Check

### What It Does
App Check verifies that requests to your Firebase services come from your actual app, not from bots or malicious scripts. It blocks unauthorized API access.

### Client-Side Setup (Already Completed)
✅ Installed `firebase_app_check: ^0.2.2+7` in `pubspec.yaml`
✅ Initialized App Check in `lib/main.dart` with debug mode for development

### Server-Side Setup (Already Completed)
✅ Enabled `enforceAppCheck: true` on critical Cloud Functions:
- `estimateJob` - 10 requests/hour per user
- `createEscrowPayment` - 20 requests/day per user
- `releaseEscrow` - 30 requests/day per user

### Required: Firebase Console Configuration

**⚠️ IMPORTANT: You must configure App Check in the Firebase Console for each platform:**

#### For Android:
1. Go to Firebase Console → Build → App Check
2. Click "Register" next to your Android app
3. Select **Play Integrity** as the provider
4. Save the configuration

#### For iOS/macOS:
1. In App Check settings, register your iOS/macOS app
2. Select **DeviceCheck** as the provider
3. Save the configuration

#### For Web:
1. In App Check settings, register your web app
2. Select **reCAPTCHA v3** as the provider
3. Get a reCAPTCHA v3 site key from https://www.google.com/recaptcha/admin
4. Update `lib/main.dart` line with your actual site key:
   ```dart
   webProvider: ReCaptchaV3Provider('YOUR_RECAPTCHA_V3_SITE_KEY'),
   ```

#### For Desktop (Windows/Linux):
Desktop platforms don't have native App Check providers. You have two options:
1. **Debug provider** (development only) - Already configured via `kDebugMode`
2. **Custom provider** - Implement your own attestation logic (advanced)

### Testing App Check

**Development Mode:**
- App Check is in debug mode when running with `flutter run`
- No console configuration needed for local testing

**Production Mode:**
When you build a release APK/IPA:
1. App Check will use Play Integrity (Android) or DeviceCheck (iOS)
2. Requests without valid App Check tokens will be rejected with HTTP 401
3. Monitor Cloud Functions logs to see rejected requests

---

## 2. Rate Limiting

### What It Does
Prevents spam and denial-of-service attacks by limiting how many times each user can call expensive functions.

### Implementation (Already Completed)
✅ Added `checkRateLimit()` function in Cloud Functions
✅ Uses Firestore `rate_limits` collection to track calls per user
✅ Enforces limits on:
- **estimateJob**: 10 calls per hour per user
- **createEscrowPayment**: 20 calls per day per user  
- **releaseEscrow**: 30 calls per day per user

### How It Works
1. Before processing a request, Cloud Function checks Firestore for recent calls
2. If limit exceeded, returns HTTP 429 (Too Many Requests) with retry time
3. Call history is stored in: `rate_limits/{userId}/calls/{functionName}`
4. Old call timestamps are automatically filtered out (time window expires)

### Monitoring Rate Limits
Check `rate_limits` collection in Firestore Console to see:
- Which users are hitting limits
- How many calls each user is making
- When limits will reset

### Adjusting Limits
Edit `functions/index.js` to change limits:
```javascript
// Example: Change estimate limit from 10/hour to 20/hour
const rateLimit = await checkRateLimit(uid, 'estimateJob', 20, 60 * 60 * 1000);
```

---

## 3. Job Discovery Privacy

### What It Does
Restricts who can see job postings to prevent scraping and improve privacy.

### Old Behavior
❌ Any signed-in user could read all job postings
❌ Competitors could easily scrape all jobs
❌ No privacy for customer job details

### New Behavior (Already Deployed)
✅ **Customers**: Can only see their own jobs
✅ **Contractors**: Can see unclaimed jobs + their claimed jobs
✅ **Admins**: Can see all jobs

### Firestore Rule
```
allow read: if isSignedIn() && (
  isAdmin() 
  || resource.data.requesterUid == request.auth.uid  // Customer's own job
  || resource.data.claimedBy == request.auth.uid     // Contractor's claimed job
  || (isContractor() && resource.data.claimed != true)  // Unclaimed jobs for contractors
);
```

### Impact on App Features
- ✅ Job browsing page for contractors: Works (shows unclaimed jobs)
- ✅ Customer's "My Jobs" page: Works (shows their own jobs)
- ✅ Contractor's claimed jobs page: Works (shows jobs they claimed)
- ✅ Admin dashboard: Works (sees all jobs)

### Further Privacy Options (Optional)

If you want even tighter privacy, you can:

1. **ZIP code filtering** - Only show jobs in contractor's service areas:
   ```
   || (isContractor() 
       && resource.data.claimed != true 
       && resource.data.zipCode in contractorServiceZips())  // Custom function
   ```

2. **Service type filtering** - Only show jobs matching contractor's services:
   ```
   || (isContractor() 
       && resource.data.claimed != true 
       && resource.data.serviceType in contractorServices())  // Custom function
   ```

3. **Blinded details** - Hide customer info until contractor expresses interest
   - Create separate collection for "job_details" with stricter rules
   - Show only summary in job_requests (service, location, budget range)
   - Reveal full details only after contractor applies

---

## Security Checklist

### Immediate Actions Required:
- [ ] Configure App Check in Firebase Console for Android (Play Integrity)
- [ ] Configure App Check in Firebase Console for iOS (DeviceCheck)  
- [ ] Get reCAPTCHA v3 site key for web
- [ ] Update `lib/main.dart` with actual reCAPTCHA key
- [ ] Test rate limiting by making rapid requests
- [ ] Test job discovery privacy from contractor account

### Optional Enhancements:
- [ ] Add rate limiting to more functions (messaging, file uploads)
- [ ] Implement ZIP/service-based job filtering
- [ ] Add detailed rate limit analytics dashboard
- [ ] Set up alerts for rate limit violations
- [ ] Create blinded job details system

### Monitoring:
- [ ] Enable Cloud Functions logs monitoring
- [ ] Set up Firebase Crashlytics for client errors
- [ ] Monitor `rate_limits` collection growth
- [ ] Track App Check verification failures

---

## Testing

### Test App Check:
1. Build a release APK: `flutter build apk --release`
2. Install on Android device
3. Try to call `estimateJob` - should work
4. Try to call from Postman/curl without App Check token - should fail with 401

### Test Rate Limiting:
1. Run app in debug mode
2. Request 10 estimates quickly
3. 11th request should fail with "Rate limit exceeded" message
4. Wait 1 hour, should work again

### Test Job Privacy:
1. Create customer account, post a job
2. Switch to contractor account  
3. Verify you can see the unclaimed job
4. Switch to different customer account
5. Verify you CANNOT see the first customer's job

---

## Troubleshooting

**App Check fails in debug mode:**
- Ensure `kDebugMode` is true when running `flutter run`
- Debug provider is automatically enabled

**Rate limits too strict:**
- Adjust the limits in `functions/index.js`
- Deploy with: `firebase deploy --only functions`

**Contractors can't see any jobs:**
- Check Firestore rules deployed correctly
- Verify contractor's `role` field is set to "contractor"
- Check if `claimed` field exists on jobs (should be false for unclaimed)

**Functions.config deprecation warning:**
- Migrate from `functions.config()` to environment variables
- Follow: https://firebase.google.com/docs/functions/config-env#migrate-config

---

## Next Steps

1. **Complete App Check setup** in Firebase Console (highest priority)
2. **Test all functionality** to ensure security rules don't break features
3. **Monitor rate_limits collection** for abuse patterns
4. **Consider additional security** like IP-based rate limiting
5. **Review Cloud Functions logs** regularly for suspicious activity

---

## Security Incident Response

If you detect abuse:

1. **Immediate**: Ban user via Firebase Auth console
2. **Investigate**: Check `rate_limits` and Cloud Functions logs
3. **Adjust**: Tighten rate limits if needed
4. **Monitor**: Watch for distributed attacks from multiple accounts

---

**Last Updated**: December 2024  
**Security Version**: v2.0 (App Check + Rate Limiting + Privacy)
