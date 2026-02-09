# Contractor Reputation Engine

## Overview
A comprehensive reputation system that goes beyond simple star ratings to provide multi-dimensional insights into contractor performance and reliability.

## Metrics Tracked

### 1. Reliability Score (0-5 scale)
Composite metric calculated from:
- **Completion Rate** (40% weight): Percentage of accepted jobs successfully completed
- **Response Time** (30% weight): Average time to respond to job requests/quotes
- **Repeat Customer Rate** (30% weight): Percentage of customers who hire the contractor multiple times
- **Experience Multiplier**: Bonus based on total completed jobs (up to 20% boost)

**Score Levels:**
- 4.5-5.0: Excellent (Green)
- 3.5-4.4: Good (Light Green)
- 2.5-3.4: Fair (Orange)
- 0-2.4: Needs Improvement (Red)

### 2. Completion Rate
- Calculated as: (Completed Jobs / Total Accepted Jobs) × 100
- Tracks contractor's ability to finish what they start
- Updated on job completion

### 3. Average Response Time
- Measured in minutes from job posting to quote submission
- Based on last 50 quotes for performance
- Color-coded:
  - Green: ≤60 minutes
  - Orange: 61-240 minutes
  - Red: >240 minutes

### 4. Repeat Customer Rate
- Percentage of customers who hired the contractor more than once
- Calculated as: (Customers with 2+ jobs / Total unique customers) × 100
- Indicates customer satisfaction and trust

### 5. Total Jobs Completed
- Simple count of successfully completed jobs
- Provides context for other metrics

### 6. Top Pro Badge 🌟
Elite designation awarded when contractor meets ALL criteria:
- Reliability Score ≥ 4.5
- Completion Rate ≥ 90%
- Total Completed Jobs ≥ 10
- Average Response Time ≤ 120 minutes

## UI Components

### Full Reputation Card
Displayed on contractor profile pages:
- Large reliability score with progress bar
- Grid layout of all metrics
- Top Pro badge (if earned)
- Tooltips explaining each metric

### Compact Reputation Display
Shown in contractor cards/search results:
- Reliability score + icon
- Completion rate
- Top Pro badge (if earned)

## Backend Functions

### Automatic Updates
1. **`updateReputationOnJobComplete`**
   - Trigger: Job status changes to 'completed'
   - Recalculates all metrics for the contractor

2. **`updateReputationOnQuoteAccept`**
   - Trigger: Quote status changes to 'accepted'
   - Updates response time metrics

3. **`recalculateAllReputations`**
   - Scheduled: Every 24 hours
   - Recalculates reputation for all contractors

### Manual Calculation
- **`recalculateReputationHttp`**: Admin endpoint for manual recalculation
  ```
  POST /recalculateReputationHttp
  Body: { "contractorId": "contractor123" }
  ```

## Data Structure

### Firestore Schema
Stored in `contractors/{contractorId}`:
```javascript
{
  reputation: {
    reliabilityScore: 4.7,           // 0-5 scale
    completionRate: 95.2,             // percentage
    avgResponseTimeMinutes: 45,       // minutes
    repeatCustomerRate: 38.5,         // percentage
    totalJobsCompleted: 42,           // count
    topProBadge: true,                // boolean
    lastUpdated: Timestamp            // server timestamp
  }
}
```

## Required Firestore Indexes
Add these to `firestore.indexes.json`:
```json
{
  "collectionGroup": "job_requests",
  "fields": [
    { "fieldPath": "contractorId", "order": "ASCENDING" },
    { "fieldPath": "claimed", "order": "ASCENDING" }
  ]
},
{
  "collectionGroup": "job_requests",
  "fields": [
    { "fieldPath": "contractorId", "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" }
  ]
},
{
  "collectionGroup": "quotes",
  "fields": [
    { "fieldPath": "contractorId", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
}
```

## Deployment

### 1. Deploy Cloud Functions
```bash
cd functions
npm install
firebase deploy --only functions:updateReputationOnJobComplete,functions:updateReputationOnQuoteAccept,functions:recalculateAllReputations,functions:recalculateReputationHttp
```

### 2. Deploy Firestore Indexes
```bash
firebase deploy --only firestore:indexes
```

### 3. Initial Population
Run for existing contractors:
```bash
# Using Firebase CLI or Cloud Console
# Call recalculateReputationHttp for each contractor
```

## Usage Examples

### Display in Flutter
```dart
// Full card on profile
ContractorReputationCard(
  reputationData: contractorData['reputation'] ?? {},
)

// Compact view in search results
ContractorReputationCard(
  reputationData: contractorData['reputation'] ?? {},
  compact: true,
)
```

### Query Top Contractors
```dart
// Find Top Pro contractors
FirebaseFirestore.instance
  .collection('contractors')
  .where('reputation.topProBadge', isEqualTo: true)
  .orderBy('reputation.reliabilityScore', descending: true)
  .limit(10)
  .get();
```

## Performance Considerations

- Response time calculation limited to last 50 quotes
- Calculations cached in contractor document (not real-time)
- Daily batch recalculation prevents stale data
- Metrics update on key events (job completion, quote acceptance)

## Future Enhancements

1. **Additional Metrics**:
   - On-time completion rate
   - Budget adherence
   - Communication responsiveness
   - Quality rating from reviews

2. **Badges**:
   - Specialist badges (by service type)
   - Verified pro (background check)
   - Rising star (fast-growing reputation)

3. **Reputation Trends**:
   - 30-day/90-day trend graphs
   - Seasonal performance analysis

4. **Customer Insights**:
   - Show reputation breakdown to customers before hiring
   - Compare contractors side-by-side

## Testing

### Manual Test Checklist
- [ ] Create test contractor with various job statuses
- [ ] Verify completion rate calculation
- [ ] Test response time tracking on quote submission
- [ ] Confirm repeat customer detection
- [ ] Validate Top Pro badge logic
- [ ] Check UI display in profile page
- [ ] Check UI display in search results
- [ ] Test manual recalculation endpoint

### Test Data Creation
```javascript
// Create test jobs for contractor
const testData = {
  contractorId: 'test_contractor_123',
  jobs: [
    { status: 'completed', claimed: true },  // 5 completed
    { status: 'completed', claimed: true },
    { status: 'completed', claimed: true },
    { status: 'completed', claimed: true },
    { status: 'completed', claimed: true },
    { status: 'cancelled', claimed: true },  // 1 not completed
  ],
  quotes: [
    { createdAt: jobTime + 30min },  // Fast response
    { createdAt: jobTime + 45min },
  ]
};
```

## Impact
- **High-quality contractors**: Incentivized to maintain excellent performance
- **Customer confidence**: Data-driven hiring decisions
- **Platform quality**: Naturally promotes reliable contractors
- **Retention**: Top Pros gain visibility and repeat business
