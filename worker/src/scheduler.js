'use strict';

const { log } = require('./firebase');
const { STATUS, REASON, SOURCE } = require('./constants');
const { setPower } = require('./deviceControl');



const TICK_SECONDS = Number(process.env.SCHEDULE_TICK_SECONDS || 20);

const CATCH_UP = String(process.env.SCHEDULE_CATCHUP || 'false') === 'true';

let firedThisMinute = new Set();
let currentMinute = '';

let interval = null;
let getDevices = () => [];

function hhmm(date) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function isoWeekday(date) {
  return date.getDay() === 0 ? 7 : date.getDay();
}

function toMinutes(value) {
  const [h, m] = String(value).split(':').map(Number);
  return (h || 0) * 60 + (m || 0);
}

function hasSchedule(device) {
  if (!device.scheduleStartTime || !device.scheduleEndTime) return false;

  return device.scheduleEnabled !== false;
}

function runsToday(device, now) {
  const days = Array.isArray(device.scheduleDays) ? device.scheduleDays : null;
  if (!days || days.length === 0) return true;
  return days.includes(isoWeekday(now));
}

function isInWindow(device, now) {
  const start = toMinutes(device.scheduleStartTime);
  const end = toMinutes(device.scheduleEndTime);
  const at = now.getHours() * 60 + now.getMinutes();

  // 22:00 -> 06:00 wraps past midnight.
  return end <= start ? at >= start || at < end : at >= start && at < end;
}

async function apply(device, on) {
  await setPower({
    deviceId: device.id,
    on,
    reason: REASON.schedule,
    source: SOURCE.worker,
  });
  log(`schedule: ${device.name} -> ${on ? 'ON' : 'OFF'}`);
}

async function tick() {
  const now = new Date();
  const minute = hhmm(now);

  if (minute !== currentMinute) {
    currentMinute = minute;
    firedThisMinute = new Set();
  }

  for (const device of getDevices()) {
    if (!hasSchedule(device)) continue;
    if (!runsToday(device, now)) continue;

    const key = `${device.id}:${minute}`;
    if (firedThisMinute.has(key)) continue;

    if (device.scheduleStartTime === minute) {
      firedThisMinute.add(key);
      await apply(device, true);
    } else if (device.scheduleEndTime === minute) {
      firedThisMinute.add(key);
      await apply(device, false);
    }
  }
}

/** Apply the state implied by any window that is already open. */
async function catchUp() {
  const now = new Date();

  for (const device of getDevices()) {
    if (!hasSchedule(device)) continue;
    if (!runsToday(device, now)) continue;
    if (!isInWindow(device, now)) continue;
    if (device.status === STATUS.on) continue;

    log(`schedule: catching up ${device.name}`);
    await apply(device, true);
  }
}

/**
 * @param {() => Array} deviceSource live device list, supplied by index.js
 */
async function start(deviceSource) {
  getDevices = deviceSource;

  if (CATCH_UP) {
    await catchUp().catch((err) => log(`catch-up failed: ${err.message}`));
  }

  await tick().catch((err) => log(`schedule tick failed: ${err.message}`));

  interval = setInterval(() => {
    tick().catch((err) => log(`schedule tick failed: ${err.message}`));
  }, TICK_SECONDS * 1000);

  log(
    `scheduler running every ${TICK_SECONDS}s ` +
      `(TZ=${process.env.TZ || 'system default'}, ` +
      `catch-up ${CATCH_UP ? 'on' : 'off'})`
  );
}

function stop() {
  if (interval) clearInterval(interval);
  interval = null;
}

module.exports = { start, stop, tick, isInWindow, hasSchedule };
