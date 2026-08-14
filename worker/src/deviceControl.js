'use strict';

const { db, FieldValue, log } = require('./firebase');
const { COLLECTIONS, STATUS, SOURCE, REASON } = require('./constants');

/**
 * Writes to the `devices` collection made on the system's behalf.
 *
 * Mirrors FirestoreService on the Flutter side, including the `turnedOnAt`
 * rules. The safety worker cannot tell who wrote a status, so every writer has
 * to maintain that field identically or the countdown breaks for everyone.
 */

/** Switch a device, or one child switch of a gang box, on or off. */
async function setPower({
  deviceId,
  on,
  childIndex = null,
  reason = REASON.schedule,
  source = SOURCE.worker,
}) {
  const ref = db().collection(COLLECTIONS.devices).doc(deviceId);

  await db().runTransaction(async (txn) => {
    const snap = await txn.get(ref);
    if (!snap.exists) {
      log(`control: device ${deviceId} no longer exists, skipping`);
      return;
    }

    const device = snap.data();

    // Never fight the hardware. A device the simulator reports as faulty or
    // unreachable stays that way until it says otherwise -- a schedule must not
    // paint a broken appliance as running.
    if (device.status === STATUS.error || device.status === STATUS.disconnected) {
      log(`control: ${device.name} is ${device.status}, skipping`);
      return;
    }

    const update = {
      statusReason: reason,
      updatedBy: source,
      lastUpdated: FieldValue.serverTimestamp(),
    };

    const children = Array.isArray(device.childSwitches)
      ? device.childSwitches
      : [];

    if (childIndex === null || children.length === 0) {
      update.status = on ? STATUS.on : STATUS.off;
      if (children.length > 0) {
        update.childSwitches = children.map((c) => ({ ...c, isOn: on }));
      }
    } else {
      const next = children.map((c, i) =>
        i === Number(childIndex) ? { ...c, isOn: on } : c
      );
      update.childSwitches = next;
      update.status = next.some((c) => c.isOn) ? STATUS.on : STATUS.off;
    }

    const wasOn = device.status === STATUS.on;
    const willBeOn = update.status === STATUS.on;

    // Only a genuine OFF -> ON edge restarts the safety clock. Re-applying a
    // schedule to a device that is already running must not extend its budget.
    if (willBeOn && !wasOn) update.turnedOnAt = FieldValue.serverTimestamp();
    if (!willBeOn) update.turnedOnAt = null;

    txn.update(ref, update);
  });
}

/** Force a status the user cannot set, e.g. DISCONNECTED from the watchdog. */
async function setStatus({ deviceId, status, reason }) {
  await db()
    .collection(COLLECTIONS.devices)
    .doc(deviceId)
    .update({
      status,
      turnedOnAt: status === STATUS.on ? FieldValue.serverTimestamp() : null,
      statusReason: reason,
      updatedBy: SOURCE.worker,
      lastUpdated: FieldValue.serverTimestamp(),
    });
}

module.exports = { setPower, setStatus };
