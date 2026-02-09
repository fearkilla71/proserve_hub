# ProServe Hub - Phase 1 Features

## Overview
ProServe Hub now includes comprehensive marketplace features enabling seamless communication, competitive bidding, and professional service delivery between customers and contractors.

## New Features

### 1. Messaging System ✅
Real-time in-app chat between customers and contractors with advanced features:

**Features:**
- **Real-time messaging**: Instant message delivery using Firestore streams
- **Photo sharing**: Upload and share images directly in chat
- **Read receipts**: Visual indicators showing message delivery and read status
  - Single check (✓): Message sent
  - Double check (✓✓): Message delivered
  - Blue checks: Message read by recipient
- **Unread counters**: Badge indicators showing unread message counts
- **Conversation list**: Centralized view of all active chats
- **Message timestamps**: "Today", "Yesterday", or date-based display
- **Auto-scrolling**: Automatically scrolls to latest messages

**How to Use:**
- **Customer**: Click Messages icon in portal → Start conversation from job detail page
- **Contractor**: Click Messages icon in portal → Reply to customer messages
- Access conversations from the message icon in the app bar

**Technical Details:**
- Collections: `conversations`, `conversations/{id}/messages`
- Models: `Message`, `Conversation` classes
- Service: `ConversationService` with helper methods
- Security: Only conversation participants can read/write messages

---

### 2. Bidding System ✅
Competitive bidding marketplace allowing multiple contractors to submit quotes:

**Features:**
- **Multiple bids per job**: Contractors can submit detailed proposals
- **Bid comparison**: Customers see all bids side-by-side
- **Counter-offers**: Both parties can negotiate pricing
- **Bid expiration**: Automatic 7-day expiration on bids
- **Status tracking**: Pending → Accepted/Rejected/Countered
- **Automatic job claiming**: Accepting a bid automatically claims the job

**Bid Components:**
- **Amount**: Quoted price in USD
- **Estimated days**: Project timeline
- **Description**: Detailed proposal (min 20 characters)
- **Contractor info**: Name and profile
- **Status indicator**: Color-coded chips (blue=pending, green=accepted, red=rejected, orange=countered)

**Workflow:**
1. **Contractor**: Browse unclaimed jobs → Submit bid with quote and timeline
2. **Customer**: View all bids → Compare proposals → Accept/Reject/Counter
3. **Negotiation**: Counter-offer creates new bid linked to original
4. **Acceptance**: Accepting bid automatically:
   - Marks bid as accepted
   - Rejects other pending bids
   - Claims job for contractor
   - Updates job with acceptedBidId

**Technical Details:**
- Collection: `bids`
- Model: `Bid` class with status tracking
- Screens: `BidsListScreen`, `SubmitBidScreen`
- Validation: Amount > 0, days > 0, description >= 20 chars

---

### 3. Enhanced User Experience ✅
Improved app polish and user onboarding:

**Onboarding Tutorial:**
- 4-page interactive tutorial for new users
- Topics: Smart matching, AI estimates, secure payments, easy management
- Skip option or complete walkthrough
- Shows once per installation

**Profile Completion Tracker:**
- Progress bar showing % completion
- Missing field indicators (up to 3 shown)
- Auto-hides when 100% complete
- Tracks 5 common fields + 5 contractor-specific fields
- Displays on both customer and contractor portals

**Image Optimization:**
- Automatic compression for images > 1MB
- Resizes to max 1920x1920 pixels
- 85% quality JPEG compression
- Significantly reduces upload times and storage costs

**Offline Detection:**
- Red banner appears when internet disconnected
- Auto-dismisses when connection restored
- Prevents user frustration with failed operations

**Smooth Animations:**
- Cupertino-style page transitions
- Swipe-to-go-back gestures
- Native iOS-like feel across platforms

---

## Firestore Structure

### Conversations Collection
```
conversations/{conversationId}
├── participantIds: [uid1, uid2] (array, sorted)
├── participantNames: {uid1: "Name1", uid2: "Name2"}
├── jobId: "job123" (optional, links to job)
├── lastMessage: "Hello..." (preview text)
├── lastMessageTime: Timestamp
└── unreadCount: {uid1: 0, uid2: 5}

  messages/{messageId}
  ├── senderId: "uid1"
  ├── senderName: "John Doe"
  ├── text: "Message content"
  ├── imageUrl: "https://..." (optional)
  ├── timestamp: Timestamp
  ├── isRead: false
  └── readBy: {uid1: true, uid2: false}
```

### Bids Collection
```
bids/{bidId}
├── jobId: "job123"
├── contractorId: "uid1"
├── contractorName: "ABC Plumbing"
├── customerId: "uid2"
├── amount: 500.00
├── currency: "USD"
├── description: "Detailed proposal..."
├── estimatedDays: 3
├── status: "pending" | "accepted" | "rejected" | "countered"
├── createdAt: Timestamp
├── expiresAt: Timestamp (createdAt + 7 days)
└── counterOfferId: "bid456" (optional, links to counter-offer)
```

---

## Security Rules

### Conversations
```javascript
match /conversations/{conversationId} {
  allow read, write: if request.auth != null && 
    request.auth.uid in resource.data.participantIds;
  
  match /messages/{messageId} {
    allow read, write: if request.auth != null && 
      request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds;
  }
}
```

### Bids
```javascript
match /bids/{bidId} {
  allow read: if request.auth != null && (
    request.auth.uid == resource.data.contractorId ||
    request.auth.uid == resource.data.customerId ||
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin'
  );
  
  allow create: if request.auth != null && isContractor();
  
  allow update: if request.auth != null && (
    request.auth.uid == resource.data.contractorId ||
    request.auth.uid == resource.data.customerId
  );
}
```

---

## Navigation

### Customer Portal
- **Messages icon** (top-right) → Conversations list
- **Job detail** → "View Bids" button → All bids for that job
- **Job detail** → "Message Contractor" → Chat screen

### Contractor Portal
- **Messages icon** (top-right) → Conversations list
- **Job detail** → "Submit Bid" button → Bid submission form
- **Job detail** → "Message Client" → Chat screen

---

## Testing Checklist

### Messaging
- [ ] Create new conversation from job detail
- [ ] Send text messages
- [ ] Upload and send photos
- [ ] Verify read receipts update
- [ ] Check unread counts in conversation list
- [ ] Test real-time message updates

### Bidding
- [ ] Contractor submits bid on unclaimed job
- [ ] Customer views all bids for a job
- [ ] Customer accepts bid → job claimed automatically
- [ ] Customer rejects bid
- [ ] Customer counters bid → new bid created
- [ ] Verify bid expiration (7 days)
- [ ] Test bid validation (amount, days, description)

### UX Polish
- [ ] Onboarding shows on first launch
- [ ] Profile completion card displays missing fields
- [ ] Images > 1MB are automatically compressed
- [ ] Offline banner appears when disconnected
- [ ] Page transitions are smooth

---

## Upcoming Features (Phase 2)

### Review System
- Star ratings (1-5)
- Written reviews with photos
- Contractor responses
- Verified completion badges
- Review sorting/filtering

### Job Tracking
- Status pipeline: Pending → In Progress → Completed
- Milestone tracking
- Progress photos from contractor
- Customer approval checkpoints

### Portfolio Management
- Before/after photo galleries
- Project showcases for contractors
- Certification uploads
- Insurance verification

### Booking & Scheduling
- Contractor availability calendar
- Time slot selection
- Appointment booking
- SMS/email reminders
- Reschedule/cancel functionality

---

## Dependencies Added

```yaml
dependencies:
  shared_preferences: ^2.5.4      # Onboarding state
  image_picker: ^1.2.1            # Photo uploads
  flutter_image_compress: ^2.3.0  # Image optimization
  connectivity_plus: ^7.0.0       # Offline detection
```

---

## API Reference

### ConversationService

#### getOrCreateConversation
```dart
Future<String> getOrCreateConversation({
  required String otherUserId,
  required String otherUserName,
  String? jobId,
})
```
Gets existing conversation or creates new one. Returns conversation ID.

#### sendMessage
```dart
Future<void> sendMessage({
  required String conversationId,
  required String text,
  String? imageUrl,
})
```
Sends a message in a conversation. Updates metadata and unread counts.

#### markAsRead
```dart
Future<void> markAsRead(String conversationId)
```
Marks all messages as read for current user.

---

## Known Limitations

1. **Push Notifications**: Not yet implemented. Users must check app for new messages/bids.
2. **Bid Edits**: Once submitted, bids cannot be edited (must counter-offer instead).
3. **Message Search**: No search functionality within conversations yet.
4. **File Attachments**: Only images supported, no PDFs or documents.
5. **Bulk Actions**: Cannot reject/accept multiple bids at once.

---

## Troubleshooting

### Messages not appearing
- Check Firestore rules are deployed: `firebase deploy --only firestore:rules`
- Verify user is authenticated
- Check participantIds array in conversation document

### Bids not showing
- Confirm job is not claimed (contractors can only bid on unclaimed jobs)
- Verify contractor has completed profile
- Check bid collection permissions

### Images not uploading
- Verify Firebase Storage rules allow authenticated writes
- Check network connection
- Ensure image picker permissions granted

### Profile completion not updating
- Force close and reopen app
- Check users collection and contractors collection for data
- Verify Firestore security rules

---

## Support

For issues or questions:
1. Check Firestore console for data
2. Review device logs for errors
3. Verify authentication state
4. Confirm Firestore rules deployed

---

## Version History

### v1.1.0 (Current)
- ✅ Real-time messaging with photo sharing
- ✅ Competitive bidding system
- ✅ Onboarding tutorial
- ✅ Profile completion tracker
- ✅ Image compression
- ✅ Offline detection
- ✅ Smooth page transitions

### v1.0.0
- AI photo estimates
- Smart contractor matching
- Stripe escrow integration
- Basic job flow
