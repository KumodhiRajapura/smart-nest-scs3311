# Setup — from a fresh clone to a running demo

Three processes make up the system, and all three talk only to Firestore:

| Part | Where | Needed for |
|---|---|---|
| Flutter app | repo root | the phone UI |
| Node worker | `worker/` | safety cutoffs, schedules, usage logs, push alerts |
| Web simulator | `web-simulator/` | pretending to be the hardware |

The app alone will run once step 3 is done. The worker and simulator are what
make the sync and safety demos possible.

---

## 0. Tools

Already on this machine: Flutter 3.47, Node 24, npm 11.

Still to install:

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
```

`flutterfire` lands in `%LOCALAPPDATA%\Pub\Cache\bin` — if the command is not
found afterwards, add that folder to `PATH` and open a new terminal.

---

## 1. Firebase console

At [console.firebase.google.com](https://console.firebase.google.com), in your
project:

1. **Firestore Database** → *Create database* → start in **test mode** → region
   `asia-south1`.
2. **Authentication** → *Get started* → enable **two** providers:
   - **Email/Password** — the app's sign-in screen uses it.
   - **Anonymous** — the web simulator needs an identity, because
     `firestore.rules` denies every unauthenticated read.
3. **Cloud Messaging** is on by default — nothing to do.

Do not add the Android app by hand here. Step 2 registers it for you with the
right package name.

---

## 2. Connect the Flutter app

From the repo root:

```bash
flutterfire configure
```

- Pick your project from the list.
- Select platforms: **android** and **web**.
- Android package name must be exactly **`com.example.smart_nest_app`** (it
  matches `android/app/build.gradle.kts`). A mismatch builds and runs fine but
  never delivers a notification, with no error explaining why.

This overwrites `lib/firebase_options.dart` (the checked-in version is a
placeholder that throws a readable error) and writes
`android/app/google-services.json`.

Then:

```bash
flutter pub get
flutter run
```

---

## 3. Rules and indexes

`.firebaserc` currently points at a project name that is probably not yours.
Repoint it and deploy:

```bash
firebase login
firebase use --add          # pick your project, alias it "default"
firebase deploy --only firestore:rules,firestore:indexes
```

Deploy these before test mode expires (30 days after the project is created),
or everything starts failing in a way that looks like a code bug.

---

## 4. Worker

```bash
cd worker
npm install
cp .env.example .env
```

Then Firebase console → **Project settings → Service accounts → Generate new
private key**, and save the downloaded file as `worker/serviceAccount.json`.
It is git-ignored on purpose: it bypasses every security rule.

```bash
npm run seed      # creates the demo house: floors, rooms, devices
npm start
```

Leave it running. It is what turns the iron off, applies schedules, writes
`usage_logs`, and pushes FCM alerts.

Two settings in `.env` worth knowing:

- `HEARTBEAT_TIMEOUT_SECONDS=0` — the watchdog is off by default. Turn it on
  only once the simulator is running, or every device goes `disconnected`.
- `TZ=Asia/Colombo` — schedules are wall-clock strings, so the worker must
  agree with the timezone they were written in.

---

## 5. Web simulator

```bash
cd web-simulator
npm install
```

Paste your **web** config into the `firebaseConfig` object in
[web-simulator/src/services/firebase.ts](../web-simulator/src/services/firebase.ts)
— get it from Firebase console → Project settings → your web app.

```bash
npm run dev        # http://localhost:5173
```

> **Known gap:** `firebase.ts` initialises Firestore but never signs in. Once
> the rules from step 3 are deployed, every simulator read returns
> permission-denied. It needs an anonymous sign-in on startup
> (`signInAnonymously` from `firebase/auth`) before the sync demo will work.

---

## 6. Check it works

With the worker running, the simulator open, and the app on a device:

1. Toggle a device in the app → it moves in the simulator in under a second, no
   refresh anywhere.
2. Toggle it in the simulator → the app follows.
3. Switch the iron on and wait past its budget (seeded at 2 minutes) → the
   worker writes `off` with `statusReason: safety_cutoff`, an alert appears,
   and a push notification arrives.

The full 13-row test matrix is in
[MEMBER2_FIREBASE_BACKEND.md §12.3](MEMBER2_FIREBASE_BACKEND.md).

---

## Notes

- **`flutter run -d windows`** needs Windows Developer Mode enabled
  (`start ms-settings:developers`) for plugin symlinks. Android and web do not.
- **`flutter test`** currently fails: `test/schedule_test.dart` and
  `test/usage_summary_test.dart` still import `models/schedule.dart` and
  `services/usage_repository.dart`, which were removed when the repositories
  were merged into `lib/services/*_service.dart`. They need rewriting against
  the current API.
- Without Firebase configured the app still starts — `main.dart` catches the
  init failure and the screens fall back to demo data. If the app looks alive
  but nothing syncs, check the console for
  `Firebase init failed, running in demo mode`.
