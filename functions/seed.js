/**
 * Seed script: Populate Firestore with pricing rules and ZIP costs for testing.
 * 
 * Usage:
 *   node seed.js
 * 
 * This will write to your live Firestore (or emulator if FIRESTORE_EMULATOR_HOST is set).
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
// (Uses Application Default Credentials or GOOGLE_APPLICATION_CREDENTIALS env var)
admin.initializeApp();

const db = admin.firestore();

async function seed() {
  console.log('Seeding Firestore...\n');

  // Pricing rules for painting
  await db.collection('pricing_rules').doc('painting').set({
    baseRate: 2.5,
    unit: 'sqft',
    minPrice: 150,
    maxPrice: 1500,
  });
  console.log('✓ Created pricing_rules/painting');

  // Pricing rules for drywall
  await db.collection('pricing_rules').doc('drywall').set({
    baseRate: 3.0,
    unit: 'sqft',
    minPrice: 200,
    maxPrice: 2000,
  });
  console.log('✓ Created pricing_rules/drywall');

  // Pricing rules for plumbing (hourly example)
  await db.collection('pricing_rules').doc('plumbing').set({
    baseRate: 95,
    unit: 'hour',
    minPrice: 120,
    maxPrice: 800,
  });
  console.log('✓ Created pricing_rules/plumbing');

  // Sample ZIP costs (Houston area examples)
  const zipCosts = {
    '77001': { multiplier: 1.15 }, // Downtown Houston
    '77002': { multiplier: 1.20 },
    '77006': { multiplier: 1.25 }, // Montrose
    '77019': { multiplier: 1.30 }, // River Oaks
    '77024': { multiplier: 1.10 },
    '77030': { multiplier: 1.15 }, // Medical Center
    '77056': { multiplier: 1.25 }, // Galleria
    '77079': { multiplier: 1.05 },
    '77494': { multiplier: 0.95 }, // Katy (suburban)
    '77573': { multiplier: 0.90 }, // League City
  };

  const batch = db.batch();
  for (const [zip, data] of Object.entries(zipCosts)) {
    const ref = db.collection('zip_costs').doc(zip);
    batch.set(ref, data);
  }
  await batch.commit();
  console.log(`✓ Created ${Object.keys(zipCosts).length} zip_costs entries`);

  console.log('\n✅ Seed complete!');
  process.exit(0);
}

seed().catch((err) => {
  console.error('❌ Seed failed:', err);
  process.exit(1);
});
