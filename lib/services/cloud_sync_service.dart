import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_nest_app/config/app_config.dart';
import 'package:smart_nest_app/models/device_model.dart';
import 'package:smart_nest_app/models/room_model.dart';
import 'package:smart_nest_app/services/smart_home_service.dart';

// If you add firebase_options.dart (via FlutterFire CLI), this import will
// provide platform-specific options. Add the generated file to the project
// root (lib/) as: lib/firebase_options.dart
import 'package:smart_nest_app/firebase_options.dart' show DefaultFirebaseOptions;

/// CloudSyncService provides either a Firestore-backed sync when Firebase is
/// configured, or falls back to a local mocked behavior. Use init() early in
/// the app lifecycle (e.g., splash screen) to initialize Firebase if available.
class CloudSyncService {
  CloudSyncService._internal();
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;

  bool _firebaseAvailable = false;

  bool get isFirebaseAvailable => _firebaseAvailable;

  Future<void> init() async {
    try {
      // Prefer using generated platform options when available. If the
      // project includes lib/firebase_options.dart (generated via
      // `flutterfire configure`), use that. Otherwise fall back to default
      // initializeApp() which can work in some environments.
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      } catch (e) {
        // If the generated options aren't present or initialization with
        // options fails, try the simpler form. This preserves the local
        // fallback behavior for development/testing.
        await Firebase.initializeApp();
      }

      _firebaseAvailable = true;
      debugPrint('Firebase initialized');
    } catch (e) {
      _firebaseAvailable = false;
      debugPrint('Firebase not configured: $e');
    }
  }

  CollectionReference<Map<String, dynamic>> get _devicesColl {
    return FirebaseFirestore.instance.collection('devices');
  }

  /// Authentication helpers
  User? get currentUser => _firebaseAvailable ? FirebaseAuth.instance.currentUser : null;
  Stream<User?> authStateChanges() => _firebaseAvailable ? FirebaseAuth.instance.authStateChanges() : Stream.value(null);

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    if (!_firebaseAvailable) return null;
    return await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    if (!_firebaseAvailable) return null;
    return await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (!_firebaseAvailable) return;
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  /// Sign in with Google (interactive). Returns null if Firebase isn't
  /// available or if the user cancels the sign-in flow.
  Future<UserCredential?> signInWithGoogle() async {
    if (!_firebaseAvailable) return null;
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        return await FirebaseAuth.instance.signInWithPopup(provider);
      }

      // Mobile Google sign-in not enabled in this build. To enable mobile
      // Google authentication, add the `google_sign_in` plugin and
      // platform OAuth configuration (google-services.json / Info.plist,
      // SHA-1, etc.).
      debugPrint('Google sign-in not implemented on non-web platforms in this build.');
      return null;
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!_firebaseAvailable) return;
    await FirebaseAuth.instance.signOut();
    // Mobile google_sign_in signOut omitted in this build.
  }

  Stream<List<Room>> roomsStream() {
    if (!_firebaseAvailable) {
      if (AppConfig.enableLocalDemoFallback) {
          return Stream.value(SmartHomeService().getRooms());
      }
      return const Stream.empty();
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance.collection('rooms').where('ownerId', isEqualTo: uid).snapshots().map((snap) {
      return snap.docs.map((d) => Room.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
    });
  }

  Stream<List<SmartDevice>> devicesStream() {
    if (!_firebaseAvailable) {
      if (AppConfig.enableLocalDemoFallback) {
          return Stream.value(SmartHomeService().getDevices());
      }
      return const Stream.empty();
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }

    return _devicesColl.where('ownerId', isEqualTo: uid).snapshots().map((snap) {
      return snap.docs.map((d) => SmartDevice.fromFirestore(d)).toList();
    });
  }

  Future<List<Room>> fetchFloors() async {
    if (!_firebaseAvailable) {
      if (AppConfig.enableLocalDemoFallback) {
        return SmartHomeService().getRooms();
      }
      return const [];
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];

    final snap = await FirebaseFirestore.instance.collection('rooms').where('ownerId', isEqualTo: uid).get();
    return snap.docs.map((d) => Room.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
  }

  Future<List<SmartDevice>> fetchDevices() async {
    if (!_firebaseAvailable) {
      if (AppConfig.enableLocalDemoFallback) {
        return const SmartHomeService().getDevices();
      }
      return const [];
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];

    final snap = await _devicesColl.where('ownerId', isEqualTo: uid).get();
    return snap.docs.map((d) => SmartDevice.fromFirestore(d)).toList();
  }

  Future<void> updateDeviceState(String deviceId, {required bool isOn}) async {
    if (!_firebaseAvailable) {
      if (AppConfig.enableLocalDemoFallback) {
        debugPrint('Local sync requested for $deviceId: $isOn');
      }
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final data = {
      'ownerId': uid,
      'status': isOn ? 'on' : 'off',
      'turnedOnAt': isOn ? FieldValue.serverTimestamp() : null,
      'updatedBy': 'mobile_app',
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    await _devicesColl.doc(deviceId).set(data, SetOptions(merge: true));
  }

  Future<void> updateMultiSwitchState(String deviceId, int switchIndex, bool value) async {
    if (!_firebaseAvailable) {
      if (AppConfig.enableLocalDemoFallback) {
        debugPrint('Local multi-switch: $deviceId[$switchIndex]=$value');
      }
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final docRef = _devicesColl.doc(deviceId);
    final snap = await docRef.get();
    if (!snap.exists) return;
    final data = snap.data() ?? {};
    if (data['ownerId'] != null && data['ownerId'] != uid) return;

    // Normalize existing childSwitches, which should be a list of maps {id,label,isOn}
    List childSwitches = [];
    if (data['childSwitches'] is List) {
      childSwitches = List.from(data['childSwitches']);
    } else if (data['switches'] is List) {
      // older format: boolean list
      final List fromOld = List.from(data['switches']);
      for (var i = 0; i < fromOld.length; i++) {
        childSwitches.add({'id': 's$i', 'label': 'Switch ${i + 1}', 'isOn': fromOld[i] == true});
      }
    }

    while (childSwitches.length <= switchIndex) {
      final idx = childSwitches.length;
      childSwitches.add({'id': 's$idx', 'label': 'Switch ${idx + 1}', 'isOn': false});
    }

    childSwitches[switchIndex] = {
      'id': childSwitches[switchIndex]['id'] ?? 's$switchIndex',
      'label': childSwitches[switchIndex]['label'] ?? 'Switch ${switchIndex + 1}',
      'isOn': value
    };

    final bool anyOn = childSwitches.any((m) => m['isOn'] == true);

    await docRef.set({
      'ownerId': uid,
      'childSwitches': childSwitches,
      'status': anyOn ? 'on' : 'off',
      'turnedOnAt': anyOn ? FieldValue.serverTimestamp() : null,
      'updatedBy': 'mobile_app',
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Seed sample data into Firestore (idempotent)
  Future<void> seedSampleData() async {
    if (!_firebaseAvailable) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final roomsRef = FirebaseFirestore.instance.collection('rooms');
    final devicesRef = FirebaseFirestore.instance.collection('devices');

    final roomsSnap = await roomsRef.where('ownerId', isEqualTo: uid).limit(1).get();
    if (roomsSnap.docs.isEmpty) {
      final sampleRooms = const SmartHomeService().getRooms();
      for (final r in sampleRooms) {
        // use Room model's canonical fields
        await roomsRef.doc('${uid}_${r.id}').set({
          'ownerId': uid,
          'id': r.id,
          'floorId': r.floorId,
          'name': r.name,
          'gridRow': r.gridRow,
          'gridCol': r.gridCol,
          'deviceIds': r.deviceIds,
        });
      }
    }

    final devSnap = await devicesRef.where('ownerId', isEqualTo: uid).limit(1).get();
    if (devSnap.docs.isEmpty) {
      final sampleDevices = const SmartHomeService().getDevices();
      for (final d in sampleDevices) {
        final map = d.toMap();
        map['ownerId'] = uid;
        await devicesRef.doc('${uid}_${d.id}').set(map);
      }
    }
  }

  /// Enforce scheduling and safety rules on a list of devices and return updated list.
  /// If Firebase is available, writes changes back to Firestore.
  Future<List<SmartDevice>> enforceRules(List<SmartDevice> devices, {DateTime? now}) async {
    final DateTime t = now ?? DateTime.now();
    final List<SmartDevice> updated = [];
    final uid = FirebaseAuth.instance.currentUser?.uid;

    for (final d in devices) {
      SmartDevice cur = d;

      if (cur.scheduledShouldBeOn(t)) {
        if (cur.isMultiSwitch) {
          // turn all child switches on
          final newChildren = cur.childSwitches.map((c) => SwitchChild(id: c.id, label: c.label, isOn: true)).toList();
          cur = cur.copyWith(childSwitches: newChildren, status: DeviceStatus.on, turnedOnAt: t);
        } else {
          cur = cur.copyWith(status: DeviceStatus.on, turnedOnAt: t);
        }
      }

      if (cur.hasExceededMaxDuration(t)) {
        if (cur.isMultiSwitch) {
          final newChildren = cur.childSwitches.map((c) => SwitchChild(id: c.id, label: c.label, isOn: false)).toList();
          cur = cur.copyWith(childSwitches: newChildren, status: DeviceStatus.off);
        } else {
          cur = cur.copyWith(status: DeviceStatus.off);
        }
        debugPrint('Safety cutoff applied to ${cur.id}');
      }

      // persist to Firestore if available and the signed-in user owns this device
      if (_firebaseAvailable && uid != null) {
        try {
          final map = cur.toMap();
          map['ownerId'] = uid;
          await _devicesColl.doc('${uid}_${cur.id}').set(map, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Failed to persist rules for ${cur.id}: $e');
        }
      }

      updated.add(cur);
    }
    return updated;
  }
}
