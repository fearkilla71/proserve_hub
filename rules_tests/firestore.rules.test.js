const fs = require('fs');
const path = require('path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  documentId,
  doc,
  getDoc,
  getDocs,
  limit,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  deleteDoc,
  where,
} = require('firebase/firestore');

const PROJECT_ID = 'demo-proserve-hub-rules';

describe('Firestore user security rules', () => {
  let testEnv;

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
        host: '127.0.0.1',
        port: 8080,
      },
    });
  });

  after(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  function db(uid) {
    return testEnv.authenticatedContext(uid).firestore();
  }

  async function seed(pathSegments, data) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), ...pathSegments), data);
    });
  }

  it('allows a user to create a safe profile document', async () => {
    await assertSucceeds(setDoc(doc(db('userA'), 'users/userA'), {
      uid: 'userA',
      displayName: 'User A',
      email: 'user@example.com',
      createdAt: new Date(),
    }));
  });

  it('blocks user-created privilege, credit, subscription, and payout fields', async () => {
    const protectedFields = [
      { role: 'admin' },
      { admin: true },
      { credits: 100 },
      { leadCredits: 100 },
      { exclusiveLeadCredits: 100 },
      { stripeAccountId: 'acct_bad' },
      { stripeSubscriptionId: 'sub_bad' },
      { subscriptionTier: 'enterprise' },
      { contractorPro: true },
      { isPro: true },
      { pricingToolsPro: true },
      { avgRating: 5 },
      { verified: true },
      { marketStatus: 'active' },
      { launchRegion: 'houston_metro' },
      { waitlistJoinedAt: new Date() },
    ];

    for (let i = 0; i < protectedFields.length; i += 1) {
      await assertFails(setDoc(doc(db(`user${i}`), `users/user${i}`), {
        uid: `user${i}`,
        displayName: 'User',
        ...protectedFields[i],
      }));
    }
  });

  it('blocks users from updating protected server-owned fields', async () => {
    await seed(['users', 'userA'], {
      uid: 'userA',
      displayName: 'User A',
      role: 'contractor',
      credits: 0,
      contractorPro: false,
    });

    await assertSucceeds(updateDoc(doc(db('userA'), 'users/userA'), {
      displayName: 'New Name',
    }));
    await assertFails(updateDoc(doc(db('userA'), 'users/userA'), {
      role: 'admin',
    }));
    await assertFails(updateDoc(doc(db('userA'), 'users/userA'), {
      credits: 99,
    }));
    await assertFails(updateDoc(doc(db('userA'), 'users/userA'), {
      contractorPro: true,
    }));
    await assertFails(updateDoc(doc(db('userA'), 'users/userA'), {
      marketStatus: 'active',
    }));
  });

  it('allows customers to create live jobs only in the Houston launch market', async () => {
    await seed(['users', 'customerA'], {
      uid: 'customerA',
      role: 'customer',
      marketStatus: 'active',
    });

    await assertSucceeds(setDoc(doc(db('customerA'), 'job_requests/houstonJob'), {
      requesterUid: 'customerA',
      service: 'Interior Painting',
      location: 'Houston, TX',
      zip: '77002',
      claimed: false,
      paidBy: [],
      createdAt: new Date(),
    }));

    await assertFails(setDoc(doc(db('customerA'), 'job_requests/austinJob'), {
      requesterUid: 'customerA',
      service: 'Interior Painting',
      location: 'Austin, TX',
      zip: '78701',
      claimed: false,
      paidBy: [],
      createdAt: new Date(),
    }));
  });

  it('blocks waitlisted customers from creating live jobs', async () => {
    await seed(['users', 'customerA'], {
      uid: 'customerA',
      role: 'customer',
      marketStatus: 'waitlist',
    });

    await assertFails(setDoc(doc(db('customerA'), 'job_requests/waitlistJob'), {
      requesterUid: 'customerA',
      service: 'Interior Painting',
      location: 'Houston, TX',
      zip: '77002',
      claimed: false,
      paidBy: [],
      createdAt: new Date(),
    }));
  });

  it('allows safe app waitlist entries with ZIP and service planning fields', async () => {
    await assertSucceeds(setDoc(doc(db('userA'), 'waitlist/entryA'), {
      uid: 'userA',
      name: 'User A',
      email: 'user@example.com',
      phone: '555-0100',
      role: 'customer',
      zip: '78701',
      service: 'Roofing',
      services: ['Roofing'],
      launchRegion: 'unsupported',
      marketStatus: 'waitlist',
      source: 'app_region_gate',
      createdAt: serverTimestamp(),
    }));
  });

  it('allows admins from /admins to manage user documents', async () => {
    await seed(['admins', 'adminA'], { role: 'super_admin' });
    await seed(['users', 'userA'], { uid: 'userA', displayName: 'User A' });

    await assertSucceeds(getDoc(doc(db('adminA'), 'users/userA')));
    await assertSucceeds(deleteDoc(doc(db('adminA'), 'users/userA')));
  });

  it('blocks non-admins from reading other user profiles', async () => {
    await seed(['users', 'userA'], { uid: 'userA', displayName: 'User A' });
    await assertFails(getDoc(doc(db('userB'), 'users/userA')));
  });

  it('allows contractors with lead credits to list open lead metadata', async () => {
    await seed(['users', 'contractorA'], {
      uid: 'contractorA',
      role: 'contractor',
      leadCredits: 1,
    });
    await seed(['job_requests', 'openJobA'], {
      requesterUid: 'customerA',
      service: 'Interior Painting',
      location: 'Houston, TX',
      claimed: false,
      leadUnlockedBy: null,
      paidBy: [],
      createdAt: new Date(),
    });

    await assertSucceeds(getDocs(query(
      collection(db('contractorA'), 'job_requests'),
      where('claimed', '==', false),
      where('leadUnlockedBy', '==', null),
      limit(10),
    )));
  });

  it('blocks contractors without credits from listing the open lead feed', async () => {
    await seed(['users', 'contractorA'], {
      uid: 'contractorA',
      role: 'contractor',
      leadCredits: 0,
      exclusiveLeadCredits: 0,
    });
    await seed(['job_requests', 'openJobA'], {
      requesterUid: 'customerA',
      service: 'Interior Painting',
      location: 'Houston, TX',
      claimed: false,
      leadUnlockedBy: null,
      paidBy: [],
      createdAt: new Date(),
    });

    await assertFails(getDocs(query(
      collection(db('contractorA'), 'job_requests'),
      where('claimed', '==', false),
      where('leadUnlockedBy', '==', null),
      limit(10),
    )));
  });

  it('allows contractors to query leads they already unlocked with paidBy', async () => {
    await seed(['users', 'contractorA'], {
      uid: 'contractorA',
      role: 'contractor',
      leadCredits: 0,
    });
    await seed(['job_requests', 'paidJobA'], {
      requesterUid: 'customerA',
      service: 'Exterior Painting',
      location: 'Austin, TX',
      claimed: false,
      leadUnlockedBy: null,
      paidBy: ['contractorA'],
      createdAt: new Date(),
    });
    await seed(['job_requests', 'paidJobA', 'private', 'contact'], {
      requesterUid: 'customerA',
      name: 'Customer A',
      email: 'customer@example.com',
      phone: '555-0100',
    });

    await assertSucceeds(getDocs(query(
      collection(db('contractorA'), 'job_requests'),
      where('paidBy', 'array-contains', 'contractorA'),
      limit(10),
    )));
    await assertSucceeds(getDoc(doc(
      db('contractorA'),
      'job_requests/paidJobA/private/contact',
    )));
    await assertFails(getDoc(doc(
      db('contractorB'),
      'job_requests/paidJobA/private/contact',
    )));
  });

  it('allows contractors to read only their own lead credit activity', async () => {
    await seed(['users', 'contractorA'], {
      uid: 'contractorA',
      role: 'contractor',
    });
    await seed(['lead_credit_transactions', 'txnA'], {
      userId: 'contractorA',
      contractorId: 'contractorA',
      type: 'used',
      creditType: 'shared',
      delta: -1,
      jobId: 'jobA',
      createdAt: new Date(),
    });
    await seed(['lead_credit_transactions', 'txnB'], {
      userId: 'contractorB',
      contractorId: 'contractorB',
      type: 'purchased',
      creditType: 'exclusive',
      delta: 1,
      packId: 'ex_1',
      createdAt: new Date(),
    });

    await assertSucceeds(getDocs(query(
      collection(db('contractorA'), 'lead_credit_transactions'),
      where('userId', '==', 'contractorA'),
      limit(5),
    )));
    await assertFails(getDoc(doc(
      db('contractorA'),
      'lead_credit_transactions/txnB',
    )));
  });

  it('allows invited contractors to load invited jobs by document id', async () => {
    await seed(['users', 'contractorA'], {
      uid: 'contractorA',
      role: 'contractor',
      leadCredits: 0,
    });
    await seed(['job_requests', 'invitedJobA'], {
      requesterUid: 'customerA',
      service: 'Cabinet Painting',
      location: 'Dallas, TX',
      claimed: false,
      leadUnlockedBy: 'contractorB',
      paidBy: [],
      createdAt: new Date(),
    });
    await seed(['bid_invites', 'invitedJobA_contractorA'], {
      jobId: 'invitedJobA',
      contractorId: 'contractorA',
      customerId: 'customerA',
      status: 'pending',
      createdAt: new Date(),
    });

    await assertSucceeds(getDocs(query(
      collection(db('contractorA'), 'job_requests'),
      where(documentId(), 'in', ['invitedJobA']),
    )));
  });

  it('allows requester completion approval but blocks requester payment fields', async () => {
    await seed(['job_requests', 'jobToComplete'], {
      requesterUid: 'customerA',
      claimed: true,
      claimedBy: 'contractorA',
      service: 'Interior Painting',
      status: 'completion_requested',
      createdAt: new Date(),
    });

    await assertSucceeds(updateDoc(doc(db('customerA'), 'job_requests/jobToComplete'), {
      status: 'completed',
      completionApproved: new Date(),
      statusHistory: [{
        status: 'completed',
        timestamp: new Date(),
        updatedBy: 'customerA',
        approved: true,
      }],
    }));

    await assertFails(updateDoc(doc(db('customerA'), 'job_requests/jobToComplete'), {
      completedAt: new Date(),
    }));
    await assertFails(updateDoc(doc(db('customerA'), 'job_requests/jobToComplete'), {
      paymentIntentId: 'pi_spoofed',
    }));
  });

  it('enforces pro entitlement for invoice, render, and estimate tools', async () => {
    await seed(['users', 'contractorA'], {
      uid: 'contractorA',
      role: 'contractor',
      subscriptionTier: 'pro',
      contractorPro: true,
      pricingToolsPro: true,
    });
    await seed(['users', 'contractorB'], {
      uid: 'contractorB',
      role: 'contractor',
      subscriptionTier: 'basic',
      contractorPro: false,
      pricingToolsPro: false,
    });

    const proPaths = [
      'users/contractorA/invoice_drafts/draftA',
      'users/contractorA/invoices/invoiceA',
      'users/contractorA/invoices/invoiceA/payments/paymentA',
      'users/contractorA/render_history/renderA',
      'contractors/contractorA/saved_estimates/estimateA',
      'contractors/contractorA/cost_estimates/costA',
    ];

    for (const pathName of proPaths) {
      await assertSucceeds(setDoc(doc(db('contractorA'), pathName), {
        ownerId: 'contractorA',
        contractorId: 'contractorA',
        title: 'Pro tool artifact',
        createdAt: new Date(),
      }));
      await assertSucceeds(getDoc(doc(db('contractorA'), pathName)));
      await assertFails(getDoc(doc(db('contractorB'), pathName)));
    }

    await assertFails(setDoc(doc(db('contractorB'), 'users/contractorB/render_history/renderB'), {
      ownerId: 'contractorB',
      title: 'Blocked basic render',
      createdAt: new Date(),
    }));
    await assertFails(setDoc(doc(db('contractorB'), 'contractors/contractorB/saved_estimates/estimateB'), {
      contractorId: 'contractorB',
      title: 'Blocked basic estimate',
      createdAt: new Date(),
    }));
  });

  it('enforces enterprise entitlement for enterprise contractor tools', async () => {
    await seed(['users', 'contractorA'], {
      uid: 'contractorA',
      role: 'contractor',
      subscriptionTier: 'enterprise',
      contractorPro: true,
      pricingToolsPro: true,
    });
    await seed(['users', 'contractorB'], {
      uid: 'contractorB',
      role: 'contractor',
      subscriptionTier: 'pro',
      contractorPro: true,
      pricingToolsPro: true,
    });

    const enterprisePaths = [
      'users/contractorA/render_history/renderA',
      'users/contractorA/quality_reports/reportA',
      'users/contractorA/bid_analyses/analysisA',
      'users/contractorA/locations/locationA',
      'users/contractorA/job_pipeline/jobA',
      'users/contractorA/schedules/scheduleA',
      'users/contractorA/crews/crewA',
    ];

    for (const pathName of enterprisePaths) {
      await assertSucceeds(setDoc(doc(db('contractorA'), pathName), {
        ownerId: 'contractorA',
        title: 'Enterprise tool artifact',
        createdAt: new Date(),
      }));
      await assertSucceeds(getDoc(doc(db('contractorA'), pathName)));
      await assertFails(getDoc(doc(db('contractorB'), pathName)));
    }

    await assertFails(setDoc(doc(db('contractorB'), 'users/contractorB/bid_analyses/analysisB'), {
      ownerId: 'contractorB',
      title: 'Blocked pro bid analysis',
      createdAt: new Date(),
    }));
    await assertFails(setDoc(doc(db('contractorB'), 'users/contractorB/schedules/scheduleB'), {
      ownerId: 'contractorB',
      title: 'Blocked pro schedule',
      createdAt: new Date(),
    }));
  });

  it('protects sub marketplace listings and bids by poster and bidder', async () => {
    await assertSucceeds(setDoc(doc(db('posterA'), 'sub_marketplace/listingA'), {
      postedBy: 'posterA',
      title: 'Interior overflow job',
      status: 'open',
      bidCount: 0,
      createdAt: new Date(),
    }));
    await assertFails(setDoc(doc(db('posterB'), 'sub_marketplace/listingBad'), {
      postedBy: 'posterA',
      title: 'Spoofed listing',
      status: 'open',
      bidCount: 0,
    }));
    await assertSucceeds(getDocs(collection(db('bidderA'), 'sub_marketplace')));

    await assertFails(setDoc(doc(db('posterA'), 'sub_marketplace_bids/selfBid'), {
      listingId: 'listingA',
      bidderId: 'posterA',
      amount: 300,
      status: 'pending',
    }));
    await assertSucceeds(setDoc(doc(db('bidderA'), 'sub_marketplace_bids/bidA'), {
      listingId: 'listingA',
      bidderId: 'bidderA',
      amount: 300,
      status: 'pending',
      createdAt: new Date(),
    }));
    await assertSucceeds(updateDoc(doc(db('bidderA'), 'sub_marketplace/listingA'), {
      bidCount: 1,
    }));
    await assertSucceeds(updateDoc(doc(db('posterA'), 'sub_marketplace_bids/bidA'), {
      status: 'accepted',
    }));
    await assertFails(updateDoc(doc(db('contractorC'), 'sub_marketplace_bids/bidA'), {
      status: 'rejected',
    }));
  });

  it('allows community post authors to delete their post cleanup docs without reading reports', async () => {
    await seed(['users', 'authorA'], { uid: 'authorA', role: 'contractor' });
    await seed(['users', 'memberB'], { uid: 'memberB', role: 'contractor' });
    await seed(['community_posts', 'postA'], {
      authorId: 'authorA',
      authorName: 'Author A',
      authorRole: 'contractor',
      caption: 'Finished project',
      mediaUrls: [],
      likeCount: 1,
      reportCount: 1,
      moderationStatus: 'active',
      createdAt: new Date(),
    });
    await seed(['community_posts', 'postA', 'comments', 'commentB'], {
      authorId: 'memberB',
      authorName: 'Member B',
      authorRole: 'contractor',
      text: 'Looks good',
      createdAt: new Date(),
    });
    await seed(['community_posts', 'postA', 'likes', 'memberB'], {
      userId: 'memberB',
      createdAt: new Date(),
    });
    await seed(['community_posts', 'postA', 'reports', 'reportB'], {
      authorId: 'memberB',
      reason: 'Other',
      details: 'Needs review',
      createdAt: new Date(),
    });

    await assertSucceeds(deleteDoc(doc(db('authorA'), 'community_posts/postA/comments/commentB')));
    await assertSucceeds(deleteDoc(doc(db('authorA'), 'community_posts/postA/likes/memberB')));
    await assertFails(getDoc(doc(db('authorA'), 'community_posts/postA/reports/reportB')));
    await assertSucceeds(deleteDoc(doc(db('authorA'), 'community_posts/postA')));
  });

  it('blocks unrelated users from deleting community post child docs', async () => {
    await seed(['users', 'authorA'], { uid: 'authorA', role: 'contractor' });
    await seed(['users', 'memberB'], { uid: 'memberB', role: 'contractor' });
    await seed(['users', 'memberC'], { uid: 'memberC', role: 'contractor' });
    await seed(['community_posts', 'postA'], {
      authorId: 'authorA',
      authorName: 'Author A',
      authorRole: 'contractor',
      caption: 'Finished project',
      mediaUrls: [],
      likeCount: 1,
      reportCount: 0,
      moderationStatus: 'active',
      createdAt: new Date(),
    });
    await seed(['community_posts', 'postA', 'comments', 'commentB'], {
      authorId: 'memberB',
      authorName: 'Member B',
      authorRole: 'contractor',
      text: 'Looks good',
      createdAt: new Date(),
    });
    await seed(['community_posts', 'postA', 'likes', 'memberB'], {
      userId: 'memberB',
      createdAt: new Date(),
    });

    await assertFails(deleteDoc(doc(db('memberC'), 'community_posts/postA/comments/commentB')));
    await assertFails(deleteDoc(doc(db('memberC'), 'community_posts/postA/likes/memberB')));
  });

  it('allows admins to inspect payment operations and review escrow records', async () => {
    await seed(['admins', 'adminA'], { role: 'operator' });
    await seed(['users', 'contractorA'], {
      uid: 'contractorA',
      role: 'contractor',
      stripeAccountId: '',
      stripeDetailsSubmitted: false,
      stripePayoutsEnabled: false,
    });
    await seed(['escrow_bookings', 'escrowA'], {
      customerId: 'customerA',
      contractorId: 'contractorA',
      jobId: 'jobA',
      service: 'Interior Painting',
      status: 'payoutFailed',
      payoutStatus: 'failed',
      payoutError: 'Missing connected account',
      aiPrice: 1000,
      contractorPayout: 950,
      createdAt: new Date(),
    });
    await seed(['payments', 'paymentA'], {
      contractorId: 'contractorA',
      status: 'failed',
      amount: 100,
      type: 'escrow_payment',
      createdAt: new Date(),
    });
    await seed(['disputes', 'jobA'], {
      jobId: 'jobA',
      requesterUid: 'customerA',
      contractorUid: 'contractorA',
      reportedBy: 'customerA',
      reportedAgainst: 'contractorA',
      category: 'payment',
      reason: 'Payment issue',
      details: 'Escrow needs review.',
      status: 'open',
      messages: [],
      createdAt: new Date(),
    });
    await seed(['community_posts', 'postA'], {
      authorId: 'contractorA',
      authorName: 'Contractor A',
      caption: 'Reported post',
      mediaUrls: [],
      likeCount: 0,
      reportCount: 2,
      moderationStatus: 'active',
      createdAt: new Date(),
    });

    await assertSucceeds(getDoc(doc(db('adminA'), 'escrow_bookings/escrowA')));
    await assertSucceeds(updateDoc(doc(db('adminA'), 'escrow_bookings/escrowA'), {
      adminReviewedAt: new Date(),
    }));
    await assertSucceeds(setDoc(doc(db('adminA'), 'escrow_bookings/escrowA/admin_actions/actionA'), {
      type: 'reviewed',
      note: 'Checked payout failure.',
      operatorUid: 'adminA',
      createdAt: new Date(),
    }));
    await assertSucceeds(getDoc(doc(db('adminA'), 'payments/paymentA')));
    await assertSucceeds(updateDoc(doc(db('adminA'), 'payments/paymentA'), {
      adminReviewedAt: new Date(),
      lastAdminActionAt: new Date(),
      lastAdminNote: 'Stripe dashboard checked.',
    }));
    await assertSucceeds(setDoc(doc(db('adminA'), 'payments/paymentA/admin_actions/actionA'), {
      type: 'note',
      note: 'Waiting on webhook retry.',
      operatorUid: 'adminA',
      createdAt: new Date(),
    }));
    await assertSucceeds(updateDoc(doc(db('adminA'), 'users/contractorA'), {
      payoutAdminContactedAt: new Date(),
      lastAdminActionAt: new Date(),
      lastAdminNote: 'Asked contractor to finish Stripe onboarding.',
    }));
    await assertSucceeds(setDoc(doc(db('adminA'), 'users/contractorA/admin_actions/actionA'), {
      type: 'payout_contacted',
      note: 'Sent payout setup reminder.',
      operatorUid: 'adminA',
      createdAt: new Date(),
    }));
    await assertSucceeds(setDoc(doc(db('adminA'), 'disputes/jobA/admin_actions/actionA'), {
      action: 'dispute_status_updated',
      note: 'Started review.',
      adminUid: 'adminA',
      createdAt: new Date(),
    }));
    await assertSucceeds(setDoc(doc(db('adminA'), 'community_posts/postA/admin_actions/actionA'), {
      action: 'post_removed',
      note: 'Removed reported post.',
      adminUid: 'adminA',
      createdAt: new Date(),
    }));
    await assertFails(updateDoc(doc(db('adminA'), 'payments/paymentA'), {
      status: 'reviewed',
    }));
    await assertFails(setDoc(doc(db('contractorA'), 'payments/paymentA/admin_actions/actionB'), {
      type: 'note',
      note: 'Contractor should not write admin action.',
      operatorUid: 'contractorA',
      createdAt: new Date(),
    }));
    await assertFails(setDoc(doc(db('contractorA'), 'disputes/jobA/admin_actions/actionB'), {
      action: 'dispute_status_updated',
      note: 'Contractor should not write dispute admin action.',
      adminUid: 'contractorA',
      createdAt: new Date(),
    }));
    await assertFails(setDoc(doc(db('contractorA'), 'community_posts/postA/admin_actions/actionB'), {
      action: 'post_removed',
      note: 'Contractor should not write moderation admin action.',
      adminUid: 'contractorA',
      createdAt: new Date(),
    }));
  });
});
