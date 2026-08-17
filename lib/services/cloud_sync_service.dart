import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:smart_nest_app/config/app_config.dart';
import 'package:smart_nest_app/config/firestore_paths.dart';
import 'package:smart_nest_app/models/device_model.dart';
import 'package:smart_nest_app/models/floor_model.dart';
import 'package:smart_nest_app/models/room_model.dart';
import 'package:smart_nest_app/services/firestore_service.dart';
import 'package:smart_nest_app/services/smart_home_service.dart';

/// Screen-facing wrapper over [FirestoreService].
///
/// It adds one thing the raw service does not have: a local demo fallback, so
/// the UI still renders something before Firebase has been configured.
/// Everything that touches the database is delegated -- there is exactly one
/// implementation of a device write in this app, and it lives in
/// [FirestoreService].
///
/// **No `ownerId` anywhere.** This is one shared house. Devices scoped per user
/// would be invisible to the web simulator, which signs in anonymously and
/// reads the whole `devices` collection, and to the backend worker, which
/// enforces safety across every device in the project. A smart home is not a
/// per-user inbox: the iron in the utility room is the same iron whoever is
/// looking at it.
///
/// Authentication is not here either -- [AuthService] owns it, and both the
/// sign-in screen and the auth gate use that.
class CloudSyncService {
  CloudSyncService._internal();

  static final CloudSyncService _instance = CloudSyncService._internal();

  factory CloudSyncService() => _instance;

  final FirestoreService _firestore = FirestoreService();

  bool _firebaseAvailable = false;

  bool get isFirebaseAvailable => _firebaseAvailable;

  /// Called from the splash screen. Safe to call more than once.
  ///
  /// `main()` already ran `Firebase.initializeApp`, so this only records
  /// whether that succeeded -- initialising a second time would throw.
  Future<void> init() async {
    _firebaseAvailable = Firebase.apps.isNotEmpty;
    debugPrint(
      _firebaseAvailable
          ? 'Firebase ready'
          : 'Firebase not configured; using local demo data',
    );
  }

  bool get _useDemoData =>
      !_firebaseAvailable && AppConfig.enableLocalDemoFallback;

  // ------------------------------------------------------------------ reads

  /// Every device in the house, live.
  ///
  /// A snapshot stream, not a fetch loop: a change made on another phone, in
  /// the web simulator, or by the safety worker arrives here in a few hundred
  /// milliseconds. That is the whole of "bidirectional sync" -- there is no
  /// refresh control in this app because there is nothing for one to do.
  Stream<List<SmartDevice>> devicesStream() {
    if (_useDemoData) return Stream.value(const SmartHomeService().getDevices());
    if (!_firebaseAvailable) return const Stream.empty();
    return _firestore.streamAllDevices();
  }

  Stream<List<SmartDevice>> devicesForRoomStream(String roomId) {
    if (_useDemoData) {
      return Stream.value(const SmartHomeService()
          .getDevices()
          .where((d) => d.roomId == roomId)
          .toList());
    }
    if (!_firebaseAvailable) return const Stream.empty();
    return _firestore.streamDevicesForRoom(roomId);
  }

  Stream<List<Room>> roomsStream() {
    if (_useDemoData) return Stream.value(const SmartHomeService().getRooms());
    if (!_firebaseAvailable) return const Stream.empty();
    return _firestore.streamAllRooms();
  }

  Stream<List<Room>> roomsForFloorStream(String floorId) {
    if (_useDemoData) {
      return Stream.value(const SmartHomeService()
          .getRooms()
          .where((r) => r.floorId == floorId)
          .toList());
    }
    if (!_firebaseAvailable) return const Stream.empty();
    return _firestore.streamRoomsForFloor(floorId);
  }

  /// Every configured floor, in display order.
  ///
  /// This is the top of the "Multi-Floor Interactive Dashboard": the floors
  /// screen lists these, and each one opens onto its own abstract room grid.
  Stream<List<FloorModel>> floorsStream() {
    if (_useDemoData) return Stream.value(const SmartHomeService().getFloors());
    if (!_firebaseAvailable) return const Stream.empty();
    return _firestore.streamFloors();
  }

  Future<List<SmartDevice>> fetchDevices() async {
    if (_useDemoData) return const SmartHomeService().getDevices();
    if (!_firebaseAvailable) return const [];
    return devicesStream().first;
  }

  Future<List<Room>> fetchFloors() async {
    if (_useDemoData) return const SmartHomeService().getRooms();
    if (!_firebaseAvailable) return const [];
    return roomsStream().first;
  }

  // ---------------------------------------------------------------- control

  /// Switch a device on or off.
  ///
  /// Delegates so the `turnedOnAt` rules and the transaction live in one place.
  /// Getting them wrong here would break the safety cutoff silently: the worker
  /// would still be watching a field that nobody maintains.
  Future<void> updateDeviceState(String deviceId, {required bool isOn}) async {
    if (!_firebaseAvailable) {
      debugPrint('Demo mode: would set $deviceId to ${isOn ? 'on' : 'off'}');
      return;
    }
    await _firestore.toggleDevice(deviceId, isOn);
  }

  /// Switch one child switch of a gang box, addressed by position.
  Future<void> updateMultiSwitchState(
    String deviceId,
    int switchIndex,
    bool value,
  ) async {
    if (!_firebaseAvailable) {
      debugPrint('Demo mode: would set $deviceId[$switchIndex] to $value');
      return;
    }
    await _firestore.toggleChildSwitchAt(deviceId, switchIndex, value);
  }

  // ------------------------------------------------------------- scheduling

  /// Set the safety budget (in minutes) for a fire-hazard appliance such as
  /// an iron. The backend worker cuts power automatically once a running
  /// device's elapsed ON time reaches this figure.
  Future<void> updateApplianceSchedule(String deviceId, int maxOnMinutes) async {
    if (!_firebaseAvailable) {
      debugPrint('Demo mode: would set max ON duration for $deviceId to $maxOnMinutes min');
      return;
    }
    await _firestore.updateApplianceSchedule(deviceId, maxOnMinutes);
  }

  /// Set the automatic ON/OFF window for a scheduled light.
  Future<void> updateLightSchedule(
    String deviceId,
    String startHHmm,
    String endHHmm, {
    bool enabled = true,
  }) async {
    if (!_firebaseAvailable) {
      debugPrint('Demo mode: would set schedule for $deviceId to $startHHmm-$endHHmm');
      return;
    }
    await _firestore.updateLightSchedule(deviceId, startHHmm, endHHmm, enabled: enabled);
  }

  Future<void> setScheduleEnabled(String deviceId, bool enabled) async {
    if (!_firebaseAvailable) {
      debugPrint('Demo mode: would set schedule enabled=$enabled for $deviceId');
      return;
    }
    await _firestore.setScheduleEnabled(deviceId, enabled);
  }

  Future<void> clearLightSchedule(String deviceId) async {
    if (!_firebaseAvailable) {
      debugPrint('Demo mode: would clear schedule for $deviceId');
      return;
    }
    await _firestore.clearLightSchedule(deviceId);
  }

  Future<void> renameDevice(String deviceId, String name) async {
    if (!_firebaseAvailable) {
      debugPrint('Demo mode: would rename $deviceId to $name');
      return;
    }
    await _firestore.renameDevice(deviceId, name);
  }

  // ------------------------------------------------------------------- CRUD

  /// Create a new floor. Returns the new floor's id, or a placeholder id in
  /// demo mode (nothing is actually persisted without Firebase).
  Future<String> createFloor({required String name, required int order, String? floorPlanImageUrl}) async {
    if (!_firebaseAvailable) {
      debugPrint('Demo mode: would create floor "$name"');
      return 'demo-floor-${DateTime.now().millisecondsSinceEpoch}';
    }
    return _firestore.createFloor(name: name, order: order, floorPlanImageUrl: floorPlanImageUrl);
  }

  Future<void> deleteFloor(String floorId) async {
    if (!_firebaseAvailable) {
      debugPrint('Demo mode: would delete floor $floorId');
      return;
    }
    await _firestore.deleteFloor(floorId);
  }

  Future<void> updateFloor(
    String floorId, {
    String? name,
    int? order,
    String? floorPlanImageUrl,
  }) async {
    if (!_firebaseAvailable) {
      debugPrint('Demo mode: would update floor $floorId');
      return;
    }
    await _firestore.updateFloor(
      floorId,
      name: name,
      order: order,
      floorPlanImageUrl: floorPlanImageUrl,
    );
  }

  Future<String> createRoom({
    required String floorId,
    required String name,
    required int gridRow,
    required int gridCol,
  }) async {
    if (!_firebaseAvailable) {
      debugPrint('Demo mode: would create room "$name" on floor $floorId');
      return 'demo-room-${DateTime.now().millisecondsSinceEpoch}';
    }
    return _firestore.createRoom(
      floorId: floorId,
      name: name,
      gridRow: gridRow,
      gridCol: gridCol,
    );
  }

  Future<void> deleteRoom(String roomId) async {
    if (!_firebaseAvailable) {
      debugPrint('Demo mode: would delete room $roomId');
      return;
    }
    await _firestore.deleteRoom(roomId);
  }

  Future<String> createDevice({
    required String name,
    required String roomId,
    required String floorId,
    required DeviceType type,
    List<SwitchChild> childSwitches = const [],
    int? maxOnDurationMinutes,
  }) async {
    if (!_firebaseAvailable) {
      debugPrint('Demo mode: would create device "$name" in room $roomId');
      return 'demo-device-${DateTime.now().millisecondsSinceEpoch}';
    }
    return _firestore.createDevice(
      name: name,
      roomId: roomId,
      floorId: floorId,
      type: type,
      childSwitches: childSwitches,
      maxOnDurationMinutes: maxOnDurationMinutes,
    );
  }

  Future<void> deleteDevice(String deviceId) async {
    if (!_firebaseAvailable) {
      debugPrint('Demo mode: would delete device $deviceId');
      return;
    }
    await _firestore.deleteDevice(deviceId);
  }

  // ------------------------------------------------------------------- seed

  /// Write the demo house, but only if the database is empty.
  ///
  /// A convenience for the sign-in screen. `worker/seed.js` (`npm run seed`) is
  /// the canonical seed -- it writes the full two-floor house the demo script
  /// expects and can be re-run to reset state. This exists so the app is not
  /// stuck staring at an empty database when nobody has a terminal open.
  Future<void> seedSampleData() async {
    if (!_firebaseAvailable) return;

    final db = FirebaseFirestore.instance;
    final existing = await db.collection(FirestorePaths.devices).limit(1).get();
    if (existing.docs.isNotEmpty) {
      debugPrint('Devices already present; skipping seed');
      return;
    }

    final floors = const SmartHomeService().getFloors();
    final rooms = const SmartHomeService().getRooms();
    final devices = const SmartHomeService().getDevices();
    final batch = db.batch();

    for (final floor in floors) {
      batch.set(db.collection(FirestorePaths.floors).doc(floor.id), {
        Fields.id: floor.id,
        Fields.name: floor.name,
        'order': floor.order,
        'floorPlanImageUrl': floor.floorPlanImageAsset,
      });
    }

    for (final room in rooms) {
      batch.set(db.collection(FirestorePaths.rooms).doc(room.id), {
        Fields.id: room.id,
        Fields.floorId: room.floorId,
        Fields.name: room.name,
        'gridRow': room.gridRow,
        'gridCol': room.gridCol,
        Fields.deviceIds:
            devices.where((d) => d.roomId == room.id).map((d) => d.id).toList(),
      });
    }

    for (final device in devices) {
      final floorId = rooms
          .firstWhere((r) => r.id == device.roomId, orElse: () => rooms.first)
          .floorId;

      batch.set(db.collection(FirestorePaths.devices).doc(device.id), {
        ...device.toMap(),
        Fields.floorId: floorId,
        // Seeding always parks the house in a known state. A device left ON
        // with a stale turnedOnAt would be cut off by the worker seconds later,
        // which looks like a bug and is really just bad seed data.
        Fields.status: DeviceStatusValues.off,
        Fields.turnedOnAt: null,
        Fields.statusReason: StatusReasons.manual,
        Fields.updatedBy: UpdateSources.app,
        Fields.lastUpdated: FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    debugPrint(
      'Seeded ${floors.length} floors, ${rooms.length} rooms, '
      '${devices.length} devices',
    );
  }
}
