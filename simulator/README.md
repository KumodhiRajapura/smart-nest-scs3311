# Simulator ↔ Firestore integration

This folder is the **data layer** for the Hardware Simulator dashboard, not the
dashboard itself. Build the visuals however you like; call this module for
everything that touches the database.

| File | What it is |
|---|---|
| `smart-nest-firestore.js` | The client. Import it, no UI inside. |
| `firebase-config.example.js` | Copy to `firebase-config.js`, paste your web config. |
| `sync-test.html` | A bare test rig for proving sync works. Not the dashboard. |

## Setup

```bash
cd simulator
cp firebase-config.example.js firebase-config.js   # then paste your keys
npx serve .                                        # or: python -m http.server 8000
```

It must be served over `http://`, not opened as a `file://` path — ES module
imports and the Firebase SDK both refuse to load otherwise.

Open `http://localhost:3000/sync-test.html` to check the connection before
wiring anything into your own page.

## The API

```js
import { connectSmartNest, STATUS } from './smart-nest-firestore.js';
import { firebaseConfig } from './firebase-config.js';

const nest = await connectSmartNest(firebaseConfig);

// Read: fires immediately with the current state, then on every change.
const stop = nest.watchDevices(devices => {
  for (const device of devices) {
    // device.status is 'ON' | 'OFF' | 'ERROR' | 'DISCONNECTED'
    paintAppliance(device.id, device.status);
  }
});

// Write: the appliance changed by itself (someone pressed its physical switch)
await nest.reportPower('dev_porch_light', true);
await nest.reportChannel('dev_kitchen_gang', 0, true);   // one gang-box switch
await nest.reportFault('dev_iron', 'thermal sensor open');
await nest.clearFault('dev_iron');

// Presence: stops → the worker marks the device DISCONNECTED
const stopBeats = nest.startHeartbeats(['dev_iron', 'dev_porch_light'], 10000);
```

`watchFloors(cb)` gives you the floor plans and their grid dimensions, if you
want to lay the simulator out like the app does.

## Rules to follow

**Never write a status without maintaining `turnedOnAt`.** The safety worker
computes its countdown from that field. `reportPower` handles it — if you write
`updateDoc` yourself and skip it, the iron's automatic cutoff silently stops
working. That is the single most breakable thing in the system.

**Render from the snapshot, not from the click.** When a button here is pressed,
write to Firestore and let the `watchDevices` callback repaint. Painting
optimistically means the simulator can show a state the database never accepted
— and the whole point of the simulator is that it shows what the database says.

**Do not write `usage_logs` or `alerts`.** Both are worker-owned, and the
security rules reject client writes to them.

**Heartbeats write only `lastHeartbeat`.** They deliberately do not stamp
`updatedBy`, so the app's "last changed by" stays meaningful instead of showing
`simulator` every ten seconds.

## Field reference

Everything the simulator cares about, on a `devices` document:

| Field | Type | Notes |
|---|---|---|
| `name` | string | display name |
| `type` | string | `outlet` · `multiswitch` · `light` · `iron` · `camera` |
| `status` | string | `ON` · `OFF` · `ERROR` · `DISCONNECTED` |
| `channels` | array | `{index, label, isOn}` — gang boxes only |
| `floorId`, `gridX`, `gridY` | | position on the floor grid |
| `maxOnDurationMinutes` | number\|null | safety budget, irons etc. |
| `turnedOnAt` | timestamp\|null | when the current ON session started |
| `streamUrl` | string\|null | cameras |
| `lastHeartbeat` | timestamp | you write this |
| `updatedBy` | string | `app` · `simulator` · `worker` |
| `statusReason` | string | e.g. `manual`, `safety_cutoff`, `schedule` |

## Demo script that shows sync in both directions

1. Phone and simulator side by side, worker running.
2. Toggle the porch light **on the phone** → the simulator lamp lights.
3. Toggle the kitchen gang box **in the simulator** → the phone updates.
4. Switch the iron on, wait 2 minutes → the worker cuts it off, both screens go
   `OFF`, and a push notification lands on the phone.
5. Press **Fault** on a device → both show `ERROR`, and an alert appears.
