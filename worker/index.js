'use strict';

require('dotenv').config();

const { db, init, log } = require('./src/firebase');
const { COLLECTIONS, STATUS, ALERT_TYPE } = require('./src/constants');
const safety = require('./src/safety');
const usage = require('./src/usage');
const scheduler = require('./src/scheduler');
const heartbeat = require('./src/heartbeat');
const { raiseAlert } = require('./src/notify');

/**
 * Smart Nest backend worker.
 *
 * Three jobs, all driven from one Firestore listener plus two timers:
 *
 *   1. usage tracking  -- open and close a session on every ON/OFF edge
 *   2. safety cutoffs  -- switch a device off when its budget expires
 *   3. schedules       -- switch lights on and off at preset times
 *
 * It listens rather than polls, so a change made from the phone or the
 * simulator is reacted to in well under a second. Everything it reacts to is a
 * *state transition*, which is why it does not matter who caused the change.
 */

// deviceId -> last status this process saw. Comparing against it is how a
// snapshot (which always carries the full document) becomes an edge.
const lastStatus = new Map();

let firstSnapshot = true;

async function handleChange(change) {
  const device = { id: change.doc.id, ...change.doc.data() };

  if (change.type === 'removed') {
    safety.disarm(device.id);
    lastStatus.delete(device.id);
    return;
  }

  const previous = lastStatus.get(device.id);
  lastStatus.set(device.id, device.status);

  // First time we have seen this device: we do not know what happened while
  // the worker was down, so repair the ledger instead of inventing an edge.
  if (previous === undefined) {
    await usage.reconcile(device);
    safety.arm(device);
    return;
  }

  const wasOn = previous === STATUS.on;
  const isOn = device.status === STATUS.on;

  if (!wasOn && isOn) {
    await usage.openSession(device);
    safety.arm(device);
  } else if (wasOn && !isOn) {
    await usage.closeSession(device, device.updatedBy);
    safety.disarm(device.id);
  } else if (isOn) {
    // Still on, but something else changed -- possibly the safety budget.
    // Re-arming recomputes the deadline from the current values.
    safety.arm(device);
  }

  // The simulator reports faults by writing ERROR. Surface it once, on the
  // edge, rather than on every subsequent snapshot of the same document.
  if (previous !== STATUS.error && device.status === STATUS.error) {
    await raiseAlert({
      type: ALERT_TYPE.deviceError,
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
        // Losing the listener silently would be the worst possible failure --
        // safety cutoffs would simply stop happening with no sign of it.
        log(`FATAL: device listener died: ${err.message}`);
        process.exit(1);
      }
    );
}

async function main() {
  init();

  log('Smart Nest worker starting');

  const unsubscribe = watchDevices();
  await scheduler.start();
  heartbeat.start();

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
