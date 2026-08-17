# Smart Nest — SCS 3311 Technical Documentation

## 1. System overview

Smart Nest is a mobile Smart Home Monitoring & Control System with three cooperating parts:

1. **Flutter mobile client** — floor plans, room/device control, cameras, reports, alerts and authentication.
2. **Web hardware simulator** — represents physical appliances and writes simulated hardware events to Firestore.
3. **Node.js backend worker** — enforces safety cutoffs, schedules, usage logging and heartbeat/disconnection rules.

All three use the same Firestore schema in `firebase/SCHEMA.md`.

## 2. Multi-floor representation

Floors are stored in `floors/{floorId}` and rooms in `rooms/{roomId}`. Each room has `gridRow` and `gridCol`. The mobile client displays a sample floor-plan image and overlays the live room grid on top of it. Floors can be added, renamed and deleted; deleting a floor cascades to its rooms and devices through the Firestore service.

## 3. Device profiles

The `devices` collection supports five device types:

- `outlet` — single ON/OFF control.
- `multiSwitch` — one physical unit containing individually addressable child switches.
- `scheduledAppliance` — safety budget for high-risk appliances such as irons.
- `scheduledLight` — automatic ON/OFF time window.
- `camera` — mock snapshot/URI feed.

Every device exposes `ON`, `OFF`, `ERROR` or `DISCONNECTED` status.

## 4. Synchronization

The Flutter app and web simulator subscribe to Firestore snapshot streams. A write from either client is therefore reflected by the other client without a manual refresh. Device writes maintain `turnedOnAt` on genuine OFF→ON transitions and clear it on OFF transitions.

## 5. Server-side safety

The worker watches device transitions. For a device with `maxOnDurationMinutes`, it derives the cutoff deadline from `turnedOnAt`. When the budget expires it performs a transaction that changes the device to OFF, clears the timer, records the safety reason, creates an alert and sends an FCM notification.

The safety rule is outside the phone UI, so the phone can be closed while the protection remains active.

## 6. Scheduling

Scheduled lights use `scheduleStartTime`, `scheduleEndTime`, `scheduleDays` and `scheduleEnabled`. The worker evaluates schedule boundaries in `Asia/Colombo` and writes device state changes to Firestore.

## 7. Usage reporting

The worker records state transitions in `usage_logs`. The Flutter reports screen reads these worker-owned logs and presents usage summaries/charts. Clients cannot fabricate usage rows.

## 8. Security

The root `firestore.rules` uses authenticated access for floors, rooms and devices, validates device status and blocks client writes to worker-owned alert/usage fields. The web simulator signs in anonymously, while the mobile app uses the normal authentication gate.

## 9. Camera demo

`assets/images/cameras/front_porch.jpg` is the mobile mock snapshot. The web simulator serves the same image from `web-simulator/public/mock-cameras/front_porch.jpg`. The project deliberately does not require a physical camera because the specification explicitly permits mock snapshots / mock URI streams.

## 10. Demo flow

1. Open the mobile app and sign in.
2. Open **Floors** and select Ground Floor.
3. Show the floor-plan background with the room grid overlay.
4. Open a room and toggle an outlet.
5. Open a gang box and toggle individual child switches.
6. Set the iron safety budget and switch it on.
7. Open the simulator and demonstrate the same device changing state.
8. Trigger a simulated fault/disconnect and show the mobile status/alert.
9. Demonstrate the camera snapshot.
10. Show the worker cutting off the iron and the usage report recording the event.
