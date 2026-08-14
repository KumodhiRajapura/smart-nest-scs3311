import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/schedule.dart';
import 'firestore_refs.dart';

/// CRUD for automatic ON/OFF windows.
///
/// The app only ever *describes* a schedule. Nothing here runs it -- the Node
/// worker is what watches the clock, so a schedule still fires when every phone
/// in the house is asleep in a drawer.
class ScheduleRepository {
  const ScheduleRepository();

  Stream<List<Schedule>> watchAll() => Refs.schedules
      .snapshots()
      .map((snap) => snap.docs.map(Schedule.fromDoc).toList());

  Stream<List<Schedule>> watchForDevice(String deviceId) => Refs.schedules
      .where('deviceId', isEqualTo: deviceId)
      .snapshots()
      .map((snap) => snap.docs.map(Schedule.fromDoc).toList());

  Future<String> create({
    required String deviceId,
    required String startTime,
    required String endTime,
    int? channelIndex,
    String label = '',
    List<int> daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    bool enabled = true,
  }) async {
    _assertTimeFormat(startTime);
    _assertTimeFormat(endTime);

    final ref = await Refs.schedules.add({
      'deviceId': deviceId,
      'startTime': startTime,
      'endTime': endTime,
      'channelIndex': channelIndex,
      'label': label,
      'daysOfWeek': daysOfWeek,
      'enabled': enabled,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(
    String scheduleId, {
    String? startTime,
    String? endTime,
    int? channelIndex,
    String? label,
    List<int>? daysOfWeek,
    bool? enabled,
  }) {
    if (startTime != null) _assertTimeFormat(startTime);
    if (endTime != null) _assertTimeFormat(endTime);

    return Refs.schedule(scheduleId).update({
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      if (channelIndex != null) 'channelIndex': channelIndex,
      if (label != null) 'label': label,
      if (daysOfWeek != null) 'daysOfWeek': daysOfWeek,
      if (enabled != null) 'enabled': enabled,
    });
  }

  Future<void> setEnabled(String scheduleId, bool enabled) =>
      Refs.schedule(scheduleId).update({'enabled': enabled});

  Future<void> delete(String scheduleId) => Refs.schedule(scheduleId).delete();

  /// The worker matches on an exact `"HH:mm"` string. A schedule stored as
  /// `"6:30"` would simply never fire, and silently -- so reject it at the door.
  void _assertTimeFormat(String value) {
    final ok = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);
    if (!ok) {
      throw ArgumentError.value(value, 'time', 'Expected 24-hour "HH:mm"');
    }
  }
}
