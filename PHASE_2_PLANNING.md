# Phase 2 Planning - Next Steps

## Priority Queue

### 🔥 High Priority (Critical for marketplace success)

#### 1. Push Notifications System
**Why:** Users need instant alerts for messages and bids to stay engaged.

**Implementation:**
- Firebase Cloud Messaging (FCM) integration
- Cloud Functions triggers:
  - `onMessageCreated` → send FCM to recipient
  - `onBidCreated` → send FCM to job owner
  - `onBidAccepted` → send FCM to contractor
  - `onBidRejected` → send FCM to contractor (optional)
- Notification handling:
  - Deep linking to chat/bid screen
  - Notification badges on app icon
  - Custom notification sounds

**Files to Create:**
- `functions/src/index.ts` - Cloud Functions
- `lib/services/fcm_service.dart` - Update with notification handlers
- `android/app/src/main/AndroidManifest.xml` - FCM permissions
- `ios/Runner/AppDelegate.swift` - iOS notification setup

**Estimated Time:** 2-3 days
**Complexity:** Medium

---

#### 2. Review System
**Why:** Trust and reputation are essential for marketplace growth.

**Implementation:**
- Review submission after job completion
- Star rating (1-5) with comment
- Photo reviews (optional)
- Contractor response capability
- Display reviews on contractor profiles
- Average rating calculation
- Review sorting/filtering (recent, highest, lowest)
- Verified completion badge

**Features:**
- Customer can only review after job marked complete
- One review per customer per job
- Contractor can respond once to each review
- Photos uploaded to Storage (`review_photos/`)
- Reviews immutable after 7 days (grace period for editing)

**Files to Create:**
- `lib/screens/submit_review_screen.dart` - Review form
- `lib/screens/reviews_list_screen.dart` - Display reviews
- `lib/widgets/review_card.dart` - Individual review widget
- `lib/widgets/rating_stars.dart` - Star rating display/input
- Update `lib/screens/contractor_profile_page.dart` - Show reviews
- Update Firestore rules for reviews (already added)

**Data Model (already created):**
```dart
class Review {
  String id;
  String jobId;
  String contractorId;
  String customerId;
  String customerName;
  double rating;  // 1.0 to 5.0
  String comment;
  List<String> photoUrls;
  DateTime createdAt;
  String? contractorResponse;
  DateTime? responseDate;
  bool verified;  // job was marked complete
}
```

**Estimated Time:** 3-4 days
**Complexity:** Medium

---

#### 3. Job Status Tracking
**Why:** Transparency and accountability throughout the service lifecycle.

**Implementation:**
- Status enum: `pending` → `accepted` → `in_progress` → `completed` → `reviewed`
- Status update UI (contractor marks progress)
- Customer approval checkpoint (mark job complete)
- Timeline/history view
- Progress photos (contractor uploads during work)
- Milestone tracking (optional sub-tasks with checkboxes)
- Status change notifications (via FCM)

**Features:**
- Contractors can update to `in_progress` after accepting
- Contractors can request `completed` status
- Customers approve completion → triggers payment release
- Progress photos stored in `job_progress/{jobId}/`
- Milestones stored in subcollection `job_requests/{jobId}/milestones`

**Files to Create:**
- `lib/screens/job_status_screen.dart` - Timeline view
- `lib/screens/progress_photos_screen.dart` - Upload/view progress photos
- `lib/widgets/milestone_tracker.dart` - Milestone checklist
- `lib/widgets/status_stepper.dart` - Visual status progression
- Update `lib/screens/job_detail_page.dart` - Add status display
- Cloud Function: `onJobCompleted` → notify customer/release escrow

**Data Structure:**
```dart
// Update job_requests
{
  status: 'in_progress',
  statusHistory: [
    {status: 'pending', timestamp: Timestamp, updatedBy: 'uid'},
    {status: 'accepted', timestamp: Timestamp, updatedBy: 'uid'},
    {status: 'in_progress', timestamp: Timestamp, updatedBy: 'uid'},
  ],
  progressPhotos: ['url1', 'url2'],
  completionRequested: Timestamp,
  completionApproved: Timestamp,
}

// Milestones subcollection
milestones/{milestoneId}
{
  title: 'Install pipes',
  description: 'Install all bathroom plumbing',
  completed: false,
  completedAt: Timestamp,
  order: 1,
}
```

**Estimated Time:** 2-3 days
**Complexity:** Medium

---

### ⚡ Medium Priority (Enhance professionalism)

#### 4. Portfolio Management
**Why:** Contractors need to showcase their work to win more bids.

**Implementation:**
- Portfolio upload screen (contractor only)
- Before/after photo pairs
- Project title, description, completion date
- Portfolio gallery on contractor profile
- Featured/pinned portfolio items
- Photo reordering with drag-and-drop
- Delete portfolio items

**Files to Create:**
- `lib/screens/portfolio_manager_screen.dart` - Upload/manage
- `lib/screens/add_portfolio_item_screen.dart` - Form
- `lib/widgets/portfolio_gallery.dart` - Display on profile
- `lib/widgets/portfolio_item_card.dart` - Individual item
- Update Firestore rules for portfolios (already added)

**Data Model:**
```dart
// portfolios/{contractorId}/items/{itemId}
{
  contractorId: 'uid',
  title: 'Bathroom Remodel',
  description: 'Complete renovation...',
  beforePhotoUrl: 'https://...',
  afterPhotoUrl: 'https://...',
  completedAt: Timestamp,
  featured: false,
  order: 1,
  createdAt: Timestamp,
}
```

**Estimated Time:** 2 days
**Complexity:** Low-Medium

---

#### 5. Enhanced Contractor Profiles
**Why:** Professionalism and trust-building.

**Implementation:**
- Certifications upload (PDF/images)
- Insurance information fields
- Background check badge (admin-controlled)
- Years in business
- Business hours (M-F 9-5, etc.)
- Service area map/radius
- Specializations/tags
- Company logo upload

**Files to Update:**
- `lib/screens/contractor_signup_page.dart` - Add fields
- `lib/screens/contractor_profile_page.dart` - Display info
- `lib/screens/edit_contractor_profile_screen.dart` (new) - Edit screen
- Update `contractors` collection schema

**Data Structure:**
```dart
// contractors/{uid}
{
  ...existing fields,
  certifications: [
    {name: 'Licensed Plumber', fileUrl: 'https://...', expiresAt: Timestamp}
  ],
  insurance: {
    provider: 'State Farm',
    policyNumber: '123456',
    expiresAt: Timestamp,
    verified: false,  // admin sets this
  },
  backgroundCheckVerified: false,  // admin only
  yearsInBusiness: 10,
  businessHours: {
    monday: {open: '09:00', close: '17:00'},
    tuesday: {open: '09:00', close: '17:00'},
    // ...
  },
  serviceRadius: 25,  // miles
  serviceCenter: GeoPoint(lat, lng),
  specializations: ['Plumbing', 'Heating', 'Cooling'],
  companyLogoUrl: 'https://...',
}
```

**Estimated Time:** 3-4 days
**Complexity:** Medium

---

### 🎯 Lower Priority (Nice-to-have)

#### 6. Booking & Scheduling System
**Why:** Streamlines appointment setting and reduces back-and-forth.

**Implementation:**
- Contractor availability calendar
- Time slot selection UI
- Appointment booking flow
- Email/SMS reminders (Cloud Functions + SendGrid/Twilio)
- Reschedule/cancel functionality
- Calendar sync (Google/Apple)
- Recurring appointments

**Files to Create:**
- `lib/screens/contractor_calendar_screen.dart` - Manage availability
- `lib/screens/booking_screen.dart` - Customer booking flow
- `lib/screens/appointments_list_screen.dart` - Upcoming appointments
- `lib/widgets/calendar_widget.dart` - Interactive calendar
- `lib/widgets/time_slot_picker.dart` - Select time slots
- Cloud Functions: `sendAppointmentReminder`, `sendRescheduledNotification`

**Third-party Dependencies:**
```yaml
table_calendar: ^3.0.9  # Calendar widget
timezone: ^0.9.2        # Timezone handling
```

**Data Structure:**
```dart
// availability/{contractorId}/slots/{slotId}
{
  date: '2024-12-15',
  startTime: '09:00',
  endTime: '10:00',
  booked: false,
  jobId: 'optional',
}

// appointments/{appointmentId}
{
  contractorId: 'uid',
  customerId: 'uid',
  jobId: 'job123',
  scheduledAt: Timestamp,
  duration: 60,  // minutes
  status: 'confirmed' | 'rescheduled' | 'cancelled' | 'completed',
  reminderSent: false,
  notes: 'Customer notes...',
}
```

**Estimated Time:** 5-7 days
**Complexity:** High

---

## Dependencies to Add (Phase 2)

```yaml
# pubspec.yaml additions

dependencies:
  # Push Notifications
  firebase_messaging: ^14.7.3
  flutter_local_notifications: ^16.1.0
  
  # Reviews (star rating)
  flutter_rating_bar: ^4.0.1
  
  # Calendars & Scheduling
  table_calendar: ^3.0.9
  timezone: ^0.9.2
  
  # Performance Monitoring
  firebase_performance: ^0.9.3
  firebase_crashlytics: ^3.4.8
  
  # PDF viewer (for certifications)
  flutter_pdfview: ^1.3.2
  
  # Maps (for service area)
  google_maps_flutter: ^2.5.0
```

---

## Cloud Functions to Create

### notifications.ts
```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Send FCM when new message created
export const onMessageCreated = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const conversationId = context.params.conversationId;
    
    // Get conversation to find recipient
    const conversationSnap = await admin.firestore()
      .collection('conversations')
      .doc(conversationId)
      .get();
    
    const conversation = conversationSnap.data();
    const recipientId = conversation.participantIds.find(
      (id: string) => id !== message.senderId
    );
    
    // Get recipient FCM token
    const userSnap = await admin.firestore()
      .collection('users')
      .doc(recipientId)
      .get();
    
    const fcmToken = userSnap.data()?.fcmToken;
    if (!fcmToken) return;
    
    // Send notification
    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: message.senderName,
        body: message.text || '📷 Photo',
      },
      data: {
        type: 'message',
        conversationId: conversationId,
      },
    });
  });

// Send FCM when new bid created
export const onBidCreated = functions.firestore
  .document('bids/{bidId}')
  .onCreate(async (snap, context) => {
    const bid = snap.data();
    
    // Get customer FCM token
    const customerSnap = await admin.firestore()
      .collection('users')
      .doc(bid.customerId)
      .get();
    
    const fcmToken = customerSnap.data()?.fcmToken;
    if (!fcmToken) return;
    
    // Send notification
    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: 'New Bid Received',
        body: `${bid.contractorName} submitted a bid of $${bid.amount}`,
      },
      data: {
        type: 'bid',
        jobId: bid.jobId,
        bidId: context.params.bidId,
      },
    });
  });

// Send FCM when bid accepted
export const onBidAccepted = functions.firestore
  .document('bids/{bidId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Only if status changed to accepted
    if (before.status !== 'accepted' && after.status === 'accepted') {
      // Get contractor FCM token
      const contractorSnap = await admin.firestore()
        .collection('users')
        .doc(after.contractorId)
        .get();
      
      const fcmToken = contractorSnap.data()?.fcmToken;
      if (!fcmToken) return;
      
      // Send notification
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: 'Bid Accepted! 🎉',
          body: `Your bid of $${after.amount} was accepted`,
        },
        data: {
          type: 'bid_accepted',
          jobId: after.jobId,
          bidId: context.params.bidId,
        },
      });
    }
  });
```

---

## Testing Strategy for Phase 2

### Unit Tests
- Test FCM token registration/updates
- Test review submission validation
- Test rating calculations (average, count)
- Test status transitions (state machine)
- Test calendar availability logic

### Integration Tests
- Test notification delivery end-to-end
- Test review creation → display on profile
- Test job status updates → UI changes
- Test portfolio upload → display
- Test booking flow → calendar update

### Manual Testing
- Test notifications on real devices (Android + iOS)
- Test review photos upload/display
- Test multiple status transitions
- Test calendar across time zones
- Test permissions (camera, storage, notifications)

---

## Performance Considerations

### Optimization Opportunities
1. **Pagination**: Implement for reviews, messages, portfolio items
2. **Caching**: Use local storage for frequently accessed data
3. **Image thumbnails**: Generate thumbnails for portfolio/review photos
4. **Lazy loading**: Load portfolio items on scroll
5. **Debouncing**: Calendar availability queries

### Monitoring Metrics
- FCM delivery rate (> 95%)
- Review submission time (< 3 seconds)
- Image upload time (< 5 seconds)
- Calendar load time (< 2 seconds)
- App startup time (< 3 seconds)

---

## Risk Assessment

### High Risk
- **FCM setup complexity**: iOS requires APNs certificate, testing on real devices
- **Timezone handling**: Calendar/scheduling bugs with different timezones
- **Escrow release automation**: Money handling requires thorough testing

### Medium Risk
- **Review spam**: Need moderation tools (admin panel)
- **Storage costs**: Many portfolio/review photos (implement compression)
- **Notification spam**: Users may disable if too frequent

### Low Risk
- **Portfolio upload**: Similar to existing photo upload
- **Status tracking**: Simple state machine
- **Profile enhancements**: UI-only changes

---

## Success Metrics (Phase 2 Goals)

- 📱 **FCM opt-in rate**: > 80%
- ⭐ **Average contractor rating**: > 4.0
- 📸 **Portfolio upload rate**: > 50% of contractors
- ✅ **Job completion rate**: > 85%
- 📅 **Booking usage**: > 30% of jobs use scheduling
- 🔔 **Notification engagement**: > 60% open rate

---

## Rollout Strategy

### Week 1: Push Notifications
- Implement FCM
- Test on Android
- Test on iOS
- Deploy Cloud Functions
- Monitor delivery rates

### Week 2: Reviews + Job Tracking
- Implement review system
- Add status tracking
- Test end-to-end workflows
- Deploy to beta testers

### Week 3: Portfolios + Enhanced Profiles
- Build portfolio manager
- Add certification uploads
- Test with contractors
- Gather feedback

### Week 4: Scheduling (optional)
- Implement calendar
- Add booking flow
- Test timezone handling
- Beta test with select contractors

### Week 5: Polish + Deploy
- Bug fixes
- Performance optimization
- Final testing
- Production deployment

---

## Questions to Resolve

1. **FCM**: What notification frequency is acceptable? Daily digest vs instant?
2. **Reviews**: Allow editing? Time limit? Moderation workflow?
3. **Status**: Automatic transitions (e.g., auto-complete after 30 days)?
4. **Portfolios**: Limit number of items? Featured item selection?
5. **Scheduling**: Required or optional? Integrate with external calendars?
6. **Payments**: Auto-release escrow on completion approval?

---

## Resources Needed

- **Firebase Functions**: Node.js runtime (free tier: 2M invocations/month)
- **SendGrid/Twilio**: Email/SMS (pay-as-you-go, ~ $0.01 per message)
- **APNs Certificate**: For iOS push notifications (Apple Developer account)
- **Testing Devices**: Real Android + iOS devices for notifications
- **Beta Testers**: 10-20 users for Phase 2 testing

---

## Next Action Steps

1. ✅ Complete Phase 1 deployment
2. ⬜ Gather user feedback on Phase 1 features
3. ⬜ Prioritize Phase 2 features based on feedback
4. ⬜ Set up Cloud Functions project
5. ⬜ Implement FCM (highest priority)
6. ⬜ Begin review system implementation
7. ⬜ Continue iterating based on metrics

---

Last updated: December 2024
