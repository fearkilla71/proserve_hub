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

  it('allows owners to manage user-owned contractor tool artifacts', async () => {
    const ownerPaths = [
      'users/contractorA/render_history/renderA',
      'users/contractorA/quality_reports/reportA',
      'users/contractorA/bid_analyses/analysisA',
      'users/contractorA/locations/locationA',
      'users/contractorA/job_pipeline/jobA',
      'users/contractorA/schedules/scheduleA',
      'users/contractorA/crews/crewA',
    ];

    for (const pathName of ownerPaths) {
      await assertSucceeds(setDoc(doc(db('contractorA'), pathName), {
        ownerId: 'contractorA',
        title: 'Tool artifact',
        createdAt: new Date(),
      }));
      await assertSucceeds(getDoc(doc(db('contractorA'), pathName)));
      await assertFails(getDoc(doc(db('contractorB'), pathName)));
    }
  });

  it('allows contractors to manage their own saved and cost estimates', async () => {
    const savedEstimate = 'contractors/contractorA/saved_estimates/estimateA';
    const costEstimate = 'contractors/contractorA/cost_estimates/costA';

    await assertSucceeds(setDoc(doc(db('contractorA'), savedEstimate), {
      contractorId: 'contractorA',
      clientName: 'Client',
      total: 1200,
    }));
    await assertSucceeds(setDoc(doc(db('contractorA'), costEstimate), {
      contractorId: 'contractorA',
      serviceType: 'Interior Painting',
      total: 900,
    }));

    await assertSucceeds(getDoc(doc(db('contractorA'), savedEstimate)));
    await assertSucceeds(getDoc(doc(db('contractorA'), costEstimate)));
    await assertFails(getDoc(doc(db('contractorB'), savedEstimate)));
    await assertFails(setDoc(doc(db('contractorB'), costEstimate), {
      contractorId: 'contractorB',
      total: 1,
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

  it('allows admins to inspect payment operations and review escrow records', async () => {
    await seed(['admins', 'adminA'], { role: 'operator' });
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

    await assertSucceeds(getDoc(doc(db('adminA'), 'escrow_bookings/escrowA')));
    await assertSucceeds(updateDoc(doc(db('adminA'), 'escrow_bookings/escrowA'), {
      adminReviewedAt: new Date(),
    }));
    await assertSucceeds(getDoc(doc(db('adminA'), 'payments/paymentA')));
    await assertFails(updateDoc(doc(db('adminA'), 'payments/paymentA'), {
      status: 'reviewed',
    }));
  });
});
