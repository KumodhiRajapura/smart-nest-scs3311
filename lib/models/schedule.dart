import 'package:cloud_firestore/cloud_firestore.dart';

import 'json_utils.dart';

/// An automatic ON/OFF window for a device.
///
/// Times are stored as `"HH:mm"` local-wall-clock strings rather than
/// timestamps: "turn the porch light on at 18:30" means 18:30 every day, not a
/// fixed instant. The worker and the app must therefore agree on the timezone;
/// both run on Asia/Colombo for this project.
class Schedule {
  const Schedule({
    required this.id,
    required this.deviceId,
    required this.startTime,
    required this.endTime,
    this.channelIndex,
    this.label = '',
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    this.enabled = true,
    this.lastRunAt,
  });

  factory Schedule.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Schedule(
      id: doc.id,
      deviceId: asString(data['deviceId']),
      startTime: asString(data['startTime'], fallback: '00:00'),
      endTime: asString(data['endTime'], fallback: '00:00'),
      channelIndex: asIntOrNull(data['channelIndex']),
      label: asString(data['label']),
      daysOfWeek: asIntList(data['daysOfWeek']).isEmpty
          ? const [1, 2, 3, 4, 5, 6, 7]
          : asIntList(data['daysOfWeek']),
      enabled: asBool(data['enabled'], fallback: true),
      lastRunAt: asDate(data['lastRunAt']),
    );
  }

  final String id;
  final String deviceId;

  /// `"HH:mm"` -- the minute the device is switched ON.
  final String startTime;

  /// `"HH:mm"` -- the minute the device is switched OFF.
  final String endTime;

  /// Which switch of a gang box this applies to. Null targets the whole device.
  final int? channelIndex;

  final String label;

  /// ISO weekdays, Monday = 1 ... Sunday = 7, matching [DateTime.weekday].
  final List<int> daysOfWeek;

  final bool enabled;
  final DateTime? lastRunAt;

  static int _minutesOf(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  int get startMinutes => _minutesOf(startTime);
  int get endMinutes => _minutesOf(endTime);

  /// True when the window wraps past midnight, e.g. 22:00 -> 06:00.
  bool get isOvernight => endMinutes <= startMinutes;

  /// Whether [now] falls inside the window, handling the overnight case.
  bool isActiveAt(DateTime now) {
    if (!enabled) return false;
    if (!daysOfWeek.contains(now.weekday)) return false;
    final minutes = now.hour * 60 + now.minute;
    if (isOvernight) return minutes >= startMinutes || minutes < endMinutes;
    return minutes >= startMinutes && minutes < endMinutes;
  }

  Map<String, dynamic> toMap() => {
        'deviceId': deviceId,
        'startTime': startTime,
        'endTime': endTime,
        'channelIndex': channelIndex,
        'label': label,
        'daysOfWeek': daysOfWeek,
        'enabled': enabled,
      };

  Schedule copyWith({
    String? startTime,
    String? endTime,
    int? channelIndex,
    String? label,
    List<int>? daysOfWeek,
    bool? enabled,
  }) =>
      Schedule(
        id: id,
        deviceId: deviceId,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        channelIndex: channelIndex ?? this.channelIndex,
        label: label ?? this.label,
        daysOfWeek: daysOfWeek ?? this.daysOfWeek,
        enabled: enabled ?? this.enabled,
        lastRunAt: lastRunAt,
      );
}
