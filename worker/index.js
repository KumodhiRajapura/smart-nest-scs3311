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

const devices = new Map();

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

    turnedOnAt: turnedOnAt || (previous ? previous.turnedOnAt : null),
  });

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

    safety.arm(device);
  }

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
