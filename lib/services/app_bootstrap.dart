import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../firebase_options.dart';
import 'notification_service.dart';

/// Everything that must happen before the first frame.
///
/// Call this from `main()` and await it before `runApp`. The order matters:
/// Firebase core first, then auth (Firestore rules reject unauthenticated
/// reads, so a listener attached before sign-in would fail), then messaging.
Future<void> bootstrapBackend() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Offline persistence: cached documents render immediately on a cold start
  // and writes made without a connection are replayed when it returns. It is
  // on by default on mobile, but being explicit documents the intent -- and
  // this is what makes a toggle feel instant even on a slow connection, since
  // the local write fires the snapshot before the server acknowledges it.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await _ensureSignedIn();
  await NotificationService.instance.init();
}

/// Anonymous sign-in.
///
/// The app has no login screen, but the security rules still require
/// `request.auth != null`. Anonymous auth gives every install a stable uid, so
/// the database is not world-writable and reads can be attributed, without
/// putting a sign-up form in front of a demo.
Future<User> _ensureSignedIn() async {
  final auth = FirebaseAuth.instance;
  final existing = auth.currentUser;
  if (existing != null) return existing;

  final credential = await auth.signInAnonymously();
  debugPrint('[auth] signed in anonymously as ${credential.user?.uid}');
  return credential.user!;
}
