'use strict';

require('dotenv').config();

const { db, init, toDate, log } = require('./src/firebase');
const {
  COLLECTIONS,
  STATUS,
  REASON,
  ALERT_TYPE,
  SEVERITY,
  USAGE_EVENT,
} = require('./src/constants');
const safety = require('./src/safety');
const usage = require('./src/usage');
const scheduler = require('./src/scheduler');
const heartbeat = require('./src/heartbeat');
const { raiseAlert } = require('./src/notify');

/**
 * Smart Nest backend worker.
 *
 * Four jobs, all driven from one Firestore listener plus two timers:
 *
 *   1. usage tracking  -- one event row per ON/OFF transition
 *   2. safety cutoffs  -- switch a device off when its budget expires
 *   3. schedules       -- switch lights on and off at preset times
 *   4. presence        -- mark devices DISCONNECTED when heartbeats stop
 *
 * It listens rather than polls, so a change made from the phone or the
 * simulator is reacted to in well under a second. Everything it reacts to is a
 * *state transition*, which is why it does not matter who caused the change --
 * app, simulator, schedule or cutoff are all measured and protected alike.
 */

/**
 * Live copy of every device.
 *
 * The snapshot listener keeps this current, and the scheduler and heartbeat
 * watchdog read from it instead of querying. That turns two repeated queries
 * into zero reads, and means every part of the worker is looking at exactly the
 * same view of the house.
 */
const devices = new Map();

/**
 * Per-device memory of the last state we saw.
 *
 * A snapshot always carries the whole document, so comparing against this is
 * how a document becomes an *edge*. `turnedOnAt` is remembered too because the
 * OFF write clears it -- by the time we see the transition, the field that
 * tells us how long the device ran is already gone from the document.
 */
const lastSeen = new Map();

let firstSnapshot = true;

async function handleChange(change) {
  const device = { id: change.doc.id, ...change.doc.data() };

  if (change.type === 'removed') {
    safety.disarm(device.id);
    devices.delete(device.id);
    lastSeen.delete(device.id);
    return;
  }

  devices.set(device.id, device);

  const previous = lastSeen.get(device.id);
  const turnedOnAt = toDate(device.turnedOnAt);

  lastSeen.set(device.id, {
    status: device.status,
    // Keep the last known start time across the OFF write that nulls it.
    turnedOnAt: turnedOnAt || (previous ? previous.turnedOnAt : null),
  });

  // First sight of this device. We do not know what happened while the worker
  // was down, so do not invent an edge -- just arm whatever is running now.
  if (previous === undefined) {
    safety.arm(device);
    return;
  }

  const wasOn = previous.status === STATUS.on;
  const isOn = device.status === STATUS.on;

  if (!wasOn && isOn) {
    await usage.recordOn(device);
    safety.arm(device);
  } else if (wasOn && !isOn) {
    const startedAt = previous.turnedOnAt;
    const seconds = startedAt
      ? Math.max(0, Math.round((Date.now() - startedAt.getTime()) / 1000))
      : null;

    await usage.recordOff(
      device,
      seconds,
      device.statusReason === REASON.safetyCutoff
    );
    safety.disarm(device.id);
  } else if (isOn) {
    // Still on, but something changed -- possibly the safety budget. Re-arming
    // recomputes the deadline from the current values.
    safety.arm(device);
  }

  // Faults are reported by the simulator. Surface each one once, on the edge,
  // rather than on every subsequent snapshot of the same document.
  if (previous.status !== STATUS.error && device.status === STATUS.error) {
    await usage.recordFault(device, USAGE_EVENT.error);
    await raiseAlert({
      type: ALERT_TYPE.deviceError,
      severity: SEVERITY.critical,
      deviceId: device.id,
      deviceName: device.name,
      message: `${device.name} reported a fault.`,
    });
  }
}

function watchDevices() {
  return db()
    .collection(COLLECTIONS.devices)
    .onSnapshot(
      async (snap) => {
        for (const change of snap.docChanges()) {
          try {
            await handleChange(change);
          } catch (err) {
            log(`device change failed (${change.doc.id}): ${err.message}`);
          }
        }

        if (firstSnapshot) {
          firstSnapshot = false;
          log(
            `watching ${snap.size} devices, ` +
              `${safety.armedCount()} safety timer(s) armed`
          );
        }
      },
      (err) => {
        // Losing the listener silently would be the worst possible failure:
        // safety cutoffs would simply stop happening, with nothing to show it.
        log(`FATAL: device listener died: ${err.message}`);
        process.exit(1);
      }
    );
}

async function main() {
  init();
  log('Smart Nest worker starting');

  const unsubscribe = watchDevices();

  const deviceList = () => Array.from(devices.values());
  await scheduler.start(deviceList);
  heartbeat.start(deviceList);

  log('worker ready');

  const shutdown = () => {
    log('shutting down');
    unsubscribe();
    scheduler.stop();
    heartbeat.stop();
    safety.disarmAll();
    process.exit(0);
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
