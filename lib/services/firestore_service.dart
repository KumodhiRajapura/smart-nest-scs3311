import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:smart_nest_app/config/firestore_paths.dart';
import 'package:smart_nest_app/models/device_model.dart';
import 'package:smart_nest_app/models/floor_model.dart';
import 'package:smart_nest_app/models/room_model.dart';

import 'app_exception.dart';

/// The single door between the app and the `devices` / `rooms` / `floors`
/// collections.
///
/// Two rules run through everything here:
///
/// **Reads are streams; the UI never applies a state change itself.** A control
/// action writes to Firestore and waits for the snapshot to come back. That is
/// what keeps the phone, the web simulator and the backend worker showing the
/// same thing, and why an externally driven change needs no refresh.
///
/// **`turnedOnAt` is sacred.** The safety worker's countdown is derived from it
/// alone. It is written *only* on a genuine OFF -> ON edge and cleared on OFF.
/// Refreshing it on a device that is already on would silently hand a running
/// iron a brand new safety budget.
///
/// There is no `ownerId` here. This is one house, shared by everyone signed in
/// -- the same house the web simulator and the worker see. Scoping devices per
/// user would mean the simulator could never mirror the app.
class FirestoreService {
  FirestoreService._internal();

  static final FirestoreService _instance = FirestoreService._internal();

  factory FirestoreService() => _instance;

  FirebaseFirestore? _db;

  FirebaseFirestore? get _firestore {
    if (_db != null) return _db;
    if (Firebase.apps.isNotEmpty) _db = FirebaseFirestore.instance;
    return _db;
  }

  /// Throws rather than returning null, so a caller cannot accidentally treat
  /// "Firebase is not ready" as "there is no data".
  FirebaseFirestore get _requireDb {
    final db = _firestore;
    if (db == null) {
      throw const AppException('Firestore is not initialised');
    }
    return db;
  }

  bool get isAvailable => _firestore != null;

  CollectionReference<Map<String, dynamic>> get _devices =>
      _requireDb.collection(FirestorePaths.devices);

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _requireDb.collection(FirestorePaths.rooms);

  CollectionReference<Map<String, dynamic>> get _floors =>
      _requireDb.collection(FirestorePaths.floors);

  /// Surfaces a setup failure through the stream instead of hanging on an
  /// empty one.
  ///
  /// This matters more than it looks: a missing composite index and a
  /// permission-denied both arrive as stream errors, and Firestore's message
  /// for a missing index contains a link that creates it in one click.
  /// Swallowing those into an empty stream turns a two-second fix into an hour
  /// of staring at an empty screen.
  Stream<T> _guarded<T>(Stream<T> Function() build) {
    try {
      return build();
    } on AppException catch (e) {
      return Stream<T>.error(e);
    } catch (e) {
      return Stream<T>.error(AppException('Query failed: $e'));
    }
  }

  // ------------------------------------------------------------------ reads

  Stream<List<FloorModel>> streamFloors() => _guarded(
        () => _floors.orderBy('order').snapshots().map(
              (snap) => snap.docs.map(FloorModel.fromFirestore).toList(),
            ),
      );

  Stream<List<Room>> streamRoomsForFloor(String floorId) => _guarded(
        () => _rooms
            .where(Fields.floorId, isEqualTo: floorId)
            .snapshots()
            .map((snap) => snap.docs.map(Room.fromFirestore).toList()),
      );

  Stream<List<Room>> streamAllRooms() => _guarded(
        () => _rooms
            .snapshots()
            .map((snap) => snap.docs.map(Room.fromFirestore).toList()),
      );

  Stream<List<SmartDevice>> streamDevicesForRoom(String roomId) => _guarded(
        () => _devices
            .where(Fields.roomId, isEqualTo: roomId)
            .snapshots()
            .map((snap) => snap.docs.map(SmartDevice.fromFirestore).toList()),
      );

  /// Every device on a floor, without walking room by room.
  ///
  /// Needs the composite index on (floorId, name) -- see firestore.indexes.json.
  Stream<List<SmartDevice>> streamDevicesForFloor(String floorId) => _guarded(
        () => _devices
            .where(Fields.floorId, isEqualTo: floorId)
            .orderBy(Fields.name)
            .snapshots()
            .map((snap) => snap.docs.map(SmartDevice.fromFirestore).toList()),
      );

  /// The whole house. What the dashboard and the simulator both listen to.
  Stream<List<SmartDevice>> streamAllDevices() => _guarded(
        () => _devices
            .orderBy(Fields.name)
            .snapshots()
            .map((snap) => snap.docs.map(SmartDevice.fromFirestore).toList()),
      );

  Stream<SmartDevice> streamDevice(String deviceId) => _guarded(
        () => _devices.doc(deviceId).snapshots().map((doc) {
          if (!doc.exists) throw AppException('Device $deviceId not found');
          return SmartDevice.fromFirestore(doc);
        }),
      );

  Future<SmartDevice?> getDevice(String deviceId) async {
    final doc = await _devices.doc(deviceId).get();
    return doc.exists ? SmartDevice.fromFirestore(doc) : null;
  }

  // ----------------------------------------------------------------- control

  /// Switch a whole device on or off.
  ///
  /// Runs in a transaction so the decision "is this a real edge?" is made
  /// against the committed document rather than a stale copy from the UI.
  Future<void> toggleDevice(String deviceId, bool turnOn) async {
    final ref = _devices.doc(deviceId);

    await _requireDb.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) {
        throw AppException('Device $deviceId no longer exists');
      }

      final data = snap.data() ?? const <String, dynamic>{};
      final current = data[Fields.status] as String?;

      // Never fight the hardware. A device the simulator reports as faulty or
      // unreachable stays that way until it says otherwise -- writing ON over
      // a DISCONNECTED iron would be a lie the UI then displays as truth.
      if (current == DeviceStatusValues.error ||
          current == DeviceStatusValues.disconnected) {
        throw AppException(
          '${data[Fields.name] ?? 'Device'} is $current. Bring it back online first.',
        );
      }

      final wasOn = current == DeviceStatusValues.on;

      // Already in the requested state: do nothing. Without this guard, tapping
      // ON on a device that is already ON rewrites turnedOnAt and restarts the
      // safety countdown from zero.
      if (wasOn == turnOn) return;

      final update = <String, dynamic>{
        Fields.status:
            turnOn ? DeviceStatusValues.on : DeviceStatusValues.off,
        Fields.turnedOnAt: turnOn ? FieldValue.serverTimestamp() : null,
        Fields.statusReason: StatusReasons.manual,
        ..._stamp(),
      };

      // A gang box has no meaning apart from its switches: switching the unit
      // off must switch every child off too.
      final children = data[Fields.childSwitches];
      if (children is List && children.isNotEmpty) {
        update[Fields.childSwitches] = children
            .whereType<Map>()
            .map((c) => {...c, 'isOn': turnOn})
            .toList();
      }

      txn.update(ref, update);
    });
  }

  /// Switch one addressable switch inside a gang box.
  ///
  /// Firestore cannot update a single array element, so the array is rewritten
  /// -- inside a transaction, because two people flipping switch 1 and switch 3
  /// at the same moment would otherwise each write back a copy that discards
  /// the other's change. One edit vanishes, with nothing to show it happened.
  Future<void> toggleChildSwitch(
    String deviceId,
    String switchId,
    bool turnOn,
  ) =>
      _setChild(deviceId, turnOn, matchId: switchId);

  /// Same thing, addressed by position.
  ///
  /// The dashboard renders child switches as a numbered row and has an index
  /// rather than an id. Resolving it inside the transaction keeps it to one
  /// round trip and means the index is read from the same document the write
  /// lands on.
  Future<void> toggleChildSwitchAt(
    String deviceId,
    int index,
    bool turnOn,
  ) =>
      _setChild(deviceId, turnOn, matchIndex: index);

  Future<void> _setChild(
    String deviceId,
    bool turnOn, {
    String? matchId,
    int? matchIndex,
  }) async {
    final ref = _devices.doc(deviceId);

    await _requireDb.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) {
        throw AppException('Device $deviceId no longer exists');
      }

      final data = snap.data() ?? const <String, dynamic>{};
      final current = data[Fields.status] as String?;

      if (current == DeviceStatusValues.error ||
          current == DeviceStatusValues.disconnected) {
        throw AppException(
          '${data[Fields.name] ?? 'Device'} is $current. Bring it back online first.',
        );
      }

      final raw = data[Fields.childSwitches];
      if (raw is! List || raw.isEmpty) {
        throw AppException(
          '${data[Fields.name] ?? 'Device'} has no child switches',
        );
      }

      final existing = raw.whereType<Map>().toList();
      var matched = false;

      final children = <Map<String, dynamic>>[];
      for (var i = 0; i < existing.length; i++) {
        final child = Map<String, dynamic>.from(existing[i]);
        final isTarget =
            matchId != null ? child['id'] == matchId : i == matchIndex;
        if (isTarget) {
          child['isOn'] = turnOn;
          matched = true;
        }
        children.add(child);
      }

      if (!matched) {
        throw AppException(
          'Switch ${matchId ?? matchIndex} not found on '
          '${data[Fields.name] ?? deviceId}',
        );
      }

      final anyOn = children.any((c) => c['isOn'] == true);
      final wasOn = current == DeviceStatusValues.on;

      final update = <String, dynamic>{
        Fields.childSwitches: children,
        Fields.status:
            anyOn ? DeviceStatusValues.on : DeviceStatusValues.off,
        Fields.statusReason: StatusReasons.manual,
        ..._stamp(),
      };

      // Only a genuine OFF -> ON edge starts the clock. Flipping a second
      // switch on a unit that is already live must not extend its budget.
      if (anyOn && !wasOn) {
        update[Fields.turnedOnAt] = FieldValue.serverTimestamp();
      } else if (!anyOn) {
        update[Fields.turnedOnAt] = null;
      }

      txn.update(ref, update);
    });
  }

  // --------------------------------------------------------- configuration

  /// Set the safety budget for a fire-hazard appliance, in minutes.
  ///
  /// Takes effect immediately: the worker re-arms from the current
  /// `turnedOnAt` whenever the document changes, so shortening the budget on a
  /// running iron shortens the time it has left rather than waiting for the
  /// next session.
  Future<void> updateApplianceSchedule(
    String deviceId,
    int maxOnMinutes,
  ) async {
    if (maxOnMinutes <= 0) {
      throw const AppException('Maximum ON duration must be at least 1 minute');
    }
    await _devices.doc(deviceId).update({
      Fields.maxOnDurationMinutes: maxOnMinutes,
      ..._stamp(),
    });
  }

  /// Set the automatic ON/OFF window for a light.
  ///
  /// Times are wall-clock `"HH:mm"` strings, not timestamps: "on at 18:30"
  /// means 18:30 every evening. The worker must therefore run in the same
  /// timezone the schedule was written in (Asia/Colombo for this project).
  Future<void> updateLightSchedule(
    String deviceId,
    String startHHmm,
    String endHHmm, {
    List<int>? days,
    bool enabled = true,
  }) async {
    _assertTimeFormat(startHHmm);
    _assertTimeFormat(endHHmm);

    await _devices.doc(deviceId).update({
      Fields.scheduleStartTime: startHHmm,
      Fields.scheduleEndTime: endHHmm,
      Fields.scheduleEnabled: enabled,
      // ISO weekdays, Monday 1 ... Sunday 7, matching DateTime.weekday.
      if (days != null) Fields.scheduleDays: days,
      ..._stamp(),
    });
  }

  Future<void> setScheduleEnabled(String deviceId, bool enabled) =>
      _devices.doc(deviceId).update({
        Fields.scheduleEnabled: enabled,
        ..._stamp(),
      });

  Future<void> clearLightSchedule(String deviceId) =>
      _devices.doc(deviceId).update({
        Fields.scheduleStartTime: null,
        Fields.scheduleEndTime: null,
        Fields.scheduleEnabled: false,
        ..._stamp(),
      });

  Future<void> renameDevice(String deviceId, String name) =>
      _devices.doc(deviceId).update({Fields.name: name, ..._stamp()});

  /// Move a device to another room.
  Future<void> moveDevice(String deviceId, String roomId, String floorId) =>
      _devices.doc(deviceId).update({
        Fields.roomId: roomId,
        Fields.floorId: floorId,
        ..._stamp(),
      });

  // ------------------------------------------------------------------- CRUD

  Future<String> createFloor({
    required String name,
    required int order,
    String? floorPlanImageUrl,
  }) async {
    final ref = await _floors.add({
      Fields.name: name,
      'order': order,
      'floorPlanImageUrl': floorPlanImageUrl,
    });
    return ref.id;
  }

  Future<void> updateFloor(
    String floorId, {
    String? name,
    int? order,
    String? floorPlanImageUrl,
  }) =>
      _floors.doc(floorId).update({
        if (name != null) Fields.name: name,
        if (order != null) 'order': order,
        if (floorPlanImageUrl != null) 'floorPlanImageUrl': floorPlanImageUrl,
      });

  /// Delete a floor, its rooms, and every device standing in them.
  ///
  /// Firestore has no cascade. Without this, deleting a floor leaves devices
  /// pointing at one that no longer exists -- they keep appearing in the
  /// all-devices stream and in the worker's safety checks.
  Future<void> deleteFloor(String floorId) async {
    final rooms = await _rooms.where(Fields.floorId, isEqualTo: floorId).get();
    final devices =
        await _devices.where(Fields.floorId, isEqualTo: floorId).get();

    final batch = _requireDb.batch();
    for (final doc in devices.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in rooms.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_floors.doc(floorId));
    await batch.commit();
  }

  Future<String> createRoom({
    required String floorId,
    required String name,
    required int gridRow,
    required int gridCol,
  }) async {
    final ref = await _rooms.add({
      Fields.floorId: floorId,
      Fields.name: name,
      'gridRow': gridRow,
      'gridCol': gridCol,
      Fields.deviceIds: <String>[],
    });
    await ref.update({Fields.id: ref.id});
    return ref.id;
  }

  Future<void> updateRoom(
    String roomId, {
    String? name,
    int? gridRow,
    int? gridCol,
  }) =>
      _rooms.doc(roomId).update({
        if (name != null) Fields.name: name,
        if (gridRow != null) 'gridRow': gridRow,
        if (gridCol != null) 'gridCol': gridCol,
      });

  Future<void> deleteRoom(String roomId) async {
    final devices = await _devices.where(Fields.roomId, isEqualTo: roomId).get();

    final batch = _requireDb.batch();
    for (final doc in devices.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_rooms.doc(roomId));
    await batch.commit();
  }

  Future<String> createDevice({
    required String name,
    required String roomId,
    required String floorId,
    required DeviceType type,
    List<SwitchChild> childSwitches = const [],
    int? maxOnDurationMinutes,
    List<String>? cameraImageUrls,
  }) async {
    final ref = await _devices.add({
      Fields.name: name,
      Fields.roomId: roomId,
      Fields.floorId: floorId,
      Fields.type: type.name,
      Fields.status: DeviceStatusValues.off,
      Fields.turnedOnAt: null,
      Fields.childSwitches: childSwitches.map((c) => c.toMap()).toList(),
      Fields.maxOnDurationMinutes: maxOnDurationMinutes,
      Fields.cameraImageUrls: cameraImageUrls,
      Fields.statusReason: StatusReasons.manual,
      ..._stamp(),
    });
    await ref.update({Fields.id: ref.id});
    return ref.id;
  }

  Future<void> deleteDevice(String deviceId) => _devices.doc(deviceId).delete();

  // ------------------------------------------------------------------ usage

  /// Raw event rows for one device, newest first.
  ///
  /// Needs the composite index on (deviceId, timestamp desc).
  Stream<List<Map<String, dynamic>>> streamUsageLogs(String deviceId) =>
      _guarded(
        () => _requireDb
            .collection(FirestorePaths.usageLogs)
            .where(UsageFields.deviceId, isEqualTo: deviceId)
            .orderBy(UsageFields.timestamp, descending: true)
            .limit(50)
            .snapshots()
            .map((snap) => snap.docs.map((d) => d.data()).toList()),
      );

  // ----------------------------------------------------------------- helpers

  /// Stamped on every write from the app.
  ///
  /// `updatedBy` is what lets the simulator and the worker recognise a change
  /// as somebody else's rather than an echo of their own, and it is the nicest
  /// thing to have on screen during a demo.
  Map<String, dynamic> _stamp() => {
        Fields.updatedBy: UpdateSources.app,
        Fields.lastUpdated: FieldValue.serverTimestamp(),
      };

  /// The worker matches schedule boundaries on an exact `"HH:mm"` string, so a
  /// time stored as `"6:30"` would simply never fire -- and never report why.
  void _assertTimeFormat(String value) {
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) {
      throw AppException('Expected 24-hour "HH:mm", got "$value"');
    }
  }
}
