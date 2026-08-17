'use strict';

const { toDate, log } = require('./firebase');
const { STATUS, REASON, ALERT_TYPE, SEVERITY } = require('./constants');
const { setStatus } = require('./deviceControl');
const { raiseAlert } = require('./notify');


const TIMEOUT_SECONDS = Number(process.env.HEARTBEAT_TIMEOUT_SECONDS || 0);
const CHECK_SECONDS = Number(process.env.HEARTBEAT_CHECK_SECONDS || 15);

let interval = null;
let getDevices = () => [];

async function check() {
  const cutoff = Date.now() - TIMEOUT_SECONDS * 1000;

  for (const device of getDevices()) {
    const beat = toDate(device.lastHeartbeat);

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
 * @param {() => Array} deviceSource 
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
