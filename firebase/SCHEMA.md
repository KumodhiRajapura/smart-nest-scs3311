# Smart Nest — Firestore Schema (Canonical)

This is the contract. The mobile app (Member 1), the web simulator (Member 3)
and the backend worker (Member 2) all read and write these exact collection and
field names. A rename is a three-file change:

| Client | Constants file |
|---|---|
| Flutter app | `lib/config/firestore_paths.dart` |
| Web simulator | `web-simulator/src/services/firebase.ts` |
| Backend worker | `worker/src/constants.js` |

If a change is necessary, agree it with the team and update all four places
together — a mismatch is invisible until a field silently stops arriving.

---

## Design decisions worth knowing

**One shared house — no `ownerId`.** Every signed-in user sees the same devices.
Scoping documents per user would make the simulator unable to mirror the app at
all: it signs in anonymously and reads the whole `devices` collection, so a
device filtered by someone else's uid simply would not exist for it. The
backend worker has the same problem — it enforces safety across every device in
the project. A smart home is not a per-user inbox.

**Everything is top-level.** A device belongs to a room by `roomId`, not by
nesting. That makes "every device in the house" one query, which is exactly what
the worker listens to and what the simulator renders.

**`turnedOnAt` is the load-bearing field.** The safety countdown is derived from
it — `turnedOnAt + maxOnDurationMinutes` is the deadline, recomputed whenever
the worker sees the device. Nothing stores "90 seconds remaining", so restarting
the worker mid-session re-arms with the correct remaining time instead of
granting a fresh budget.

Every writer must maintain it identically:

- set it (server timestamp) **only** on a genuine OFF → ON transition
- **never** refresh it on a device that is already ON — that hands a running
  iron a brand new safety budget and the cutoff never fires
- clear it to `null` on OFF

**Status is lowercase on the wire.** `on` / `off` / `error` / `disconnected`.
The UI uppercases for display, which is what the specification shows.

---

## Collections

### `floors/{floorId}`

| Field | Type | Notes |
|---|---|---|
| `id` | string | document id, denormalised |
| `name` | string | "Ground Floor" |
| `order` | number | 0 = ground; orders the floor tabs |
| `floorPlanImageUrl` | string \| null | asset path or URL of the plan image |

### `rooms/{roomId}`

| Field | Type | Notes |
|---|---|---|
| `id` | string | |
| `floorId` | string | |
| `name` | string | |
| `gridRow`, `gridCol` | number | cell on the floor's abstract grid |
| `deviceIds` | array\<string\> | denormalised, so a room card shows a count without a second query |

### `devices/{deviceId}`

Common to every device:

| Field | Type | Notes |
|---|---|---|
| `id` | string | |
| `name` | string | |
| `roomId` | string | |
| `floorId` | string | denormalised from the room, so the worker and the floor dashboard can query without a join |
| `type` | string | `outlet` · `multiSwitch` · `scheduledAppliance` · `scheduledLight` · `camera` |
| `status` | string | `on` · `off` · `error` · `disconnected` |
| `statusReason` | string | `manual` · `safety_cutoff` · `schedule` · `heartbeat_lost` · `heartbeat_recovered` · `simulator_fault` |
| `updatedBy` | string | `mobile_app` · `simulator` · `backend_worker` |
| `lastUpdated` | Timestamp | server timestamp, set on every write |
| `lastHeartbeat` | Timestamp \| null | written by the simulator; when it goes stale the worker marks the device `disconnected` |
| `lastAlert` | string \| null | **backend only** — clients must not write |
| `lastAlertAt` | Timestamp \| null | **backend only** |

Type-specific:

| Type | Fields |
|---|---|
| `multiSwitch` | `childSwitches: [{ id, label, isOn }]` |
| `scheduledAppliance` | `maxOnDurationMinutes: number \| null`, `turnedOnAt: Timestamp \| null` |
| `scheduledLight` | `scheduleStartTime: "HH:mm"`, `scheduleEndTime: "HH:mm"`, `scheduleDays: number[] \| null`, `scheduleEnabled: boolean` |
| `camera` | `cameraImageUrls: string[] \| null` |

Notes on the schedule fields:

- `scheduleDays` holds ISO weekdays, **Monday = 1 … Sunday = 7**, matching
  Dart's `DateTime.weekday`. Null or empty means every day.
- `scheduleEnabled` absent is treated as enabled, so documents written before
  the flag existed keep running.
- Times are wall-clock strings, not timestamps: "on at 18:30" means 18:30 every
  evening. The worker must therefore run in the timezone the schedules were
  written in — `TZ=Asia/Colombo`.

**A gang box is one document, not N.** Five switches live in `childSwitches` on
a single device, which is what the specification asks for and what keeps one
device in one cell of the floor grid. The unit's `status` is `on` while any
child is on. The cost is that updating one switch rewrites the array, so those
writes run in a **transaction** — without one, two people flipping switch 1 and
switch 3 at the same moment would each write back a copy that discards the
other's change.

### `usage_logs/{logId}`

One row per transition, written by the backend worker only.

| Field | Type | Notes |
|---|---|---|
| `deviceId`, `deviceName`, `roomId` | string | name denormalised so reports need no join |
| `event` | string | `on` · `off` · `auto_off_safety` · `error` · `disconnected` |
| `timestamp` | Timestamp | |
| `durationOnSeconds` | number \| null | on session-ending events |
| `durationOnMinutes` | number \| null | same figure, rounded — kept for readability |
| `createdBy` | string | `backend_worker` |

Seconds as well as minutes because the demo iron has a **two-minute** budget,
and a report that rounds every session to whole minutes cannot show it
convincingly.

Summing the `off` and `auto_off_safety` rows gives total ON time directly — no
pairing pass needed.

### `alerts/{alertId}`

| Field | Type | Notes |
|---|---|---|
| `deviceId`, `deviceName` | string | |
| `type` | string | `safety_cutoff` · `device_error` · `device_offline` · `schedule_run` |
| `message` | string | |
| `severity` | string | `info` · `warning` · `critical` |
| `createdAt` | Timestamp | |
| `acknowledged` | boolean | the only field a client may change |
| `createdBy` | string | `backend_worker` |

---

## Who may write what

Enforced by `firestore.rules` at the repository root (that is the file
`firebase.json` deploys).

| Collection | Client read | Client write |
|---|---|---|
| `floors` | signed in | signed in |
| `rooms` | signed in | signed in |
| `devices` | signed in | signed in, **closed field list**, valid `status`, never `lastAlert`/`lastAlertAt` |
| `usage_logs` | signed in | **denied** — worker only |
| `alerts` | signed in | only the `acknowledged` field |

The worker uses the Admin SDK, which bypasses rules entirely. That asymmetry is
the design: a collection can be worker-writable and client-read-only at the same
time, and usage history cannot be fabricated or erased from a handset.

Both clients must be **signed in** — the app with email/Google, the simulator
anonymously. Anonymous sign-in has to stay enabled in the Firebase console even
though the app itself never uses it.

## Indexes

Declared in `firestore.indexes.json`. Deploy with
`firebase deploy --only firestore:indexes`.

- `devices` (floorId ASC, name ASC)
- `devices` (roomId ASC, type ASC)
- `usage_logs` (deviceId ASC, timestamp DESC)
- `alerts` (acknowledged ASC, createdAt DESC)
- `alerts` (deviceId ASC, createdAt DESC)

A missing index surfaces as a stream error whose message contains a link that
creates it in one click — which is why none of the query code swallows errors.

## Timezone

Scheduled tasks and safety cutoffs run in **Asia/Colombo**. Set `TZ` in
`worker/.env`.
