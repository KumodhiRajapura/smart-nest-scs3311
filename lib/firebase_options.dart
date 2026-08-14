// PLACEHOLDER -- replace by running:
//
//   flutterfire configure --project=<your-firebase-project-id>
//
// That command overwrites this whole file with the real keys and drops
// android/app/google-services.json into place. It is checked in here only so
// the project compiles before anyone has run it.
//
// The values below are deliberately invalid. Firebase would fail deep inside
// the native SDK with an unhelpful message, so [DefaultFirebaseOptions] throws
// something readable instead.

// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

const String _placeholder = 'REPLACE_ME';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    final options = _forPlatform;
    if (options.apiKey == _placeholder) {
      throw StateError(
        'Firebase is not configured yet.\n'
        'Run:  flutterfire configure --project=<your-project-id>\n'
        'from the repository root, then rebuild.',
      );
    }
    return options;
  }

  static FirebaseOptions get _forPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
          'No Firebase options for $defaultTargetPlatform. '
          'Re-run flutterfire configure and select that platform.',
        ),
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBBEjcvEH8N5YUOyBl6w4DRNDyJfEsiI-A',
    appId: '1:362954050184:android:f07df5521ed49085ceed3d',
    messagingSenderId: '362954050184',
    projectId: 'smart-nest-scs3311',
    storageBucket: 'smart-nest-scs3311.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _placeholder,
    projectId: _placeholder,
    storageBucket: _placeholder,
    iosBundleId: 'com.example.smartNestApp',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBKFJqZNQBV77ivx4ypGwcVJ-rnwCRg-AA',
    appId: '1:362954050184:web:a85ef90fb9039a02ceed3d',
    messagingSenderId: '362954050184',
    projectId: 'smart-nest-scs3311',
    authDomain: 'smart-nest-scs3311.firebaseapp.com',
    storageBucket: 'smart-nest-scs3311.firebasestorage.app',
  );
}
