'use strict';

const { db, FieldValue, log } = require('./firebase');
const { COLLECTIONS, USAGE_EVENT } = require('./constants');

function logsRef() {
  return db().collection(COLLECTIONS.usageLogs);
}

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
