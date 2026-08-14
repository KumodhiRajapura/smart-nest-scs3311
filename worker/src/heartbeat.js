'use strict';

const { toDate, log } = require('./firebase');
const { STATUS, REASON, ALERT_TYPE, SEVERITY } = require('./constants');
const { setStatus } = require('./deviceControl');
const { raiseAlert } = require('./notify');

/**
 * Presence watchdog -- the source of the DISCONNECTED status.
 *
 * The web simulator writes `lastHeartbeat` on a timer for each appliance it is
 * pretending to be. When those stop arriving the appliance is unreachable, and
 * the app should say so rather than showing a stale ON that nobody is
 * maintaining.
 *
 * Off by default. With no simulator running, every device would go DISCONNECTED
 * within a minute -- correct, but it makes the app look broken while the UI is
 * still being built. Set HEARTBEAT_TIMEOUT_SECONDS once the simulator is part
 * of the demo.
 */

const TIMEOUT_SECONDS = Number(process.env.HEARTBEAT_TIMEOUT_SECONDS || 0);
const CHECK_SECONDS = Number(process.env.HEARTBEAT_CHECK_SECONDS || 15);

let interval = null;
let getDevices = () => [];

async function check() {
  const cutoff = Date.now() - TIMEOUT_SECONDS * 1000;

  for (const device of getDevices()) {
    const beat = toDate(device.lastHeartbeat);

    // A device that has never reported in is not "lost" -- it was never claimed
    // by the simulator in the first place.
    if (!beat) continue;

    const stale = beat.getTime() < cutoff;
    const marked = device.status === STATUS.disconnected;

    try {
      if (stale && !marked) {
        await setStatus({
          deviceId: device.id,
          status: STATUS.disconnected,
          reason: REASON.heartbeatLost,
        });
        log(`heartbeat: ${device.name} went DISCONNECTED`);

        await raiseAlert({
          type: ALERT_TYPE.deviceOffline,
          severity: SEVERITY.warning,
          deviceId: device.id,
          deviceName: device.name,
          message: `${device.name} stopped responding.`,
        });
      } else if (!stale && marked) {
        // Recovery comes back OFF, not to whatever it was doing before. The
        // system does not know what the appliance did while it was unreachable,
        // and ON is the dangerous guess.
        await setStatus({
          deviceId: device.id,
          status: STATUS.off,
          reason: REASON.heartbeatRecovered,
        });
        log(`heartbeat: ${device.name} is back`);
      }
    } catch (err) {
      log(`heartbeat: ${device.id} failed: ${err.message}`);
    }
  }
}

/**
 * @param {() => Array} deviceSource live device list, supplied by index.js
 */
function start(deviceSource) {
  getDevices = deviceSource;

  if (TIMEOUT_SECONDS <= 0) {
    log('heartbeat watchdog disabled (set HEARTBEAT_TIMEOUT_SECONDS to enable)');
    return;
  }

  interval = setInterval(() => {
    check().catch((err) => log(`heartbeat check failed: ${err.message}`));
  }, CHECK_SECONDS * 1000);

  log(`heartbeat watchdog running: DISCONNECTED after ${TIMEOUT_SECONDS}s silence`);
}

function stop() {
  if (interval) clearInterval(interval);
  interval = null;
}

module.exports = { start, stop, check };
