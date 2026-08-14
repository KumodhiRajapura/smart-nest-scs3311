// Cloud Functions (TypeScript) entry point for Smart Nest (place under functions/src/index.ts)
// NOTE: repo tooling here cannot create a 'functions/' folder automatically. Copy this file into functions/src/index.ts before running `npm install` and `npm run build`.

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();
const db = admin.firestore();

function minutesSince(ts?: admin.firestore.Timestamp | null): number {
  if (!ts) return 0;
  const now = admin.firestore.Timestamp.now();
  return Math.floor((now.toDate().getTime() - ts.toDate().getTime()) / 60000);
}

export const onDeviceWrite = functions.firestore
  .document('devices/{deviceId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    const deviceId = context.params.deviceId;

    const beforeStatus = before.status;
    const afterStatus = after.status;

    if (afterStatus === 'on' && !after.turnedOnAt) {
      await db.collection('devices').doc(deviceId).set({
        turnedOnAt: admin.firestore.FieldValue.serverTimestamp(),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: 'backend_worker',
      }, { merge: true });
    }

    if (beforeStatus === 'on' && afterStatus === 'off' && before.turnedOnAt) {
      try {
        const turnedTs = before.turnedOnAt as admin.firestore.Timestamp;
        const duration = Math.max(0, minutesSince(turnedTs));
        await db.collection('usage_logs').add({
          deviceId: deviceId,
          event: 'off',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          durationOnMinutes: duration,
          createdBy: 'backend_worker',
        });

        await db.collection('devices').doc(deviceId).set({
          turnedOnAt: null,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          updatedBy: 'backend_worker',
        }, { merge: true });
      } catch (e) {
        console.error('Error creating usage log:', e);
      }
    }

    return null;
  });

export const enforceSafetyCutoffs = functions.pubsub
  .schedule('every 1 minutes')
  .timeZone('Asia/Colombo')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const q = db.collection('devices')
      .where('type', '==', 'scheduledAppliance')
      .where('status', '==', 'on')
      .where('maxOnDurationMinutes', '!=', null);

    const snap = await q.get();
    const batch = db.batch();
    const alerts: any[] = [];

    for (const doc of snap.docs) {
      const data = doc.data();
      const turned = data.turnedOnAt as admin.firestore.Timestamp | undefined | null;
      const maxMinutes = data.maxOnDurationMinutes as number | undefined | null;
      if (!turned || !maxMinutes) continue;
      const elapsed = Math.floor((now.toDate().getTime() - turned.toDate().getTime()) / 60000);
      if (elapsed >= maxMinutes) {
        const deviceRef = doc.ref;
        batch.set(deviceRef, {
          status: 'off',
          turnedOnAt: null,
          lastAlert: `Auto shut-off: exceeded ${maxMinutes} minute limit`,
          lastAlertAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedBy: 'backend_worker',
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        alerts.push({
          deviceId: doc.id,
          deviceName: data.name || doc.id,
          message: `Auto shut-off: exceeded ${maxMinutes} minute limit`,
          severity: 'critical',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          acknowledged: false,
          createdBy: 'backend_worker',
        });
      }
    }

    try {
      if (!snap.empty) await batch.commit();
      for (const a of alerts) {
        await db.collection('alerts').add(a);
      }
    } catch (e) {
      console.error('Error enforcing safety cutoffs:', e);
    }

    return null;
  });

export const onAlertCreate = functions.firestore
  .document('alerts/{alertId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const severity = data.severity || 'info';
    const deviceId = data.deviceId || null;
    const title = 'Smart Nest Alert';
    const body = data.message || 'Alert from Smart Nest';

    const message: admin.messaging.Message = {
      notification: { title, body },
      topic: 'safety_alerts',
      data: { deviceId: deviceId || '', alertId: context.params.alertId, severity },
    };

    try {
      await admin.messaging().send(message);
    } catch (e) {
      console.error('Failed to send FCM:', e);
    }

    return null;
  });
