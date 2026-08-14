import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_nest_app/config/firestore_paths.dart';

import 'json_utils.dart';

enum AlertSeverity {
  info('info'),
  warning('warning'),
  critical('critical');

  const AlertSeverity(this.id);

  final String id;

  static AlertSeverity fromId(String? id) =>
      values.firstWhere((s) => s.id == id, orElse: () => AlertSeverity.info);
}

enum AlertType {
  safetyCutoff('safety_cutoff'),
  deviceError('device_error'),
  deviceOffline('device_offline'),
  scheduleRun('schedule_run');

  const AlertType(this.id);

  final String id;

  static AlertType fromId(String? id) =>
      values.firstWhere((t) => t.id == id, orElse: () => AlertType.deviceError);
}

/// An event the user needs to know about.
///
/// Written by the backend worker only. The Firestore document is the durable
/// record; the FCM push is just the nudge -- so nothing is lost if the phone
/// was off, notifications were denied, or the push was dropped. That is why the
/// alerts screen reads this collection rather than a list of notifications.
class Alert {
  const Alert({
    required this.id,
    required this.message,
    required this.createdAt,
    this.type = AlertType.deviceError,
    this.severity = AlertSeverity.info,
    this.deviceId = '',
    this.deviceName = '',
    this.acknowledged = false,
  });

  factory Alert.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Alert(
      id: doc.id,
      message: asString(data[AlertFields.message]),
      createdAt: asDate(data[AlertFields.createdAt]) ?? DateTime.now(),
      type: AlertType.fromId(asStringOrNull(data[AlertFields.type])),
      severity: AlertSeverity.fromId(asStringOrNull(data[AlertFields.severity])),
      deviceId: asString(data[AlertFields.deviceId]),
      deviceName: asString(data[AlertFields.deviceName]),
      acknowledged: asBool(data[AlertFields.acknowledged]),
    );
  }

  final String id;
  final String message;
  final DateTime createdAt;
  final AlertType type;
  final AlertSeverity severity;
  final String deviceId;
  final String deviceName;
  final bool acknowledged;

  bool get isCritical => severity == AlertSeverity.critical;

  String get title => switch (type) {
        AlertType.safetyCutoff => 'Safety cutoff',
        AlertType.deviceError => 'Device error',
        AlertType.deviceOffline => 'Device offline',
        AlertType.scheduleRun => 'Schedule ran',
      };
}
