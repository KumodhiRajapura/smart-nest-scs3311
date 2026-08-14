'use strict';

const { db, FieldValue, log } = require('./firebase');
const { COLLECTIONS, USAGE_EVENT } = require('./constants');

/**
 * Usage tracking.
 *
 * The worker is the only writer of `usage_logs`, and firestore.rules denies the
 * collection to every client. Two reasons:
 *
 *   1. Completeness. The worker reacts to *status transitions*, not to button
 *      presses, so a device switched on from the simulator or by a schedule is
 *      measured exactly like one switched on from the phone. If the app wrote
 *      its own rows, everything that did not originate in the app would go
 *      uncounted.
 *
 *   2. Integrity. One writer means no duplicate row when two clients react to
 *      the same change, and usage that cannot be fabricated from a handset.
 *
 * The log is event-shaped: one row per transition. A row that ends a session
 * carries the duration, so a report needs no pairing pass -- summing the
 * `off` and `auto_off_safety` rows gives total ON time directly.
 */

function logsRef() {
  return db().collection(COLLECTIONS.usageLogs);
}

/**
 * Record one transition.
 *
 * Duration is written in both seconds and minutes: minutes because
 * firebase/SCHEMA.md specifies it, seconds because a two-minute safety demo
 * rounds to a useless "2 min" and the report needs the real figure.
 */
async function recordEvent(device, event, durationSeconds = null) {
  const row = {
    deviceId: device.id,
    deviceName: device.name || '',
    roomId: device.roomId || '',
    event,
    timestamp: FieldValue.serverTimestamp(),
    createdBy: 'backend_worker',
    durationOnSeconds: durationSeconds,
    durationOnMinutes:
      durationSeconds === null ? null : Math.round(durationSeconds / 60),
  };

  await logsRef().add(row);

  const suffix =
    durationSeconds === null ? '' : ` after ${durationSeconds}s`;
  log(`usage: ${device.name || device.id} -> ${event}${suffix}`);
}

const recordOn = (device) => recordEvent(device, USAGE_EVENT.on);

const recordOff = (device, durationSeconds, wasCutOff = false) =>
  recordEvent(
    device,
    wasCutOff ? USAGE_EVENT.autoOffSafety : USAGE_EVENT.off,
    durationSeconds
  );

const recordFault = (device, event) => recordEvent(device, event);

module.exports = { recordEvent, recordOn, recordOff, recordFault };
