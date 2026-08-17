'use strict';

const { db, FieldValue, toDate, log } = require('./firebase');
const {
  COLLECTIONS,
  STATUS,
  SOURCE,
  REASON,
  ALERT_TYPE,
  SEVERITY,
} = require('./constants');
const { raiseAlert } = require('./notify');

const timers = new Map();

// setTimeout fires immediately past this, so long budgets are armed in chunks.
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

function arm(device) {
  disarm(device.id);

  const budget = budgetMs(device);
  if (!budget || device.status !== STATUS.on) return;

  const turnedOnAt = toDate(device.turnedOnAt);
  if (!turnedOnAt) {

    return;
  }

  const remaining = turnedOnAt.getTime() + budget - Date.now();
  const delay = Math.max(0, Math.min(remaining, MAX_TIMEOUT_MS));

  timers.set(
    device.id,
    setTimeout(() => {
      if (remaining > MAX_TIMEOUT_MS) {
        arm(device); 
      } else {
        cutOff(device.id).catch((err) => log(`cutoff failed: ${err.message}`));
      }
    }, delay)
  );

  log(`safety: ${device.name} armed, ${Math.round(remaining / 1000)}s remaining`);
}


async function cutOff(deviceId) {
  const ref = db().collection(COLLECTIONS.devices).doc(deviceId);

  const result = await db().runTransaction(async (txn) => {
    const snap = await txn.get(ref);
    if (!snap.exists) return null;

    const device = { id: snap.id, ...snap.data() };
    if (device.status !== STATUS.on) return null;

    const budget = budgetMs(device);
    const turnedOnAt = toDate(device.turnedOnAt);
    if (!budget || !turnedOnAt) return null;

    const elapsed = Date.now() - turnedOnAt.getTime();
    if (elapsed + 1000 < budget) return { rearm: device };

    const update = {
      status: STATUS.off,
      turnedOnAt: null,
      statusReason: REASON.safetyCutoff,
      updatedBy: SOURCE.worker,
      lastUpdated: FieldValue.serverTimestamp(),
      lastAlert: 'Switched off automatically for safety',
      lastAlertAt: FieldValue.serverTimestamp(),
    };

    if (Array.isArray(device.childSwitches) && device.childSwitches.length) {
      update.childSwitches = device.childSwitches.map((c) => ({
        ...c,
        isOn: false,
      }));
    }

    txn.update(ref, update);
    return { cut: device };
  });

  if (!result) return;

  if (result.rearm) {
    arm(result.rearm);
    return;
  }

  const device = result.cut;
  const minutes = Number(device.maxOnDurationMinutes) || 0;

  log(`SAFETY CUTOFF: ${device.name} after ${minutes} min`);

  await raiseAlert({
    type: ALERT_TYPE.safetyCutoff,
    severity: SEVERITY.critical,
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
