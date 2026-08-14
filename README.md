# Smart Nest (SCS3311)

A Flutter mobile application built for the **MADD (Mobile Application Design & Development)** module, semester 3.1.

> **Status:** Backend layer built (Firestore, worker, notifications). The app currently opens a debug console; the dashboard UI is in progress.

**Backend / Firebase:** see [docs/MEMBER2_FIREBASE_BACKEND.md](docs/MEMBER2_FIREBASE_BACKEND.md)
for the data model, the synchronisation mechanism, and setup from nothing.
The safety worker lives in [worker/](worker/); the simulator's Firestore client
in [simulator/](simulator/).

> **Before the first run:** the Firebase packages are not in `pubspec.yaml` yet.
> Run `flutter pub add firebase_core cloud_firestore firebase_auth firebase_messaging flutter_local_notifications`
> and `flutterfire configure`, or the build will fail on missing imports.

---

## Project Info

| | |
|---|---|
| Package name | `smart_nest_app` |
| Application ID | `com.example.smart_nest_app` |
| Version | `1.0.0+1` |
| Dart SDK | `^3.12.2` |
| Flutter channel | `stable` |
| Project type | Flutter app |

### Target platforms

Android · iOS · Web · Windows · macOS · Linux

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel, Dart `3.12.2` or newer)
- Android Studio / Xcode / VS Code with the Flutter and Dart plugins
- A connected device or a running emulator/simulator

Check that your toolchain is healthy:

```bash
flutter doctor
```

### Install dependencies

```bash
flutter pub get
```

### Run the app

```bash
# On the default connected device
flutter run

# List available devices first
flutter devices

# Target a specific device
flutter run -d chrome
flutter run -d windows
```

---

## Project Structure

```
smart-nest-scs3311/
├── android/              # Android host project
├── ios/                  # iOS host project
├── web/                  # Web host project
├── windows/ macos/ linux/ # Desktop host projects
├── lib/
│   └── main.dart         # App entry point + root widget
├── test/
│   └── widget_test.dart  # Widget tests
├── analysis_options.yaml # Lint rules (flutter_lints)
├── pubspec.yaml          # Dependencies & assets
└── README.md
```

### `lib/main.dart`

| Element | Description |
|---|---|
| `main()` | Entry point — calls `runApp(const MyApp())` |
| `MyApp` | Root `StatelessWidget`; sets up `MaterialApp` with a `deepPurple` seeded `ColorScheme` |
| `MyHomePage` | `StatefulWidget` home screen with an app bar title |
| `_MyHomePageState` | Holds `_counter` and increments it via `setState` from the floating action button |

---

## Dependencies

**Runtime**

- `flutter` — Flutter SDK
- `cupertino_icons: ^1.0.8` — iOS-style icon set

**Development**

- `flutter_test` — widget/unit testing framework
- `flutter_lints: ^6.0.0` — recommended lint rules

Add a new package with:

```bash
flutter pub add <package_name>
```

---

## Development Commands

```bash
flutter pub get          # Fetch dependencies
flutter analyze          # Static analysis / lints
flutter test             # Run the test suite
dart format .            # Format all Dart source
flutter clean            # Clear build artifacts
```

### Hot reload

While `flutter run` is active:

- `r` — hot reload (keeps app state)
- `R` — hot restart (resets app state)
- `q` — quit

---

## Building for Release

```bash
# Android
flutter build apk --release          # APK
flutter build appbundle --release    # Play Store bundle

# iOS (requires macOS + Xcode)
flutter build ios --release

# Web
flutter build web --release

# Windows
flutter build windows --release
```

---

## Assets and Fonts

Assets are not configured yet. To add them, uncomment and fill in the `assets:` / `fonts:` sections in [pubspec.yaml](pubspec.yaml), then run `flutter pub get`.

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
```

---

## Resources

- [Flutter documentation](https://docs.flutter.dev/)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter cookbook](https://docs.flutter.dev/cookbook)
- [Dart language tour](https://dart.dev/language)
- [pub.dev packages](https://pub.dev/)
