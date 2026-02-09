const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

/**
 * Calculate and update contractor reputation metrics
 * Triggered when jobs are completed, quotes accepted, or periodically
 */

/**
 * Update reputation when a job is completed
 */
const updateReputationOnJobComplete = functions.firestore
  .document('job_requests/{jobId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only run when job transitions to completed
    if (before.status !== 'completed' && after.status === 'completed') {
      const contractorId = after.contractorId;
      if (!contractorId) return null;

      try {
        await calculateAndUpdateReputation(contractorId);
        console.log(`Updated reputation for contractor: ${contractorId}`);
      } catch (error) {
        console.error('Error updating reputation:', error);
      }
    }

    return null;
  });

/**
 * Update reputation when a quote is accepted
 */
const updateReputationOnQuoteAccept = functions.firestore
  .document('quotes/{quoteId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only run when quote is accepted
    if (before.status !== 'accepted' && after.status === 'accepted') {
      const contractorId = after.contractorId;
      if (!contractorId) return null;

      try {
        await calculateAndUpdateReputation(contractorId);
        console.log(`Updated reputation for contractor: ${contractorId}`);
      } catch (error) {
        console.error('Error updating reputation:', error);
      }
    }

    return null;
  });

/**
 * Scheduled function to recalculate all contractor reputations daily
 */
const recalculateAllReputations = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const db = admin.firestore();
    const contractorsSnapshot = await db.collection('contractors').get();

    const updatePromises = [];
    contractorsSnapshot.forEach((doc) => {
      updatePromises.push(calculateAndUpdateReputation(doc.id));
    });

    await Promise.all(updatePromises);
    console.log(`Recalculated reputation for ${updatePromises.length} contractors`);
    return null;
  });

/**
 * Core reputation calculation logic
 */
async function calculateAndUpdateReputation(contractorId) {
  const db = admin.firestore();

  // Fetch contractor data
  const contractorRef = db.collection('contractors').doc(contractorId);
  const contractorDoc = await contractorRef.get();

  if (!contractorDoc.exists) {
    throw new Error(`Contractor ${contractorId} not found`);
  }

  // Calculate completion rate
  const completionRate = await calculateCompletionRate(contractorId);

  // Calculate average response time
  const avgResponseTime = await calculateAvgResponseTime(contractorId);

  // Calculate repeat customer rate
  const repeatCustomerRate = await calculateRepeatCustomerRate(contractorId);

  // Get total completed jobs
  const totalJobsCompleted = await getTotalCompletedJobs(contractorId);

  // Calculate reliability score (composite metric)
  const reliabilityScore = calculateReliabilityScore({
    completionRate,
    avgResponseTime,
    repeatCustomerRate,
    totalJobsCompleted,
  });

  // Determine Top Pro badge eligibility
  const topProBadge = determineTopProBadge({
    reliabilityScore,
    completionRate,
    totalJobsCompleted,
    avgResponseTime,
  });

  // Update contractor document with reputation data
  const reputationData = {
    reputation: {
      reliabilityScore,
      completionRate,
      avgResponseTimeMinutes: avgResponseTime,
      repeatCustomerRate,
      totalJobsCompleted,
      topProBadge,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    },
  };

  await contractorRef.update(reputationData);

  return reputationData.reputation;
}

/**
 * Calculate completion rate: completed jobs / total accepted jobs
 */
async function calculateCompletionRate(contractorId) {
  const db = admin.firestore();

  const acceptedJobsSnapshot = await db
    .collection('job_requests')
    .where('contractorId', '==', contractorId)
    .where('claimed', '==', true)
    .get();

  const totalAccepted = acceptedJobsSnapshot.size;

  if (totalAccepted === 0) return 0;

  const completedJobsSnapshot = await db
    .collection('job_requests')
    .where('contractorId', '==', contractorId)
    .where('status', '==', 'completed')
    .get();

  const totalCompleted = completedJobsSnapshot.size;

  return (totalCompleted / totalAccepted) * 100;
}

/**
 * Calculate average response time to quotes (in minutes)
 */
async function calculateAvgResponseTime(contractorId) {
  const db = admin.firestore();

  const quotesSnapshot = await db
    .collection('quotes')
    .where('contractorId', '==', contractorId)
    .orderBy('createdAt', 'desc')
    .limit(50) // Last 50 quotes for performance
    .get();

  if (quotesSnapshot.empty) return 0;

  let totalResponseTime = 0;
  let validQuotes = 0;

  for (const doc of quotesSnapshot.docs) {
    const quote = doc.data();
    const jobId = quote.jobId;

    if (!jobId) continue;

    // Get job request creation time
    const jobDoc = await db.collection('job_requests').doc(jobId).get();
    if (!jobDoc.exists) continue;

    const jobData = jobDoc.data();
    const jobCreatedAt = jobData.createdAt?.toMillis();
    const quoteCreatedAt = quote.createdAt?.toMillis();

    if (jobCreatedAt && quoteCreatedAt && quoteCreatedAt > jobCreatedAt) {
      const responseTimeMs = quoteCreatedAt - jobCreatedAt;
      totalResponseTime += responseTimeMs / (1000 * 60); // Convert to minutes
      validQuotes++;
    }
  }

  return validQuotes > 0 ? Math.round(totalResponseTime / validQuotes) : 0;
}

/**
 * Calculate repeat customer rate: customers who hired >1 time / total customers
 */
async function calculateRepeatCustomerRate(contractorId) {
  const db = admin.firestore();

  const completedJobsSnapshot = await db
    .collection('job_requests')
    .where('contractorId', '==', contractorId)
    .where('status', '==', 'completed')
    .get();

  if (completedJobsSnapshot.empty) return 0;

  const customerJobCount = {};

  completedJobsSnapshot.forEach((doc) => {
    const customerId = doc.data().requesterUid;
    if (customerId) {
      customerJobCount[customerId] = (customerJobCount[customerId] || 0) + 1;
    }
  });

  const totalCustomers = Object.keys(customerJobCount).length;
  const repeatCustomers = Object.values(customerJobCount).filter(
    (count) => count > 1
  ).length;

  return totalCustomers > 0 ? (repeatCustomers / totalCustomers) * 100 : 0;
}

/**
 * Get total completed jobs
 */
async function getTotalCompletedJobs(contractorId) {
  const db = admin.firestore();

  const completedJobsSnapshot = await db
    .collection('job_requests')
    .where('contractorId', '==', contractorId)
    .where('status', '==', 'completed')
    .get();

  return completedJobsSnapshot.size;
}

/**
 * Calculate reliability score (0-5 scale)
 * Weighted composite of various factors
 */
function calculateReliabilityScore({
  completionRate,
  avgResponseTime,
  repeatCustomerRate,
  totalJobsCompleted,
}) {
  // Normalize completion rate (0-100 -> 0-5)
  const completionScore = (completionRate / 100) * 5;

  // Normalize response time (faster is better, max 5 for <1hr, 0 for >24hr)
  let responseScore = 5;
  if (avgResponseTime > 1440) responseScore = 0; // >24h
  else if (avgResponseTime > 720) responseScore = 2; // >12h
  else if (avgResponseTime > 240) responseScore = 3; // >4h
  else if (avgResponseTime > 60) responseScore = 4; // >1h

  // Normalize repeat customer rate (0-100 -> 0-5)
  const repeatScore = (repeatCustomerRate / 100) * 5;

  // Experience bonus (more jobs = higher weight)
  const experienceMultiplier = Math.min(1 + totalJobsCompleted / 100, 1.2);

  // Weighted average
  const rawScore =
    (completionScore * 0.4 + responseScore * 0.3 + repeatScore * 0.3) *
    experienceMultiplier;

  // Clamp to 0-5 and round to 1 decimal
  return Math.min(5, Math.max(0, Math.round(rawScore * 10) / 10));
}

/**
 * Determine if contractor qualifies for Top Pro badge
 */
function determineTopProBadge({
  reliabilityScore,
  completionRate,
  totalJobsCompleted,
  avgResponseTime,
}) {
  // Requirements for Top Pro:
  // - Reliability score >= 4.5
  // - Completion rate >= 90%
  // - At least 10 completed jobs
  // - Average response time <= 120 minutes (2 hours)

  return (
    reliabilityScore >= 4.5 &&
    completionRate >= 90 &&
    totalJobsCompleted >= 10 &&
    avgResponseTime <= 120
  );
}

module.exports = {
  updateReputationOnJobComplete,
  updateReputationOnQuoteAccept,
  recalculateAllReputations,
  calculateAndUpdateReputation,
  calculateCompletionRate,
  calculateAvgResponseTime,
  calculateRepeatCustomerRate,
  calculateReliabilityScore,
  determineTopProBadge,
};
