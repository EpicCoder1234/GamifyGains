/**
 * @file Firebase Cloud Function to reset weekly gym time for all users.
 * @description This function is scheduled to run periodically (e.g., every
 * Monday at midnight UTC). It iterates through all user documents in Firestore
 * and sets their 'weeklyGymTime' to 0 and updates 'lastWeeklyResetDate'.
 */

// Import necessary Firebase modules
const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK if not already initialized (only once)
if (!admin.apps.length) {
  admin.initializeApp();
}

const firestore = admin.firestore();

/**
 * Scheduled Cloud Function to reset weeklyGymTime for all users.
 *
 * This function will be triggered based on the cron schedule defined.
 * Example: '0 0 * * 1' means "At 00:00 (midnight) on Monday."
 * We recommend using UTC time for server-side operations for consistency.
 */
exports.resetWeeklyGymTime = functions.pubsub.schedule('0 0 * * 1') // Runs every Monday at 00:00 UTC
    .timeZone('UTC') // Ensure the timezone is explicit
    .onRun(async (context) => {
      console.log('Weekly gym time reset function started.');

      const usersRef = firestore.collection('users');
      let usersSnapshot;
      try {
        usersSnapshot = await usersRef.get();
        console.log(`Found ${usersSnapshot.size} user documents to process.`);
      } catch (error) {
        console.error('Error fetching users collection:', error);
        return null; // Exit early if unable to fetch users
      }

      if (usersSnapshot.empty) {
        console.log('No user documents found in Firestore. Skipping reset.');
        return null;
      }

      const batch = firestore.batch();
      const now = admin.firestore.Timestamp.now(); // Current server timestamp

      let updatedCount = 0;
      usersSnapshot.forEach((doc) => { // Added parentheses around 'doc' for arrow-parens rule
        // Get the existing user data.
        // Ensure 'weeklyGymTime' and 'lastWeeklyResetDate' fields exist in your User model
        // or handle cases where they might be missing (e.g., new users).
        const userData = doc.data();
        const currentWeeklyGymTime = userData.weeklyGymTime || 0; // Default to 0 if null/undefined

        // Only reset if currentWeeklyGymTime is greater than 0 to avoid unnecessary writes
        // Or you can always write to ensure lastWeeklyResetDate is updated.
        if (currentWeeklyGymTime > 0) {
          const userDocRef = usersRef.doc(doc.id);
          batch.update(userDocRef, {
            weeklyGymTime: 0,
            lastWeeklyResetDate: now, // Record when the reset happened, added trailing comma
          });
          updatedCount++;
        }
      });

      try {
        if (updatedCount > 0) {
          await batch.commit();
          console.log(`Successfully reset weeklyGymTime for ${updatedCount} users.`);
        } else {
          console.log('No users had positive weeklyGymTime. No updates committed.');
        }
        console.log('Weekly gym time reset function finished successfully.');
        return {success: true, usersReset: updatedCount}; // Consistent object-curly-spacing
      } catch (error) {
        console.error('Error committing batch update for weekly gym time reset:', error);
        return {success: false, error: error.message}; // Consistent object-curly-spacing
      }
    });

