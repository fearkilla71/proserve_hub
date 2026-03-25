/**
 * Seed script: Populate a contractor account with reviews, reputation data,
 * and featured status so it appears as a top recommended contractor.
 *
 * Usage:
 *   cd functions
 *   node seed_contractor.js <CONTRACTOR_UID>
 *
 * Example:
 *   node seed_contractor.js AbC123xYz
 *
 * This writes directly via Firebase Admin (bypasses Firestore rules).
 * Uses Application Default Credentials or GOOGLE_APPLICATION_CREDENTIALS.
 */

const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'proserve-hub-ada0e' });

const db = admin.firestore();

// ─── Configuration ───────────────────────────────────────────────────────────

const COMPANY_NAME = 'VeroHue Pro Painting';
const CONTRACTOR_NAME = 'Carvic Franco';
const HOUSTON_LAT = 29.8168;
const HOUSTON_LNG = -95.3421;
const SERVICE_RADIUS = 50; // miles

const SERVICES = [
  'Interior Painting',
  'Exterior Painting',
  'Cabinet Refinishing',
  'Pressure Washing',
  'Drywall Repair',
];

// Realistic fake customer names & reviews for painting work
const REVIEWS = [
  {
    customerName: 'Maria G.',
    rating: 5,
    qualityRating: 5,
    timelinessRating: 5,
    communicationRating: 5,
    comment:
      'Outstanding work on our living room and kitchen repaint. Carvic was professional, on time, and the finish is flawless. Highly recommend!',
    daysAgo: 8,
  },
  {
    customerName: 'James T.',
    rating: 5,
    qualityRating: 5,
    timelinessRating: 5,
    communicationRating: 5,
    comment:
      'Best painter in Houston hands down. He repainted our entire exterior and it looks brand new. Fair pricing and incredible attention to detail.',
    daysAgo: 15,
  },
  {
    customerName: 'Sarah W.',
    rating: 5,
    qualityRating: 5,
    timelinessRating: 4,
    communicationRating: 5,
    comment:
      'Did a full interior repaint for our 3-bedroom home. Clean, efficient, and the color matching was perfect. Will hire again.',
    daysAgo: 22,
  },
  {
    customerName: 'Robert M.',
    rating: 4,
    qualityRating: 5,
    timelinessRating: 4,
    communicationRating: 4,
    comment:
      'Great quality paint job on our master bedroom and bathroom. Showed up on time and finished ahead of schedule.',
    daysAgo: 30,
  },
  {
    customerName: 'Linda P.',
    rating: 5,
    qualityRating: 5,
    timelinessRating: 5,
    communicationRating: 5,
    comment:
      'Carvic and his team transformed our kitchen cabinets. The refinishing work is absolutely gorgeous. Very pleased with the results!',
    daysAgo: 38,
  },
  {
    customerName: 'David H.',
    rating: 5,
    qualityRating: 5,
    timelinessRating: 5,
    communicationRating: 5,
    comment:
      'Hired for pressure washing and exterior painting. The house looks like we just moved in. Super professional crew.',
    daysAgo: 45,
  },
  {
    customerName: 'Jennifer K.',
    rating: 5,
    qualityRating: 5,
    timelinessRating: 5,
    communicationRating: 4,
    comment:
      'Amazing attention to detail on our accent wall and trim work. Clean workspace and fair quote. Would definitely recommend to friends.',
    daysAgo: 52,
  },
  {
    customerName: 'Michael R.',
    rating: 4,
    qualityRating: 4,
    timelinessRating: 5,
    communicationRating: 5,
    comment:
      'Solid work on our garage and fence painting. Good communication throughout the project. Reasonable pricing for the quality.',
    daysAgo: 60,
  },
  {
    customerName: 'Ashley N.',
    rating: 5,
    qualityRating: 5,
    timelinessRating: 5,
    communicationRating: 5,
    comment:
      'We had drywall damage repaired and the whole room repainted. You cannot tell where the repair was — seamless job. 10/10!',
    daysAgo: 68,
  },
  {
    customerName: 'Carlos V.',
    rating: 5,
    qualityRating: 5,
    timelinessRating: 4,
    communicationRating: 5,
    comment:
      'Repainted our office space over the weekend so we had zero downtime. Professional, fast, and the quality speaks for itself.',
    daysAgo: 75,
  },
  {
    customerName: 'Emily S.',
    rating: 5,
    qualityRating: 5,
    timelinessRating: 5,
    communicationRating: 5,
    comment:
      'Third time hiring Carvic. He painted our nursery with zero-VOC paint and it turned out beautiful. Always my go-to painter in Houston.',
    daysAgo: 90,
  },
  {
    customerName: 'Brandon L.',
    rating: 4,
    qualityRating: 5,
    timelinessRating: 4,
    communicationRating: 4,
    comment:
      'Exterior repaint with Sherwin-Williams Duration. Looks fantastic and should hold up great. Good value for the money.',
    daysAgo: 105,
  },
];

// ─── Seed Logic ──────────────────────────────────────────────────────────────

async function seedContractor(contractorId) {
  console.log(`\nSeeding contractor: ${contractorId}\n`);

  // 1) Create fake job_request docs and review docs
  const batch = db.batch();
  let reviewCount = 0;
  let ratingSum = 0;

  for (const r of REVIEWS) {
    // Create a minimal job_request doc so the review has a valid reference
    const fakeJobId = `seed_job_${contractorId}_${reviewCount}`;
    const fakeCustomerId = `seed_customer_${reviewCount}`;
    const createdAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - r.daysAgo * 86400000)
    );

    const jobRef = db.collection('job_requests').doc(fakeJobId);
    batch.set(jobRef, {
      service: 'Interior Painting',
      status: 'completed',
      contractorId,
      requesterUid: fakeCustomerId,
      zip: '77093',
      lat: HOUSTON_LAT + (Math.random() - 0.5) * 0.05,
      lng: HOUSTON_LNG + (Math.random() - 0.5) * 0.05,
      claimed: true,
      createdAt,
      completedAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - (r.daysAgo - 2) * 86400000)
      ),
      _seeded: true,
    });

    // Review with deterministic ID: <jobId>_<customerId>
    const reviewId = `${fakeJobId}_${fakeCustomerId}`;
    const reviewRef = db.collection('reviews').doc(reviewId);
    batch.set(reviewRef, {
      jobId: fakeJobId,
      contractorId,
      customerId: fakeCustomerId,
      reviewerName: r.customerName,
      rating: r.rating,
      qualityRating: r.qualityRating,
      timelinessRating: r.timelinessRating,
      communicationRating: r.communicationRating,
      comment: r.comment,
      createdAt,
    });

    ratingSum += r.rating;
    reviewCount++;
    console.log(`  ✓ Review by ${r.customerName} — ${r.rating}★`);
  }

  await batch.commit();
  console.log(`\n✓ Created ${reviewCount} reviews + job_request stubs\n`);

  // 2) Update contractor document with strong metrics
  const avgRating = ratingSum / reviewCount;
  const contractorRef = db.collection('contractors').doc(contractorId);

  await contractorRef.set(
    {
      name: COMPANY_NAME,
      contractorName: CONTRACTOR_NAME,
      services: SERVICES,
      servicesOffered: SERVICES,
      verified: true,
      available: true,
      featured: true,
      lat: HOUSTON_LAT,
      lng: HOUSTON_LNG,
      zip: '77093',
      radius: SERVICE_RADIUS,
      rating: Math.round(avgRating * 10) / 10,
      averageRating: Math.round(avgRating * 10) / 10,
      reviewCount,
      totalReviews: reviewCount,
      completedJobs: reviewCount + 3, // a few extra completed without review
      avgResponseMinutes: 12,
      availabilityWindow: 'today',
      stripePayoutsEnabled: true,
      reputation: {
        reliabilityScore: 4.8,
        completionRate: 96,
        avgResponseTimeMinutes: 12,
        repeatCustomerRate: 25,
        totalJobsCompleted: reviewCount + 3,
        topProBadge: true,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      },
      _seeded: true,
    },
    { merge: true }
  );

  console.log('✓ Updated contractor doc with metrics + featured flag');
  console.log(`  Rating: ${avgRating.toFixed(1)}★ (${reviewCount} reviews)`);
  console.log(`  Featured: true`);
  console.log(`  Top Pro Badge: true`);
  console.log(`  Services: ${SERVICES.join(', ')}`);
  console.log(`  Location: Houston (77006), radius ${SERVICE_RADIUS} mi`);
  console.log('\n✅ Seed complete!\n');
}

// ─── CLI Entry ───────────────────────────────────────────────────────────────

const uid = process.argv[2];
if (!uid) {
  console.error('Usage: node seed_contractor.js <CONTRACTOR_UID>');
  console.error('\nTo find your UID, open the app → Profile → scroll to bottom,');
  console.error('or check Firebase Console → Authentication → Users.');
  process.exit(1);
}

seedContractor(uid)
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Seed failed:', err);
    process.exit(1);
  });
