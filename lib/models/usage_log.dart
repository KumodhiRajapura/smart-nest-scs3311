import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_nest_app/config/firestore_paths.dart';

import 'json_utils.dart';

/// What happened to a device.
enum UsageEvent {
  on('on'),
  off('off'),
  autoOffSafety('auto_off_safety'),
  error('error'),
  disconnected('disconnected');

  const UsageEvent(this.id);

  final String id;

  static UsageEvent fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => UsageEvent.off);

  /// Events that close a session and therefore carry a duration.
  bool get endsSession =>
      this == UsageEvent.off ||
      this == UsageEvent.autoOffSafety ||
      this == UsageEvent.disconnected;
}

/// One row of the device event log.
///
/// Written by the backend worker only, and `firestore.rules` denies this
/// collection to every client. Two reasons: the worker reacts to *status
/// transitions* rather than button presses, so a device switched on from the
/// simulator is measured exactly like one switched on from the phone; and with
/// a single writer there is no way to get two rows for one event, or to
/// fabricate usage from a handset.
class UsageLog {
  const UsageLog({
    required this.id,
    required this.deviceId,
    required this.event,
    required this.timestamp,
    this.deviceName = '',
    this.roomId = '',
    this.durationOnSeconds,
    this.createdBy,
  });

  factory UsageLog.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return UsageLog.fromMap(doc.id, data);
  }

  factory UsageLog.fromMap(String id, Map<String, dynamic> data) {
    // Seconds is the field the worker writes now; minutes is kept for rows
    // written before that, and for anything reading the schema literally.
    final seconds = asIntOrNull(data[UsageFields.durationOnSeconds]) ??
        (asIntOrNull(data[UsageFields.durationOnMinutes]) != null
            ? asIntOrNull(data[UsageFields.durationOnMinutes])! * 60
            : null);

    return UsageLog(
      id: id,
      deviceId: asString(data[UsageFields.deviceId]),
      deviceName: asString(data[UsageFields.deviceName]),
      roomId: asString(data[UsageFields.roomId]),
      event: UsageEvent.fromId(asStringOrNull(data[UsageFields.event])),
      timestamp: asDate(data[UsageFields.timestamp]) ?? DateTime.now(),
      durationOnSeconds: seconds,
      createdBy: asStringOrNull(data[UsageFields.createdBy]),
    );
  }

  final String id;
  final String deviceId;
  final String deviceName;
  final String roomId;
  final UsageEvent event;
  final DateTime timestamp;

  /// How long the device had been on, on an event that ends a session.
  final int? durationOnSeconds;

  final String? createdBy;

  Duration get duration => Duration(seconds: durationOnSeconds ?? 0);

  /// True when the worker, not a person, ended this session.
  bool get wasCutOff => event == UsageEvent.autoOffSafety;
}

/// Aggregated usage for one device over a reporting window.
class DeviceUsageSummary {
  const DeviceUsageSummary({
    required this.deviceId,
    required this.deviceName,
    required this.totalDuration,
    required this.sessionCount,
    this.safetyCutoffCount = 0,
  });

  final String deviceId;
  final String deviceName;
  final Duration totalDuration;
  final int sessionCount;

  /// How many of those sessions the safety worker had to end. A non-zero
  /// number here is the most interesting line in the whole report.
  final int safetyCutoffCount;

  Duration get averageSession => sessionCount == 0
      ? Duration.zero
      : Duration(seconds: totalDuration.inSeconds ~/ sessionCount);

  /// `2h 14m`, `43m`, or `12s` -- short enough for a list tile.
  String get formattedTotal => formatDuration(totalDuration);

  static String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${s}s';
  }
}
