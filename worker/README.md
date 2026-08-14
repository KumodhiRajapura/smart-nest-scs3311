# Smart Nest backend worker

The server-side half of the system. A Node process holding a Firestore listener
and two timers.

It exists because the phone cannot be trusted with safety. An app that has been
swiped out of the recents list cannot switch off an iron that has been on for
half an hour — so the rule that does that lives here, outside the app, where
nothing the user does to their phone can stop it.

## What it does

| Job | Trigger | Effect |
|---|---|---|
| **Usage tracking** | any `ON`/`OFF` transition | opens/closes a `usage_logs` session |
| **Safety cutoff** | `maxOnDurationMinutes` expires | writes `status: OFF`, raises an alert, pushes FCM |
| **Scheduling** | wall clock hits `startTime` / `endTime` | switches the device or one gang-box channel |
| **Heartbeat watchdog** *(opt-in)* | `lastHeartbeat` goes stale | marks the device `DISCONNECTED` |

## Setup

```bash
cd worker
npm install
cp .env.example .env
```

Then download the service account key:

**Firebase console → Project settings → Service accounts → Generate new private
key** → save as `worker/serviceAccount.json`.

That file is git-ignored, and it must stay that way — it bypasses every
security rule in the project.

## Run

```bash
npm run seed     # demo house: 2 floors, 10 devices, 3 schedules
npm start        # the worker itself
```

Leave `npm start` running in its own terminal. Output looks like:

```
[14:02:11] Smart Nest worker starting
[14:02:12] watching 10 devices, 0 safety timer(s) armed
[14:02:12] scheduler running every 20s (TZ=Asia/Colombo, catch-up off)
[14:02:12] worker ready
[14:03:04] usage: opened session for Clothes Iron
[14:03:04] safety: Clothes Iron armed, 120s remaining
[14:05:04] SAFETY CUTOFF: Clothes Iron after 2 min
[14:05:04] alert: safety_cutoff -- Clothes Iron was switched off automatically…
[14:05:05] usage: closed session for Clothes Iron after 121s
```

## Design notes worth defending

**The countdown is derived, not stored.** Nothing persists "90 seconds left".
`turnedOnAt + maxOnDurationMinutes` is the deadline, recomputed whenever the
worker sees the device. Kill the worker mid-session and restart it: it re-arms
with the correct remaining time instead of granting a fresh budget.

**Transitions, not commands.** The worker never learns that "the user pressed a
button". It compares each snapshot against the last status it saw. So a device
switched on from the phone, from the simulator, by a schedule, or by hand in the
Firestore console is measured and protected identically.

**Schedules are edge-triggered.** The worker acts on the minute a window opens
and the minute it closes, and ignores the time in between. That is what lets you
override a scheduled light by hand without the worker switching it straight back
— the next boundary takes over again. `SCHEDULE_CATCHUP=true` additionally
applies windows that were already open at startup.

**The cutoff runs in a transaction.** It re-reads `turnedOnAt` before writing,
so a cutoff armed for a session the user has already ended cannot land on the
new one.

**One writer for usage logs.** Only the worker writes `usage_logs`, and
`firestore.rules` denies that collection to every client. Sessions cannot be
duplicated by two clients reacting to the same change, and usage cannot be
faked from a phone.

## Configuration

See [.env.example](.env.example). The two that matter:

- `TZ` — schedules are wall-clock times. This process must run in the timezone
  the schedules were written in.
- `HEARTBEAT_TIMEOUT_SECONDS` — leave at `0` until the simulator is running.
  With it enabled and nothing sending heartbeats, every device goes
  `DISCONNECTED` within a minute.

## Known limits

- Runs on one machine. If the laptop sleeps, cutoffs do not fire. The same code
  moves to Cloud Functions if the project is on the Blaze plan — the logic in
  `src/safety.js` is trigger-shaped already.
- Timers live in memory. A restart re-arms them from Firestore (correctly), but
  a cutoff due *during* the downtime fires late, when the worker comes back.
