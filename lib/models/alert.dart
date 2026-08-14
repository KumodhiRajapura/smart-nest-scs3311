import 'package:cloud_firestore/cloud_firestore.dart';

import 'json_utils.dart';

enum AlertType {
  safetyCutoff('safety_cutoff'),
  deviceError('device_error'),
  deviceOffline('device_offline'),
  scheduleRun('schedule_run');

  const AlertType(this.id);

  final String id;

  static AlertType fromId(String? id) =>
      values.firstWhere((t) => t.id == id, orElse: () => AlertType.deviceError);

  bool get isCritical => this == AlertType.safetyCutoff;
}

/// An event the user needs to know about.
///
/// Alerts are written by the worker and mirrored to the phone through FCM. The
/// Firestore document is the durable record -- the push is only the nudge, so
/// nothing is lost if the app was closed when the notification fired.
class Alert {
  const Alert({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
    this.deviceId = '',
    this.deviceName = '',
    this.read = false,
  });

  factory Alert.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Alert(
      id: doc.id,
      type: AlertType.fromId(asStringOrNull(data['type'])),
      message: asString(data['message']),
      createdAt: asDate(data['createdAt']) ?? DateTime.now(),
      deviceId: asString(data['deviceId']),
      deviceName: asString(data['deviceName']),
      read: asBool(data['read']),
    );
  }

  final String id;
  final AlertType type;
  final String message;
  final DateTime createdAt;
  final String deviceId;
  final String deviceName;
  final bool read;

  String get title => switch (type) {
        AlertType.safetyCutoff => 'Safety cutoff',
        AlertType.deviceError => 'Device error',
        AlertType.deviceOffline => 'Device offline',
        AlertType.scheduleRun => 'Schedule ran',
      };
}
