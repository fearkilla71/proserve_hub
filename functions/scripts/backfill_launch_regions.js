#!/usr/bin/env node

const admin = require('firebase-admin');

function normalizeZip(value) {
  const digits = (value || '').toString().replace(/\D/g, '');
  return digits.length >= 5 ? digits.slice(0, 5) : digits;
}

function isSupportedLaunchZip(value) {
  const zip = normalizeZip(value);
  return /^(770(0[1-9]|[1-8][0-9]|9[0-6]|98|99)|773(0[1-6]|1[568]|2[578]|3[36789]|4[567]|5[3-7]|6[2589]|7[235789]|8[0-9]|9[136])|774(0[1267]|1[0137]|2[239]|3[013]|4[145679]|5[019]|6[13469]|7[16789]|8[014679]|9[1234678])|775(0[1-8]|1[0-8]|2[0-3]|3[0-6]|38|39|4[125679]|5[0-5]|6[0-6]|68|7[1234578]|8[0-8]|9[0-278])|776(17|23|50|61|65))$/.test(zip);
}

function launchRegionForZip(zip) {
  return isSupportedLaunchZip(zip) ? 'houston_metro' : 'unsupported';
}

function marketStatusForZip(zip) {
  return isSupportedLaunchZip(zip) ? 'active' : 'waitlist';
}

function extractZip(data) {
  const candidates = [
    data.zip,
    data.serviceZip,
    data.businessZip,
    data.location,
    data.address,
  ];
  for (const candidate of candidates) {
    const zip = normalizeZip(candidate);
    if (zip.length === 5) return zip;
  }
  return '';
}

async function commitBatch(db, batch, count, apply) {
  if (!apply || count === 0) return;
  await batch.commit();
}

async function backfillCollection(db, collectionName, apply) {
  const snap = await db.collection(collectionName).get();
  let scanned = 0;
  let changed = 0;
  let unsupported = 0;
  let missingZip = 0;
  let batch = db.batch();
  let writes = 0;

  for (const doc of snap.docs) {
    scanned += 1;
    const data = doc.data() || {};
    const zip = extractZip(data);
    if (!zip) {
      missingZip += 1;
      continue;
    }

    const launchRegion = launchRegionForZip(zip);
    const marketStatus = marketStatusForZip(zip);
    if (marketStatus === 'waitlist') unsupported += 1;

    if (
      data.zip === zip &&
      data.launchRegion === launchRegion &&
      data.marketStatus === marketStatus
    ) {
      continue;
    }

    changed += 1;
    if (apply) {
      batch.set(
        doc.ref,
        {
          zip,
          launchRegion,
          marketStatus,
          regionBackfilledAt: admin.firestore.FieldValue.serverTimestamp(),
          ...(marketStatus === 'active'
            ? { marketActivatedAt: admin.firestore.FieldValue.serverTimestamp() }
            : { waitlistJoinedAt: admin.firestore.FieldValue.serverTimestamp() }),
        },
        { merge: true }
      );
      writes += 1;
      if (writes >= 450) {
        await commitBatch(db, batch, writes, apply);
        batch = db.batch();
        writes = 0;
      }
    }
  }

  await commitBatch(db, batch, writes, apply);
  return { collection: collectionName, scanned, changed, unsupported, missingZip };
}

async function mirrorUnsupportedUsersToWaitlist(db, apply) {
  const snap = await db.collection('users').where('marketStatus', '==', 'waitlist').get();
  let changed = 0;
  let batch = db.batch();
  let writes = 0;

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const email = (data.email || '').toString().trim();
    const role = (data.role || '').toString().trim().toLowerCase();
    const zip = extractZip(data);
    if (!email || !['customer', 'contractor'].includes(role)) continue;

    changed += 1;
    if (apply) {
      const waitlistRef = db.collection('waitlist').doc(`user_${doc.id}`);
      batch.set(
        waitlistRef,
        {
          uid: doc.id,
          name: (data.displayName || data.name || email).toString().trim(),
          email,
          phone: (data.phone || '').toString().trim(),
          role,
          zip,
          service: (data.service || '').toString().trim(),
          services: Array.isArray(data.services) ? data.services : [],
          launchRegion: 'unsupported',
          marketStatus: 'waitlist',
          source: 'launch_region_backfill',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      writes += 1;
      if (writes >= 450) {
        await commitBatch(db, batch, writes, apply);
        batch = db.batch();
        writes = 0;
      }
    }
  }

  await commitBatch(db, batch, writes, apply);
  return { collection: 'waitlist', scanned: snap.size, changed };
}

async function main() {
  const apply = process.argv.includes('--apply');
  const projectArg = process.argv.find((arg) => arg.startsWith('--project='));
  const firebaseConfig = process.env.FIREBASE_CONFIG
    ? JSON.parse(process.env.FIREBASE_CONFIG)
    : {};
  const projectId = projectArg?.split('=')[1]
    || process.env.GCLOUD_PROJECT
    || process.env.GOOGLE_CLOUD_PROJECT
    || firebaseConfig.projectId;

  admin.initializeApp(projectId ? { projectId } : undefined);
  const db = admin.firestore();

  const results = [];
  results.push(await backfillCollection(db, 'users', apply));
  results.push(await backfillCollection(db, 'contractors', apply));
  results.push(await backfillCollection(db, 'job_requests', apply));
  results.push(await mirrorUnsupportedUsersToWaitlist(db, apply));

  console.log(JSON.stringify({ apply, results }, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
