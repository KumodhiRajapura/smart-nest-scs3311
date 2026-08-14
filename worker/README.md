# Smart Nest backend worker

The server-side half of the system: a Node process holding one Firestore
listener and two timers.

It exists because the phone cannot be trusted with safety. An app that has been
swiped out of the recents list cannot switch off an iron that has been on for
half an hour — so the rule that does that lives here, outside the app, where
nothing the user does to their phone can stop it.

Schema: [`firebase/SCHEMA.md`](../firebase/SCHEMA.md).

## What it does

| Job | Trigger | Effect |
|---|---|---|
| **Usage tracking** | any status transition | writes a `usage_logs` row with the duration |
| **Safety cutoff** | `maxOnDurationMinutes` expires | writes `status: off`, raises an alert, pushes FCM |
| **Scheduling** | wall clock hits `scheduleStartTime` / `scheduleEndTime` | switches the device |
| **Presence** *(opt-in)* | `lastHeartbeat` goes stale | marks the device `disconnected` |

## Setup

```bash
cd worker
npm install
cp .env.example .env
```

Then download the service account key:

**Firebase console → Project settings → Service accounts → Generate new private
key** → save as `worker/serviceAccount.json`.

That file is git-ignored and must stay that way — it bypasses every security
rule in the project.

## Run

```bash
npm run seed     # demo house: 2 floors, 7 rooms, 10 devices
npm start        # the worker itself
```

Leave `npm start` running in its own terminal:

```
[14:02:11] Smart Nest worker starting
[14:02:12] watching 10 devices, 0 safety timer(s) armed
[14:02:12] scheduler running every 20s (TZ=Asia/Colombo, catch-up off)
[14:02:12] heartbeat watchdog disabled (set HEARTBEAT_TIMEOUT_SECONDS to enable)
[14:02:12] worker ready
[14:03:04] usage: Clothes Iron -> on
[14:03:04] safety: Clothes Iron armed, 120s remaining
[14:05:04] SAFETY CUTOFF: Clothes Iron after 2 min
[14:05:04] alert: safety_cutoff -- Clothes Iron was switched off automatically…
[14:05:04] push sent to topic "alerts"
[14:05:05] usage: Clothes Iron -> auto_off_safety after 121s
```

## Design notes worth defending

**The countdown is derived, not stored.** Nothing persists "90 seconds left".
`turnedOnAt + maxOnDurationMinutes` is the deadline, recomputed whenever the
worker sees the device. Kill the worker mid-session and restart it: it re-arms
with the correct remaining time rather than granting a fresh budget.

**Transitions, not commands.** The worker never learns that "the user pressed a
button". It compares each snapshot against the last status it saw, so a device
switched on from the phone, from the simulator, by a schedule, or by hand in the
Firestore console is measured and protected identically.

**One in-memory view of the house.** The snapshot listener maintains a device
cache that the scheduler and the heartbeat watchdog read from, instead of each
running its own query every tick. Two repeated queries become zero reads, and
every part of the worker sees exactly the same state.

**Schedules are edge-triggered.** The worker acts on the minute a window opens
and the minute it closes, and ignores the time in between. That is what lets you
override a scheduled light by hand without the worker switching it straight
back — the next boundary takes over again. `SCHEDULE_CATCHUP=true` additionally
applies windows that were already open at startup.

**The cutoff runs in a transaction.** It re-reads `turnedOnAt` before writing
and stands down if the session it was armed for is already over — otherwise
someone who switched the iron off and straight back on would have the *old*
timer cut off their *new* session.

**One writer for usage logs.** Only the worker writes `usage_logs`, and
`firestore.rules` denies that collection to every client. Sessions cannot be
duplicated by two clients reacting to one change, and usage cannot be faked from
a phone.

## Configuration

See [`.env.example`](.env.example). The two that matter:

- `TZ` — schedules are wall-clock times. This process must run in the timezone
  they were written in.
- `HEARTBEAT_TIMEOUT_SECONDS` — leave at `0` until the simulator is running.
  With it enabled and nothing sending heartbeats, every device goes
  `disconnected` within a minute.

## Known limits

- Runs on one machine. If the laptop sleeps, cutoffs do not fire. Everything
  else — control, sync, the UI — keeps working, because the worker is a
  participant in the database rather than a proxy in front of it.
- Timers live in memory. A restart re-arms them from Firestore correctly, but a
  cutoff that came due *during* the downtime fires when the worker comes back,
  not at the moment it was due.
- Usage is tracked per device, not per child switch. A gang box logs one session
  for the unit; "how long was the exhaust fan on?" is not answerable from the
  current schema.

## Relationship to `firebase/functions_index.ts`

That file is an earlier Cloud Functions sketch of the same rules. It is **not
deployed** and is not what runs — this worker is. Cloud Functions require the
Blaze plan, which the team chose not to use. If that changes, the logic in
`src/safety.js` is already trigger-shaped and ports across directly.
