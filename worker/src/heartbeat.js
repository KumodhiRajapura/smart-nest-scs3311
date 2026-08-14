'use strict';

const { db, toDate, log } = require('./firebase');
const { COLLECTIONS, STATUS, REASON, ALERT_TYPE } = require('./constants');
const { setStatus } = require('./deviceControl');
const { raiseAlert } = require('./notify');

/**
 * Presence watchdog -- the source of the DISCONNECTED status.
 *
 * The web simulator writes `lastHeartbeat` on a timer for each appliance it is
 * pretending to be. When those stop arriving, the appliance is unreachable and
 * the app should say so rather than showing a stale ON.
 *
 * Off by default. With no simulator running, every device goes DISCONNECTED
 * within a minute, which is correct but makes the app look broken while you are
 * building the UI. Turn it on with HEARTBEAT_TIMEOUT_SECONDS once the simulator
 * is part of the demo.
 */

const TIMEOUT_SECONDS = Number(process.env.HEARTBEAT_TIMEOUT_SECONDS || 0);
const CHECK_SECONDS = Number(process.env.HEARTBEAT_CHECK_SECONDS || 15);

let interval = null;

async function check() {
  const cutoff = Date.now() - TIMEOUT_SECONDS * 1000;

  const snap = await db().collection(COLLECTIONS.devices).get();

  for (const doc of snap.docs) {
    const device = { id: doc.id, ...doc.data() };
    const beat = toDate(device.lastHeartbeat);

    // A device that has never reported in is not "lost" -- it was never
    // claimed by the simulator in the first place.
    if (!beat) continue;

    const stale = beat.getTime() < cutoff;
    const marked = device.status === STATUS.disconnected;

    if (stale && !marked) {
      await setStatus({
        deviceId: device.id,
        status: STATUS.disconnected,
        reason: REASON.heartbeatLost,
      });
      log(`heartbeat: ${device.name} went DISCONNECTED`);

      await raiseAlert({
        type: ALERT_TYPE.deviceOffline,
        deviceId: device.id,
        deviceName: device.name,
        message: `${device.name} stopped responding.`,
      });
    } else if (!stale && marked) {
      // Recovery: the simulator is reporting again. Come back OFF rather than
      // guessing at the state the appliance was in when it vanished.
      await setStatus({
        deviceId: device.id,
        status: STATUS.off,
        reason: 'heartbeat_recovered',
      });
      log(`heartbeat: ${device.name} is back`);
    }
  }
}

function start() {
  if (TIMEOUT_SECONDS <= 0) {
    log('heartbeat watchdog disabled (set HEARTBEAT_TIMEOUT_SECONDS to enable)');
    return;
  }

  interval = setInterval(() => {
    check().catch((err) => log(`heartbeat check failed: ${err.message}`));
  }, CHECK_SECONDS * 1000);

  log(
    `heartbeat watchdog running: DISCONNECTED after ${TIMEOUT_SECONDS}s silence`
  );
}

function stop() {
  if (interval) clearInterval(interval);
  interval = null;
}

module.exports = { start, stop, check };
