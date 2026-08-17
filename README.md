# Smart Nest — SCS 3311 Mini-Project

A cloud-connected Smart Home Monitoring & Control System built for SCS 3311.

## Components

- `lib/` — Flutter mobile application
- `web-simulator/` — React/Vite hardware simulator
- `worker/` — Node.js safety/scheduling/usage worker
- `firebase/` — schema, seed helpers and Firebase documentation
- `assets/` — mock camera and sample floor-plan assets
- `docs/` — technical documentation and demo script

## Requirements implemented

- Multi-floor dashboard with add/rename/delete floor management
- Sample floor-plan layouts with live room-grid overlay
- Reactive ON/OFF/ERROR/DISCONNECTED device states
- Single electrical outlets
- Multi-switch gang boxes with independently addressable switches
- Maximum ON duration for safety-critical appliances
- Scheduled lights
- Mock security camera snapshots
- Firestore bidirectional synchronization
- Server-side safety cutoffs and alerts
- Usage logging and reports
- Web hardware simulator with heartbeat, fault, disconnect and camera simulation

## Flutter

```powershell
flutter pub get
flutter run
```

The camera image is registered in `pubspec.yaml` and is available at:

`assets/images/cameras/front_porch.jpg`

## Hardware simulator

```powershell
cd web-simulator
npm install
copy .env.example .env
npm run dev
```

Enable Anonymous Authentication in Firebase because the simulator signs in anonymously.

## Backend worker

```powershell
cd worker
npm install
copy .env.example .env
npm run seed
npm start
```

Set `TZ=Asia/Colombo` for schedule times. Keep the Firebase service-account key out of Git.

## Important Firebase rule

The deployed rules are the root `firestore.rules` referenced by `firebase.json`. They use the shared-house schema documented in `firebase/SCHEMA.md`; they do not use per-user `ownerId` fields.

## Demo

See:

- `docs/TECHNICAL_DOCUMENTATION.md`
- `docs/DEMO_VIDEO_SCRIPT.md`
