import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_service.dart';

/// Backend services that must be up before the first Firestore listener.
///
/// Call this from `main()` straight after `Firebase.initializeApp()`, and
/// before `runApp`.
///
/// Note what is deliberately *not* here: `Firebase.initializeApp` (main.dart
/// owns it) and sign-in. The app authenticates through AuthService and the
/// sign-in screen, so this must not create a competing anonymous session. The
/// web simulator still signs in anonymously, which is why Anonymous auth has to
/// stay enabled in the Firebase console even though the app never uses it.
Future<void> initBackendServices() async {
  _configureFirestore();
  await NotificationService.instance.init();
}

/// Offline persistence.
///
/// Cached documents render immediately on a cold start, and writes made without
/// a connection are replayed when it returns. It is on by default on mobile,
/// but being explicit documents the intent -- and this is what makes a toggle
/// feel instant on a slow connection, since the local write fires the snapshot
/// before the server acknowledges it.
void _configureFirestore() {
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
}
