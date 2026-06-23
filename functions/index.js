/**
 * Cloud Function : notifyFamilyEvent
 *
 * Déploiement :
 *   1. firebase init functions   (choisir JavaScript)
 *   2. npm install               (dans le dossier functions/)
 *   3. firebase deploy --only functions
 *
 * Cette fonction est appelée depuis l'app Flutter via cloud_functions
 * et envoie une notification FCM à tous les appareils abonnés au
 * topic "family_agenda".
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.notifyFamilyEvent = functions.https.onCall(async (data, context) => {
  const { title, body, startTime } = data;

  if (!title || !body) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'title et body sont requis.'
    );
  }

  const message = {
    topic: 'family_agenda',
    notification: { title, body },
    data: {
      type: 'new_event',
      startTime: startTime ?? '',
    },
    android: {
      priority: 'high',
      notification: { channelId: 'family_events', sound: 'default' },
    },
    apns: {
      payload: { aps: { sound: 'default', badge: 1 } },
    },
  };

  await admin.messaging().send(message);
  return { success: true };
});
