'use strict';

const { db, FieldValue, toDate, log } = require('./firebase');
const { COLLECTIONS, STATUS, SOURCE, REASON, ALERT_TYPE } = require('./constants');
const { raiseAlert } = require('./notify');

/**
 * Server-side safety cutoff.
 *
 * The rule: a device carrying `maxOnDurationMinutes` may not stay ON for longer
 * than that. When the budget runs out the worker flips the database to OFF and
 * raises an alert -- the phone does not have to be awake, unlocked, or even in
 * the building, which is the whole point of the requirement.
 *
 * The countdown is derived, never stored. `turnedOnAt` plus the budget gives
 * the deadline, so restarting the worker mid-session re-arms the timer with the
 * correct remaining time instead of granting a fresh one.
 */

// deviceId -> Timeout
const timers = new Map();

// setTimeout overflows past this and fires immediately, so long budgets are
// armed in chunks.
const MAX_TIMEOUT_MS = 2 ** 31 - 1;

function budgetMs(device) {
  const minutes = Number(device.maxOnDurationMinutes) || 0;
  return minutes > 0 ? minutes * 60 * 1000 : 0;
}

function disarm(deviceId) {
  const timer = timers.get(deviceId);
  if (timer) {
    clearTimeout(timer);
    timers.delete(deviceId);
  }
}

/**
 * (Re)arm the cutoff for a device. Safe to call on every snapshot -- it always
 * clears the previous timer first, so a change to `maxOnDurationMinutes` while
 * the device is running takes effect immediately.
 */
function arm(device) {
  disarm(device.id);

  const budget = budgetMs(device);
  if (!budget || device.status !== STATUS.on) return;

  const turnedOnAt = toDate(device.turnedOnAt);
  if (!turnedOnAt) {
    // The server timestamp has not resolved yet. The write that resolves it
    // produces another snapshot, and that one will arm the timer properly.
    return;
  }

  const remaining = turnedOnAt.getTime() + budget - Date.now();
  const delay = Math.max(0, Math.min(remaining, MAX_TIMEOUT_MS));

  timers.set(
    device.id,
    setTimeout(() => {
      if (remaining > MAX_TIMEOUT_MS) {
        arm(device); // long budget: continue counting in the next chunk
      } else {
        cutOff(device.id).catch((err) => log(`cutoff failed: ${err.message}`));
      }
    }, delay)
  );

  log(
    `safety: ${device.name} armed, ${Math.round(remaining / 1000)}s remaining`
  );
}

/**
 * Flip a device OFF because its budget expired.
 *
 * The read-check-write runs in a transaction so a cutoff cannot land on top of
 * a user who switched the device off and straight back on in the same instant;
 * the transaction re-reads `turnedOnAt` and stands down if the session it was
 * armed for is already over.
 */
async function cutOff(deviceId) {
  const ref = db().collection(COLLECTIONS.devices).doc(deviceId);

  const cutDevice = await db().runTransaction(async (txn) => {
    const snap = await txn.get(ref);
    if (!snap.exists) return null;

    const device = { id: snap.id, ...snap.data() };
    if (device.status !== STATUS.on) return null;

    const budget = budgetMs(device);
    const turnedOnAt = toDate(device.turnedOnAt);
    if (!budget || !turnedOnAt) return null;

    // One second of slack absorbs clock jitter between this process and the
    // Firestore servers.
    const elapsed = Date.now() - turnedOnAt.getTime();
    if (elapsed + 1000 < budget) return { rearm: device };

    const update = {
      status: STATUS.off,
      turnedOnAt: null,
      statusReason: REASON.safetyCutoff,
      updatedBy: SOURCE.worker,
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (Array.isArray(device.channels) && device.channels.length) {
      update.channels = device.channels.map((c) => ({ ...c, isOn: false }));
    }

    txn.update(ref, update);
    return { cut: device };
  });

  if (!cutDevice) return;

  // The session was newer than the timer thought -- start the clock again.
  if (cutDevice.rearm) {
    arm(cutDevice.rearm);
    return;
  }

  const device = cutDevice.cut;
  const minutes = Number(device.maxOnDurationMinutes) || 0;

  log(`SAFETY CUTOFF: ${device.name} after ${minutes} min`);

  await raiseAlert({
    type: ALERT_TYPE.safetyCutoff,
    deviceId: device.id,
    deviceName: device.name,
    message:
      `${device.name} was switched off automatically after ${minutes} ` +
      'minutes for safety.',
  });
}

function armedCount() {
  return timers.size;
}

function disarmAll() {
  for (const timer of timers.values()) clearTimeout(timer);
  timers.clear();
}

module.exports = { arm, disarm, cutOff, armedCount, disarmAll };
