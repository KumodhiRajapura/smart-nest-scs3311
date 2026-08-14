'use strict';

const { db, FieldValue, log } = require('./firebase');
const { COLLECTIONS, STATUS, SOURCE, REASON } = require('./constants');

/**
 * Writes to the `devices` collection made on the system's behalf.
 *
 * Mirrors DeviceRepository on the Flutter side, including the `turnedOnAt`
 * rules -- the safety worker cannot tell who wrote a status, so every writer
 * has to maintain that field the same way or the countdown breaks.
 */

/** Switch a device (or one channel of a gang box) on or off. */
async function setPower({
  deviceId,
  on,
  channelIndex = null,
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

    // Never fight the hardware: a device the simulator says is faulty or gone
    // stays that way until it reports otherwise.
    if (
      device.status === STATUS.error ||
      device.status === STATUS.disconnected
    ) {
      log(`control: ${device.name} is ${device.status}, skipping`);
      return;
    }

    const update = {
      statusReason: reason,
      updatedBy: source,
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (channelIndex === null || !Array.isArray(device.channels)) {
      update.status = on ? STATUS.on : STATUS.off;
      if (Array.isArray(device.channels) && device.channels.length) {
        update.channels = device.channels.map((c) => ({ ...c, isOn: on }));
      }
    } else {
      const channels = device.channels.map((c) =>
        Number(c.index) === Number(channelIndex) ? { ...c, isOn: on } : c
      );
      update.channels = channels;
      update.status = channels.some((c) => c.isOn) ? STATUS.on : STATUS.off;
    }

    const wasOn = device.status === STATUS.on;
    const willBeOn = update.status === STATUS.on;

    // Only a genuine OFF -> ON edge restarts the safety clock.
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
      updatedAt: FieldValue.serverTimestamp(),
    });
}

module.exports = { setPower, setStatus };
