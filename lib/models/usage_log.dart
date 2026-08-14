import 'package:cloud_firestore/cloud_firestore.dart';

import 'json_utils.dart';

/// One continuous ON session of a device.
///
/// Written by the Node worker, never by the app. A single writer means no
/// duplicate sessions when the app and the simulator both react to the same
/// state change, and usage figures cannot be inflated from a client.
///
/// A log with [offAt] == null is the session that is happening right now.
class UsageLog {
  const UsageLog({
    required this.id,
    required this.deviceId,
    required this.onAt,
    this.deviceName = '',
    this.floorId = '',
    this.offAt,
    this.durationSeconds,
    this.endedBy,
  });

  factory UsageLog.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return UsageLog(
      id: doc.id,
      deviceId: asString(data['deviceId']),
      deviceName: asString(data['deviceName']),
      floorId: asString(data['floorId']),
      onAt: asDate(data['onAt']) ?? DateTime.now(),
      offAt: asDate(data['offAt']),
      durationSeconds: asIntOrNull(data['durationSeconds']),
      endedBy: asStringOrNull(data['endedBy']),
    );
  }

  final String id;
  final String deviceId;

  /// Denormalised so the report screen renders without a join.
  final String deviceName;
  final String floorId;

  final DateTime onAt;
  final DateTime? offAt;
  final int? durationSeconds;

  /// `app`, `worker`, `simulator` or `schedule` -- who ended the session.
  final String? endedBy;

  bool get isOpen => offAt == null;

  /// Duration of the session, counting up to now while it is still open.
  Duration get duration {
    if (durationSeconds != null) return Duration(seconds: durationSeconds!);
    return (offAt ?? DateTime.now()).difference(onAt);
  }
}

/// Aggregated usage for one device over a reporting window.
class DeviceUsageSummary {
  const DeviceUsageSummary({
    required this.deviceId,
    required this.deviceName,
    required this.totalDuration,
    required this.sessionCount,
  });

  final String deviceId;
  final String deviceName;
  final Duration totalDuration;
  final int sessionCount;

  Duration get averageSession => sessionCount == 0
      ? Duration.zero
      : Duration(seconds: totalDuration.inSeconds ~/ sessionCount);

  /// `2h 14m`, or `43m`, or `12s` -- compact enough for a list tile.
  String get formattedTotal {
    final h = totalDuration.inHours;
    final m = totalDuration.inMinutes.remainder(60);
    final s = totalDuration.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${s}s';
  }
}
