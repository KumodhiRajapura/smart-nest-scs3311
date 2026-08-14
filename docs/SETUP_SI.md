# Smart Nest — Setup Guide (සිංහල)

Member 2 (Firebase & Backend) — මුල ඉඳන් අන්තිමට.

පියවර 10ක්. පිළිවෙලට කරන්න — එකක් මඟ ඇරියොත් ඊළඟ එක වැඩ කරන්නේ නෑ.

---

## පියවර 0 — Flutter වැඩද කියලා බලන්න

```powershell
flutter --version
flutter doctor
```

`flutter doctor` එකේ මේ දෙකට ✓ තියෙන්න ඕන:

```
[√] Flutter
[√] Android toolchain - develop for Android devices
```

- **`[X] Visual Studio`** → **නොසලකා හරින්න.** ඒක Windows desktop apps වලට විතරයි.
- **`Android sdkmanager not found`** → Android Studio → **Tools → SDK Manager** →
  **SDK Tools** tab → **Android SDK Command-line Tools (latest)** ✅ → Apply.
  ඊට පස්සේ `flutter doctor --android-licenses` (හැම එකකටම `y`).

---

## පියවර 1 — Firebase project එක

[console.firebase.google.com](https://console.firebase.google.com) → **Add project**

- නම: `smart-nest-app`
- Google Analytics: **off** (ඕන නෑ)
- **Create project** → විනාඩියක් ඉන්න

### දැනටමත් project එකක් හදලා නම්

⚙️ → **Project settings** → **Project ID** එක බලන්න.

`smart-nest-app` නොවේ නම් කමක් නෑ — පියවර 6 එකේ `firebase use --add` කරාම
`.firebaserc` එක ඉබේම හරි වෙනවා. **ඒත් ඒ ID එක ලියාගන්න**, පියවර 4ට ඕන.

---

## පියවර 2 — Services enable කරන්න

### (අ) Firestore

1. **Build → Firestore Database** → **Create database**
2. Database ID: `(default)` — එහෙමම තියන්න
3. Location: **`asia-south1` (Mumbai)**
   > ⚠️ **පස්සේ වෙනස් කරන්න බෑ.** එක පාරයි දාන්න පුළුවන්.
4. **Start in test mode** → **Create**

✅ හිස් table එකක් + `Start collection` button එකක් පේනවා.

### (ආ) Authentication — **දෙකක්** ඕන

**Build → Authentication → Get started** → **Sign-in method** tab:

| Provider | ඇයි |
|---|---|
| **Email/Password** ✅ | App එකට sign in වෙන්න. නැත්නම් sign-in screen එකෙන් එහාට යන්න බෑ |
| **Anonymous** ✅ | Simulator එකට. ඒක anonymous විදිහට තමයි sign in වෙන්නේ |
| Google *(optional)* | Web එකට විතරයි |

> ⚠️ **Google button එක Android එකේ වැඩ කරන්නේ නෑ** — `auth_service.dart:78`
> එකේ mobile එකට `return null` කරලා තියෙනවා. **Email/Password අනිවාර්යයි.**

✅ දෙකටම ඉස්සරහින් **Enabled**.

### (ඇ) Cloud Messaging

කරන්න දෙයක් නෑ — default එකෙන්ම on.
බලන්න නම්: ⚙️ → Project settings → **Cloud Messaging** → Sender ID එකක් තියෙනවා නම් හරි.

## පියවර 3 — CLI tools

```powershell
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
```

`firebase login` කරාම browser එකක් open වෙනවා → Google account එකෙන් sign in.

`flutterfire` හම්බ නොවුණොත් මේක PATH එකට දාන්න:

```
%LOCALAPPDATA%\Pub\Cache\bin
```

---

## පියවර 4 — App එක Firebase එකට connect

Project folder එකේ ඉඳන් (`smart-nest-app` වෙනුවට ඔයාගේ project ID එක):

```powershell
flutterfire configure --project=smart-nest-app
```

- Platform ලැයිස්තුවෙන් **android** සහ **web** තෝරන්න (space = select, enter = confirm)
- iOS ඕන නෑ (Mac එකක් නැත්නම්)

මේකෙන් වෙන දේ:

- `lib/firebase_options.dart` එකේ `REPLACE_ME` ඔක්කොම real keys වලින් replace වෙනවා
- `android/app/google-services.json` හැදෙනවා

✅ **හරි ගියාද:**

```powershell
findstr REPLACE_ME lib\firebase_options.dart
```

කිසිත් නොආවොත් හරි. `REPLACE_ME` ආවොත් තාම වැඩ නෑ.

---

## පියවර 5 — Dependencies + Tests

```powershell
flutter pub get
flutter test
```

> **`flutter pub add` කරන්න එපා.** Packages ඔක්කොම දැනටමත් `pubspec.yaml` එකේ
> තියෙනවා — `firebase_core`, `cloud_firestore`, `firebase_auth`,
> `firebase_messaging`, `flutter_local_notifications`.

Tests වලට Firebase ඕන නෑ, ඒ නිසා දැන්ම run කරන්න පුළුවන්.

✅ `All tests passed!`

---

## පියවර 6 — Rules සහ Indexes deploy

```powershell
firebase use --add
```

→ ලැයිස්තුවෙන් ඔයාගේ project එක තෝරන්න → alias එකට `default`
*(මේකෙන් `.firebaserc` එකත් හරි වෙනවා)*

```powershell
firebase deploy --only firestore:rules,firestore:indexes
```

> ⚠️ **වැදගත් 2ක්:**
> 1. Test mode දවස් 30කින් expire වෙනවා. ඒකට කලින් deploy කරන්න — නැත්නම්
>    app එක හදිස්සියේ නවතිනවා, ඒක code bug එකක් වගේ පේනවා.
> 2. Deploy කළාට පස්සේ **sign in වෙන්නේ නැතුව data කියවන්න බෑ.** ඒක හරි.

---





## පියවර 7 — Worker එක

### Service account key

1. ⚙️ → **Project settings** → **Service accounts** tab
2. **Generate new private key** → **Generate key** → JSON එකක් download වෙනවා
3. **rename** කරලා `serviceAccount.json`, `worker/` folder එකට දාන්න

> 🔒 මේ file එක GitHub එකට **කවදාවත්** push කරන්න එපා. ඒකෙන් security rules
> ඔක්කොම bypass කරලා full admin access දෙනවා. (`.gitignore` එකේ දාලා තියෙනවා.)

### Run

```powershell
cd worker
npm install
copy .env.example .env
npm run seed
npm start
```

✅ **මෙහෙම එන්න ඕන:**

```
[14:02:11] Smart Nest worker starting
[14:02:12] watching 10 devices, 0 safety timer(s) armed
[14:02:12] scheduler running every 20s (TZ=Asia/Colombo, catch-up off)
[14:02:12] heartbeat watchdog disabled (set HEARTBEAT_TIMEOUT_SECONDS to enable)
[14:02:12] worker ready
```

Firestore console එකේ බලන්න: **`floors` (2), `rooms` (7), `devices` (10)**

**🚫 මේ terminal එක වහන්න එපා.**

---

## පියවර 8 — App එක run

**අලුත් terminal එකක්:**

```powershell
flutter run
```

1. Splash screen එකක්
2. ඊට පස්සේ **Sign-in screen** එකක්
3. Email + password දාලා **Sign up** *(Google button එක Android එකේ වැඩ නෑ)*
4. Home screen එකේ **devices 10** පේන්න ඕන

✅ Device එකක් toggle කරන්න. Worker terminal එකේ:

```
[14:03:04] usage: Porch Light -> on
```

**මේක ආවොත් — Flutter ↔ Firestore integration එක වැඩ** ✅

---

## පියවර 9 — Simulator එක

**තව අලුත් terminal එකක්:**

```powershell
cd web-simulator
npm install
copy .env.example .env
```

`.env` එක open කරලා values දාන්න:

```
VITE_FIREBASE_API_KEY=...
VITE_FIREBASE_AUTH_DOMAIN=smart-nest-app.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=smart-nest-app
VITE_FIREBASE_STORAGE_BUCKET=smart-nest-app.appspot.com
VITE_FIREBASE_MESSAGING_SENDER_ID=...
VITE_FIREBASE_APP_ID=...
```

ඒවා ගන්නේ: **⚙️ → Project settings → General → Your apps → Web app**
*(නැත්නම් `lib/firebase_options.dart` එකේ `static const FirebaseOptions web`
කොටසෙන් copy කරන්න — එකම values)*

```powershell
npm run dev
```

Browser එකේ **http://localhost:5173**

> Vite එක `.env` කියවන්නේ **startup එකේදී විතරයි.** `.env` edit කළොත්
> `npm run dev` restart කරන්න.

✅ Devices room අනුව group වෙලා පේනවා.
❌ Permission error → **Anonymous auth enable කරලා නෑ** (පියවර 2ආ).

---

## පියවර 10 — Sync test

Phone එකයි, browser එකයි, worker terminal එකයි **එකපාරට** පේන විදිහට තියාගන්න.

| # | කරන්න | වෙන්න ඕන |
|---|---|---|
| 1 | Phone එකේ Porch Light on | Browser එකේ තත්පරයකින් update |
| 2 | Browser එකේ device එකක් on | Phone එකේ update |
| 3 | Firestore console එකේ `status` අතින් වෙනස් කරන්න | දෙකේම update |
| 4 | Kitchen Gang Box එකේ **එක switch එකක්** on | ඒක විතරක්; unit එක `ON` |
| 5 | **Iron එක on කරලා විනාඩි 2** | Auto-OFF + notification + *"Switched off by the safety worker"* |
| 6 | Iron on තියෙද්දී **ආපහු on ගහන්න** | Countdown **reset වෙන්නේ නෑ** |
| 7 | Worker Ctrl+C → ආපහු `npm start` (iron on තියෙද්දී) | Countdown ඉතුරු වෙලාවෙන්ම දිගටම |
| 8 | Simulator එකේ **Simulate Disconnect** | Phone එකෙන් toggle කරන්න බෑ |
| 9 | Airplane mode → toggle → ආපහු on | Write එක replay වෙනවා |

**#5, #6, #7 තමයි video එකට ගන්න වටින්නේ** — design එකේ හරිම තැන් පේන්නේ ඒවායින්.

---

## බාධා එන්න පුළුවන් තැන් 3ක්

**1. `notification_service.dart` compile error — ලොකුම risk එක**

`flutter_local_notifications ^22.3.0` කියන්නේ ගොඩක් අලුත් major version එකක්.
`initialize()`, `show()` වගේ ඒවායේ API එක වෙනස් වෙලා තියෙන්න පුළුවන්.
Error එක copy කරලා ගන්න.

**2. `minSdk` error**

`firebase_auth 6.x` එකට minSdk 23 ඕන. Build fail වුණොත්
`android/app/build.gradle.kts` එකේ:

```kotlin
minSdk = 23        // flutter.minSdkVersion වෙනුවට
```

**3. `failed-precondition ... index`**

Error එකේම index එක හදන link එකක් තියෙනවා — ඒක click කරන්න.
(පියවර 6 හරියට කළා නම් මේක එන්නේ නෑ.)

---

## තව ලියවිලි

- `docs/MEMBER2_FIREBASE_BACKEND.md` — technical report (schema, sync, safety)
- `firebase/SCHEMA.md` — canonical schema (හැමෝටම පොදු contract එක)
- `worker/README.md` — worker එකේ design notes
- `web-simulator/README.md` — simulator integration
