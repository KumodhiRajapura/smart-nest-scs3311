import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:smart_nest_app/config/firestore_paths.dart';
import 'package:smart_nest_app/models/device_model.dart';
import 'package:smart_nest_app/models/room_model.dart';
import 'package:smart_nest_app/models/floor_model.dart';
import 'app_exception.dart';

class FirestoreService {
  FirestoreService._internal();
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;

  FirebaseFirestore? _db;

  FirebaseFirestore? get _firestore {
    if (_db != null) return _db;
    try {
      if (Firebase.apps.isNotEmpty) _db = FirebaseFirestore.instance;
    } catch (_) {
      _db = null;
    }
    return _db;
  }

  Stream<List<FloorModel>> streamFloors() {
    try {
      final db = _firestore;
      if (db == null) return const Stream.empty();
      return db.collection(FirestorePaths.floors).orderBy('order').snapshots().map((snap) {
        return snap.docs.map((d) => FloorModel.fromFirestore(d)).toList();
      });
    } catch (e) {
      // Convert to stream that emits nothing on error rather than throw
      return const Stream.empty();
    }
  }

  Stream<List<Room>> streamRoomsForFloor(String floorId) {
    try {
      final db = _firestore;
      if (db == null) return const Stream.empty();
      return db
          .collection(FirestorePaths.rooms)
          .where('floorId', isEqualTo: floorId)
          .snapshots()
          .map((snap) => snap.docs.map((d) => Room.fromFirestore(d)).toList());
    } catch (e) {
      return const Stream.empty();
    }
  }

  Stream<List<SmartDevice>> streamDevicesForRoom(String roomId) {
    try {
      final db = _firestore;
      if (db == null) return const Stream.empty();
      return db
          .collection(FirestorePaths.devices)
          .where('roomId', isEqualTo: roomId)
          .snapshots()
          .map((snap) => snap.docs.map((d) => SmartDevice.fromFirestore(d)).toList());
    } catch (e) {
      return const Stream.empty();
    }
  }

  Stream<SmartDevice> streamDevice(String deviceId) {
    try {
      final db = _firestore;
      if (db == null) throw AppException('Firestore not initialized');
      return db.collection(FirestorePaths.devices).doc(deviceId).snapshots().map((d) => SmartDevice.fromFirestore(d));
    } catch (e) {
      // returning an empty stream would block; instead throw so callers can handle
      throw AppException('Failed to stream device: $e');
    }
  }

  Future<void> toggleDevice(String deviceId, bool turnOn) async {
    try {
      final db = _firestore;
      if (db == null) throw AppException('Firestore not initialized');
      final ref = db.collection(FirestorePaths.devices).doc(deviceId);
      await ref.set({
        Fields.isOn: turnOn,
        Fields.status: turnOn ? 'on' : 'off',
        Fields.lastUpdated: FieldValue.serverTimestamp(),
        Fields.updatedBy: 'mobile_app',
        if (turnOn) Fields.turnedOnAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw AppException('Failed to toggle device: $e');
    }
  }

  Future<void> toggleChildSwitch(String deviceId, String switchId, bool turnOn) async {
    try {
      final db = _firestore;
      if (db == null) throw AppException('Firestore not initialized');
      final ref = db.collection(FirestorePaths.devices).doc(deviceId);
      final doc = await ref.get();
      final data = doc.data() ?? {};
      final List switches = data['childSwitches'] is List ? List.from(data['childSwitches']) : [];
      for (var i = 0; i < switches.length; i++) {
        final sw = switches[i];
        if (sw is Map && sw['id'] == switchId) {
          sw['isOn'] = turnOn;
        }
      }
      final anyOn = switches.any((s) => s is Map && s['isOn'] == true);
      await ref.set({
        'childSwitches': switches,
        Fields.isOn: anyOn,
        Fields.status: anyOn ? 'on' : 'off',
        Fields.lastUpdated: FieldValue.serverTimestamp(),
        Fields.updatedBy: 'mobile_app',
      }, SetOptions(merge: true));
    } catch (e) {
      throw AppException('Failed to toggle child switch: $e');
    }
  }

  Future<void> updateApplianceSchedule(String deviceId, int maxOnMinutes) async {
    try {
      final db = _firestore;
      if (db == null) throw AppException('Firestore not initialized');
      final ref = db.collection(FirestorePaths.devices).doc(deviceId);
      await ref.set({
        Fields.maxOnDurationMinutes: maxOnMinutes,
        Fields.lastUpdated: FieldValue.serverTimestamp(),
        Fields.updatedBy: 'mobile_app',
      }, SetOptions(merge: true));
    } catch (e) {
      throw AppException('Failed to update appliance schedule: $e');
    }
  }

  Future<void> updateLightSchedule(String deviceId, String startHHmm, String endHHmm) async {
    try {
      final db = _firestore;
      if (db == null) throw AppException('Firestore not initialized');
      final ref = db.collection(FirestorePaths.devices).doc(deviceId);
      await ref.set({
        Fields.scheduleStartTime: startHHmm,
        Fields.scheduleEndTime: endHHmm,
        Fields.lastUpdated: FieldValue.serverTimestamp(),
        Fields.updatedBy: 'mobile_app',
      }, SetOptions(merge: true));
    } catch (e) {
      throw AppException('Failed to update light schedule: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> streamUsageLogs(String deviceId) {
    try {
      final db = _firestore;
      if (db == null) return const Stream.empty();
      return db
          .collection(FirestorePaths.usageLogs)
          .where('deviceId', isEqualTo: deviceId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .map((snap) => snap.docs.map((d) => d.data()).toList());
    } catch (e) {
      return const Stream.empty();
    }
  }
}
