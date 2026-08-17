'use strict';

const { db, messaging, FieldValue, log } = require('./firebase');
const { COLLECTIONS, SEVERITY } = require('./constants');

const TOPIC = process.env.FCM_TOPIC || 'alerts';

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
