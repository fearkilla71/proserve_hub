const fs = require('fs');
const path = require('path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
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
});
