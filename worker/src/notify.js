'use strict';

const { db, messaging, FieldValue, log } = require('./firebase');
const { COLLECTIONS } = require('./constants');

const TOPIC = process.env.FCM_TOPIC || 'alerts';

/**
 * Record an alert and push it to every subscribed phone.
 *
 * Two writes, deliberately in this order. The Firestore document is the
 * durable record -- it survives a phone that was off, a revoked notification
 * permission, or a push that Google drops. The FCM message is only the nudge,
 * so if it fails we log it and carry on rather than failing the cutoff that
 * caused it.
 */
async function raiseAlert({ type, message, deviceId = '', deviceName = '' }) {
  await db().collection(COLLECTIONS.alerts).add({
    type,
    message,
    deviceId,
    deviceName,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  log(`alert: ${type} -- ${message}`);
  await push({ type, message, deviceId, deviceName });
}

async function push({ type, message, deviceId, deviceName }) {
  try {
    await messaging().send({
      topic: TOPIC,
      notification: {
        title: deviceName ? `${deviceName}` : 'Smart Nest',
        body: message,
      },
      data: {
        type: String(type),
        deviceId: String(deviceId || ''),
      },
      android: {
        priority: 'high',
        notification: { channelId: 'smart_nest_alerts' },
      },
    });
    log(`push sent to topic "${TOPIC}"`);
  } catch (err) {
    // A missing topic subscriber is not an error worth stopping for.
    log(`push failed (non-fatal): ${err.message}`);
  }
}

module.exports = { raiseAlert, TOPIC };
