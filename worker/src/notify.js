'use strict';

const { db, messaging, FieldValue, log } = require('./firebase');
const { COLLECTIONS, SEVERITY } = require('./constants');

const TOPIC = process.env.FCM_TOPIC || 'alerts';

/**
 * Record an alert and push it to every subscribed phone.
 *
 * Two writes, deliberately in this order. The Firestore document is the durable
 * record -- it survives a phone that was off, a revoked notification
 * permission, or a push that Google drops. The FCM message is only the nudge,
 * so if it fails we log it and carry on rather than failing the safety cutoff
 * that caused it. A cutoff that rolled back because a notification could not be
 * delivered would be a far worse bug than a missed notification.
 */
async function raiseAlert({
  type,
  message,
  severity = SEVERITY.warning,
  deviceId = '',
  deviceName = '',
}) {
  await db().collection(COLLECTIONS.alerts).add({
    type,
    message,
    severity,
    deviceId,
    deviceName,
    acknowledged: false,
    createdAt: FieldValue.serverTimestamp(),
    createdBy: 'backend_worker',
  });

  log(`alert: ${type} -- ${message}`);
  await push({ type, message, deviceId, deviceName, severity });
}

async function push({ type, message, deviceId, deviceName, severity }) {
  try {
    await messaging().send({
      // A topic rather than device tokens: no token registry to maintain, no
      // stale-token cleanup, and in a household everyone *should* hear that the
      // iron was cut off.
      topic: TOPIC,
      notification: {
        title: deviceName || 'Smart Nest',
        body: message,
      },
      data: {
        type: String(type),
        deviceId: String(deviceId || ''),
        severity: String(severity || ''),
      },
      android: {
        priority: 'high',
        notification: { channelId: 'smart_nest_alerts' },
      },
    });
    log(`push sent to topic "${TOPIC}"`);
  } catch (err) {
    // No subscriber yet is not an error worth stopping for.
    log(`push failed (non-fatal): ${err.message}`);
  }
}

module.exports = { raiseAlert, TOPIC };
