# Web Hardware Simulator — Smart Nest

Represents the physical appliances. Listens to Firestore and reflects every
change; writing back is how it pretends someone pressed a switch on the wall.

Schema: [`firebase/SCHEMA.md`](../firebase/SCHEMA.md).

## Quick start

```bash
cd web-simulator
npm install
cp .env.example .env      # then paste your Firebase web config
npm run dev               # http://localhost:5173
```

The web config comes from **Firebase console → Project settings → General →
Your apps → Web app** — the same values `flutterfire configure` wrote into
`lib/firebase_options.dart` under `static const FirebaseOptions web`.

Vite reads `.env` at **startup**, so restart `npm run dev` after editing it.

## Anonymous sign-in is required

`firestore.rules` requires `request.auth != null`. The simulator therefore signs
in anonymously before attaching any listener — `connect()` in
`src/services/firebase.ts` does this, and `Dashboard.tsx` awaits it.

If the dashboard shows a permission error, **Anonymous sign-in is not enabled**
in the Firebase console: Authentication → Sign-in method → Anonymous → Enable.
An unauthenticated simulator does not get an error page from Firestore, it gets
an empty collection — which looks exactly like "there are no devices".

## Architecture

```
src/services/firebase.ts   the Firestore layer  ← Member 2 owns this
src/pages/Dashboard.tsx    listener + layout    ← Member 3 owns this
src/components/DeviceCard.tsx  one appliance    ← Member 3 owns this
```

`firebase.ts` has no UI in it on purpose. The dashboard decides how an appliance
looks; the service decides what it means to write one.

## The API

```ts
import {
  connect, watchDevices, watchRooms, watchFloors,
  reportPower, reportChildSwitch,
  reportFault, reportDisconnected, clearFault,
  nextCameraFrame, heartbeat, startHeartbeats,
} from './services/firebase'

await connect()                                  // sign in — do this first

const stop = watchDevices(devices => render(devices), err => showError(err))

await reportPower('dev_porch_light', true)       // physical switch pressed
await reportChildSwitch('dev_kitchen_gang', 's0', true)
await reportFault('dev_iron', 'thermal sensor open')
await clearFault('dev_iron')

const stopBeats = startHeartbeats(['dev_iron'], 10000)
```

## Rules to follow when extending the UI

**Never write `status` without maintaining `turnedOnAt`.** The safety worker's
countdown is derived from that field. `reportPower` and `reportChildSwitch`
handle it — including the guard that stops a device already ON from having its
clock reset, which would silently disable the iron's cutoff. Call them rather
than `updateDoc` directly.

**Render from the snapshot, not from the click.** Write to Firestore and let the
`watchDevices` callback repaint. Painting optimistically lets the simulator show
a state the database never accepted, and the whole point of the simulator is
that it shows what the database says.

**Do not write `usage_logs`, `alerts`, `lastAlert` or `lastAlertAt`.** All
worker-owned; the security rules reject client writes to them.

**Heartbeats write only `lastHeartbeat`.** They deliberately do not stamp
`updatedBy` — otherwise the app's "last changed by" would read `simulator` every
ten seconds regardless of who actually touched the device.

## Demo script — sync in both directions

Phone, simulator and the worker's terminal all visible at once.

1. Toggle the porch light **on the phone** → the simulator lamp lights.
2. Toggle a gang-box switch **in the simulator** → the phone updates.
3. Switch the iron on, wait 2 minutes → the worker cuts it off, both screens go
   `OFF`, the card shows *"Switched off by the safety worker"*, and a push
   notification lands on the phone.
4. Press **Simulate Error** → both show `ERROR`, and an alert appears.
5. Press **Simulate Disconnect** → the phone refuses to toggle that device.
