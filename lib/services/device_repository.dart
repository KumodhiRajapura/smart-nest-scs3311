import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/device.dart';
import 'firestore_refs.dart';

/// Thrown when a control action is not legal for the device's current state.
class DeviceControlException implements Exception {
  const DeviceControlException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The only door between the UI and the `devices` collection.
///
/// Reads are streams, writes are fire-and-forget futures. The UI never applies
/// a state change itself: it writes to Firestore and waits for the snapshot to
/// come back. That single rule is what keeps the phone, the simulator and the
/// worker showing the same thing, and it is why an externally driven change
/// needs no refresh button.
class DeviceRepository {
  const DeviceRepository();

  // ---------------------------------------------------------------- reads

  /// All devices, ordered so the list does not jump around between snapshots.
  Stream<List<Device>> watchAll() => Refs.devices
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs.map(Device.fromDoc).toList());

  /// Devices on one floor plan.
  ///
  /// Needs the composite index on (floorId, name) -- see
  /// `firestore.indexes.json`. Without it this stream throws on first listen.
  Stream<List<Device>> watchByFloor(String floorId) => Refs.devices
      .where('floorId', isEqualTo: floorId)
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs.map(Device.fromDoc).toList());

  Stream<Device?> watchDevice(String deviceId) => Refs.device(deviceId)
      .snapshots()
      .map((doc) => doc.exists ? Device.fromDoc(doc) : null);

  /// Devices that carry a safety budget, for the safety panel.
  Stream<List<Device>> watchSafetyDevices() => Refs.devices
      .where('maxOnDurationMinutes', isGreaterThan: 0)
      .snapshots()
      .map((snap) => snap.docs.map(Device.fromDoc).toList());

  Future<Device?> getDevice(String deviceId) async {
    final doc = await Refs.device(deviceId).get();
    return doc.exists ? Device.fromDoc(doc) : null;
  }

  // --------------------------------------------------------------- writes

  /// Switch a whole device on or off.
  ///
  /// [turnedOnAt] is a *server* timestamp: the worker's countdown must not
  /// depend on how far the phone's clock has drifted. On the way off it is
  /// cleared, which is the signal the worker uses to disarm the cutoff.
  Future<void> setPower(Device device, bool on, {String? reason}) async {
    if (!device.type.isSwitchable) {
      throw DeviceControlException('${device.name} cannot be switched.');
    }
    if (device.status == DeviceStatus.disconnected) {
      throw DeviceControlException(
        '${device.name} is disconnected. Bring it back online first.',
      );
    }

    final update = <String, dynamic>{
      'status': on ? DeviceStatus.on.id : DeviceStatus.off.id,
      'turnedOnAt': on ? FieldValue.serverTimestamp() : null,
      'statusReason': reason ?? StatusReason.manual,
      ..._meta(),
    };

    // A gang box has no meaning without its channels: switching the unit off
    // must switch every switch inside it off too.
    if (device.type.hasChannels && device.channels.isNotEmpty) {
      update['channels'] =
          device.channels.map((c) => c.copyWith(isOn: on).toMap()).toList();
    }

    await Refs.device(device.id).update(update);
  }

  Future<void> toggle(Device device) => setPower(device, !device.isOn);

  /// Switch one addressable switch inside a gang box.
  ///
  /// Firestore cannot update a single array element, so the array is rewritten
  /// inside a transaction. The transaction also matters for correctness: two
  /// people flipping switch 1 and switch 3 at the same moment would otherwise
  /// each write back a copy of the array that discards the other's change.
  Future<void> setChannel({
    required String deviceId,
    required int channelIndex,
    required bool isOn,
  }) async {
    final ref = Refs.device(deviceId);

    await Refs.db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) {
        throw const DeviceControlException('Device no longer exists.');
      }

      final device = Device.fromDoc(snap);
      if (!device.type.hasChannels) {
        throw DeviceControlException('${device.name} has no switch channels.');
      }
      if (device.status == DeviceStatus.disconnected) {
        throw DeviceControlException('${device.name} is disconnected.');
      }

      final channels = device.channels
          .map((c) => c.index == channelIndex ? c.copyWith(isOn: isOn) : c)
          .toList();

      // The unit is ON while any one of its switches is ON.
      final anyOn = channels.any((c) => c.isOn);
      final wasOn = device.isOn;

      final update = <String, dynamic>{
        'channels': channels.map((c) => c.toMap()).toList(),
        'status': anyOn ? DeviceStatus.on.id : DeviceStatus.off.id,
        'statusReason': StatusReason.manual,
        ..._meta(),
      };

      // Only restart the clock on a genuine OFF -> ON edge, so flipping a
      // second switch does not hand the unit a fresh safety budget.
      if (anyOn && !wasOn) update['turnedOnAt'] = FieldValue.serverTimestamp();
      if (!anyOn) update['turnedOnAt'] = null;

      txn.update(ref, update);
    });
  }

  /// Create a device and return its generated id.
  Future<String> create(Device device) async {
    final ref = await Refs.devices.add({
      ...device.toCreateMap(),
      'status': DeviceStatus.off.id,
      'turnedOnAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      ..._meta(),
    });
    return ref.id;
  }

  /// Edit the configuration of a device -- not its power state.
  Future<void> updateConfig(
    String deviceId, {
    String? name,
    String? room,
    int? gridX,
    int? gridY,
    int? maxOnDurationMinutes,
    String? streamUrl,
  }) =>
      Refs.device(deviceId).update({
        if (name != null) 'name': name,
        if (room != null) 'room': room,
        if (gridX != null) 'gridX': gridX,
        if (gridY != null) 'gridY': gridY,
        if (maxOnDurationMinutes != null)
          'maxOnDurationMinutes': maxOnDurationMinutes,
        if (streamUrl != null) 'streamUrl': streamUrl,
        ..._meta(),
      });

  /// Move a device to another cell of the floor grid.
  Future<void> moveTo(String deviceId, int gridX, int gridY) =>
      Refs.device(deviceId).update({
        'gridX': gridX,
        'gridY': gridY,
        ..._meta(),
      });

  Future<void> delete(String deviceId) => Refs.device(deviceId).delete();

  /// Force a status, including the two states the user cannot reach.
  ///
  /// Only for the developer tools and tests -- production status changes come
  /// from [setPower], the simulator or the worker.
  Future<void> debugForceStatus(String deviceId, DeviceStatus status) =>
      Refs.device(deviceId).update({
        'status': status.id,
        'turnedOnAt':
            status == DeviceStatus.on ? FieldValue.serverTimestamp() : null,
        'statusReason': 'debug',
        ..._meta(),
      });

  /// Stamped on every write from this client.
  ///
  /// `updatedBy` tells the simulator and the worker that a change originated
  /// here, so they can ignore their own echo instead of reacting to it.
  Map<String, dynamic> _meta() => {
        'updatedBy': UpdateSource.app,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
