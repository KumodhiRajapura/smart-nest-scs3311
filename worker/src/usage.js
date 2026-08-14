'use strict';

const { db, toDate, log } = require('./firebase');
const { COLLECTIONS, STATUS } = require('./constants');

/**
 * Usage tracking.
 *
 * The worker is the only writer of `usage_logs`. It reacts to status
 * transitions rather than to user actions, so a device switched on from the web
 * simulator, by a schedule, or by hand in the Firestore console is measured
 * exactly the same way as one switched on from the phone.
 *
 * An open session is a document with `offAt == null`. There is at most one per
 * device; [openSession] checks before inserting so a worker restart in the
 * middle of a long iron session does not create a second one.
 */

function logsRef() {
  return db().collection(COLLECTIONS.usageLogs);
}

async function findOpenSession(deviceId) {
  const snap = await logsRef()
    .where('deviceId', '==', deviceId)
    .where('offAt', '==', null)
    .limit(1)
    .get();

  return snap.empty ? null : snap.docs[0];
}

/** Start a session, unless one is already open for this device. */
async function openSession(device) {
  const existing = await findOpenSession(device.id);
  if (existing) return existing.id;

  // Prefer the device's own `turnedOnAt`: on a worker restart that is when the
  // appliance actually came on, which may be long before the worker did.
  const onAt = toDate(device.turnedOnAt) || new Date();

  const ref = await logsRef().add({
    deviceId: device.id,
    deviceName: device.name || '',
    floorId: device.floorId || '',
    onAt,
    offAt: null,
    durationSeconds: null,
    startedBy: device.updatedBy || null,
    endedBy: null,
  });

  log(`usage: opened session for ${device.name}`);
  return ref.id;
}

/** Close the open session, if there is one. */
async function closeSession(device, endedBy) {
  const open = await findOpenSession(device.id);
  if (!open) return;

  const onAt = toDate(open.get('onAt')) || new Date();
  const offAt = new Date();
  const durationSeconds = Math.max(
    0,
    Math.round((offAt.getTime() - onAt.getTime()) / 1000)
  );

  await open.ref.update({
    offAt,
    durationSeconds,
    endedBy: endedBy || device.updatedBy || null,
  });

  log(`usage: closed session for ${device.name} after ${durationSeconds}s`);
}

/**
 * Bring the ledger back in line with reality after a restart.
 *
 * If the device is ON there must be an open session; if it is not, any session
 * left dangling by a crash is closed at the time the worker last saw sense --
 * we use the device's `updatedAt`, not now, so downtime is not billed as usage.
 */
async function reconcile(device) {
  if (device.status === STATUS.on) {
    await openSession(device);
    return;
  }

  const open = await findOpenSession(device.id);
  if (!open) return;

  const onAt = toDate(open.get('onAt')) || new Date();
  const offAt = toDate(device.updatedAt) || new Date();
  const durationSeconds = Math.max(
    0,
    Math.round((offAt.getTime() - onAt.getTime()) / 1000)
  );

  await open.ref.update({
    offAt,
    durationSeconds,
    endedBy: 'reconciled',
  });

  log(`usage: reconciled stale session for ${device.name} (${durationSeconds}s)`);
}

module.exports = { openSession, closeSession, reconcile, findOpenSession };
