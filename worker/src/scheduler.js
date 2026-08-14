'use strict';

const { db, FieldValue, log } = require('./firebase');
const { COLLECTIONS, REASON, SOURCE } = require('./constants');
const { setPower } = require('./deviceControl');

/**
 * Time-of-day automation for lights and anything else with a preset window.
 *
 * Edge-triggered, not level-triggered: the worker acts on the minute a window
 * opens and the minute it closes, and does nothing in between. That is what
 * makes a manual override work -- switch the porch light off at 20:00 and it
 * stays off, instead of being switched back on four seconds later by a worker
 * insisting the window is still open. The next boundary takes over again.
 *
 * Times are wall-clock strings, so this process must run in the same timezone
 * the schedules were written in. Set TZ=Asia/Colombo before starting it.
 */

const TICK_SECONDS = Number(process.env.SCHEDULE_TICK_SECONDS || 20);

/** Windows already open when the worker starts are applied once, if enabled. */
const CATCH_UP = String(process.env.SCHEDULE_CATCHUP || 'false') === 'true';

// `${scheduleId}:${hh:mm}` for boundaries already handled, so a 20-second tick
// does not fire the same boundary three times inside its minute.
let firedThisMinute = new Set();
let currentMinute = '';

let interval = null;

function hhmm(date) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

/** ISO weekday: Monday = 1 ... Sunday = 7, matching Dart's DateTime.weekday. */
function isoWeekday(date) {
  return date.getDay() === 0 ? 7 : date.getDay();
}

function isInWindow(schedule, now) {
  const toMinutes = (s) => {
    const [h, m] = String(s).split(':').map(Number);
    return (h || 0) * 60 + (m || 0);
  };
  const start = toMinutes(schedule.startTime);
  const end = toMinutes(schedule.endTime);
  const at = now.getHours() * 60 + now.getMinutes();

  // 22:00 -> 06:00 wraps past midnight.
  return end <= start ? at >= start || at < end : at >= start && at < end;
}

async function applySchedule(doc, on) {
  const schedule = doc.data();

  await setPower({
    deviceId: schedule.deviceId,
    on,
    channelIndex:
      schedule.channelIndex === undefined ? null : schedule.channelIndex,
    reason: REASON.schedule,
    source: SOURCE.worker,
  });

  await doc.ref.update({ lastRunAt: FieldValue.serverTimestamp() });

  log(
    `schedule: ${schedule.label || doc.id} -> ${on ? 'ON' : 'OFF'} ` +
      `(device ${schedule.deviceId})`
  );
}

async function tick() {
  const now = new Date();
  const minute = hhmm(now);
  const weekday = isoWeekday(now);

  if (minute !== currentMinute) {
    currentMinute = minute;
    firedThisMinute = new Set();
  }

  const snap = await db()
    .collection(COLLECTIONS.schedules)
    .where('enabled', '==', true)
    .get();

  for (const doc of snap.docs) {
    const schedule = doc.data();
    const days = Array.isArray(schedule.daysOfWeek)
      ? schedule.daysOfWeek
      : [1, 2, 3, 4, 5, 6, 7];

    if (!days.includes(weekday)) continue;

    const key = `${doc.id}:${minute}`;
    if (firedThisMinute.has(key)) continue;

    if (schedule.startTime === minute) {
      firedThisMinute.add(key);
      await applySchedule(doc, true);
    } else if (schedule.endTime === minute) {
      firedThisMinute.add(key);
      await applySchedule(doc, false);
    }
  }
}

/** Apply the state implied by any window that is already open. */
async function catchUp() {
  const now = new Date();
  const weekday = isoWeekday(now);

  const snap = await db()
    .collection(COLLECTIONS.schedules)
    .where('enabled', '==', true)
    .get();

  for (const doc of snap.docs) {
    const schedule = doc.data();
    const days = Array.isArray(schedule.daysOfWeek)
      ? schedule.daysOfWeek
      : [1, 2, 3, 4, 5, 6, 7];

    if (!days.includes(weekday)) continue;
    if (!isInWindow(schedule, now)) continue;

    log(`schedule: catching up ${schedule.label || doc.id}`);
    await applySchedule(doc, true);
  }
}

async function start() {
  if (CATCH_UP) {
    await catchUp().catch((err) => log(`catch-up failed: ${err.message}`));
  }

  await tick().catch((err) => log(`schedule tick failed: ${err.message}`));

  interval = setInterval(() => {
    tick().catch((err) => log(`schedule tick failed: ${err.message}`));
  }, TICK_SECONDS * 1000);

  log(
    `scheduler running every ${TICK_SECONDS}s ` +
      `(TZ=${process.env.TZ || 'system default'}, catch-up ${CATCH_UP ? 'on' : 'off'})`
  );
}

function stop() {
  if (interval) clearInterval(interval);
  interval = null;
}

module.exports = { start, stop, tick, isInWindow };
