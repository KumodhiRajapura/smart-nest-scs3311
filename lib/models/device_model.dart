import 'package:cloud_firestore/cloud_firestore.dart';

enum DeviceType { outlet, multiSwitch, scheduledAppliance, scheduledLight, camera }

enum DeviceStatus { on, off, error, disconnected }

class SwitchChild {
  final String id;
  final String label;
  final bool isOn;

  const SwitchChild({required this.id, required this.label, required this.isOn});

  Map<String, dynamic> toMap() => {'id': id, 'label': label, 'isOn': isOn};

  factory SwitchChild.fromMap(Map<String, dynamic> m) => SwitchChild(
        id: m['id'] ?? '',
        label: m['label'] ?? '',
        isOn: m['isOn'] == true,
      );
}

class SmartDevice {
  final String id;
  final String name;
  final String roomId;
  final DeviceType type;
  final DeviceStatus status;
  final String? iconName;
  final List<SwitchChild> childSwitches;
  final int? maxOnDurationMinutes;
  final DateTime? turnedOnAt; // Firestore Timestamp stored as ISO string or Timestamp
  final String? scheduleStartTime; // "HH:mm"
  final String? scheduleEndTime; // "HH:mm"
  final List<String>? cameraImageUrls;
  final String? lastAlert;
  final double powerUsage;

  const SmartDevice({
    required this.id,
    required this.name,
    required this.roomId,
    required this.type,
    required this.status,
    this.iconName,
    this.childSwitches = const [],
    this.maxOnDurationMinutes,
    this.turnedOnAt,
    this.scheduleStartTime,
    this.scheduleEndTime,
    this.cameraImageUrls,
    this.lastAlert,
    this.powerUsage = 0.0,
  });

  SmartDevice copyWith({
    String? id,
    String? name,
    String? roomId,
    DeviceType? type,
    DeviceStatus? status,
    String? iconName,
    List<SwitchChild>? childSwitches,
    int? maxOnDurationMinutes,
    DateTime? turnedOnAt,
    String? scheduleStartTime,
    String? scheduleEndTime,
    List<String>? cameraImageUrls,
    String? lastAlert,
    double? powerUsage,
  }) {
    return SmartDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      roomId: roomId ?? this.roomId,
      type: type ?? this.type,
      status: status ?? this.status,
      iconName: iconName ?? this.iconName,
      childSwitches: childSwitches ?? this.childSwitches,
      maxOnDurationMinutes: maxOnDurationMinutes ?? this.maxOnDurationMinutes,
      turnedOnAt: turnedOnAt ?? this.turnedOnAt,
      scheduleStartTime: scheduleStartTime ?? this.scheduleStartTime,
      scheduleEndTime: scheduleEndTime ?? this.scheduleEndTime,
      cameraImageUrls: cameraImageUrls ?? this.cameraImageUrls,
      lastAlert: lastAlert ?? this.lastAlert,
      powerUsage: powerUsage ?? this.powerUsage,
    );
  }

  bool get isMultiSwitch => childSwitches.isNotEmpty;

  // Compatibility getters used by older UI/services
  bool get isOn => status == DeviceStatus.on;
  List<bool> get switches => childSwitches.map((c) => c.isOn).toList();
  List<bool> get multiSwitchStates => switches;
  DateTime? get lastTurnedOnAt => turnedOnAt;

  /// Returns true if scheduleStartTime/scheduleEndTime indicate device should be on now.
  bool scheduledShouldBeOn(DateTime now) {
    if (scheduleStartTime == null || scheduleEndTime == null) return false;
    try {
      int parseTime(String hhmm) {
        final parts = hhmm.split(':');
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }
      final minutesNow = now.hour * 60 + now.minute;
      final start = parseTime(scheduleStartTime!);
      final end = parseTime(scheduleEndTime!);
      if (start <= end) return minutesNow >= start && minutesNow < end;
      return minutesNow >= start || minutesNow < end;
    } catch (_) {
      return false;
    }
  }

  bool hasExceededMaxDuration(DateTime now) {
    if (maxOnDurationMinutes == null || turnedOnAt == null) return false;
    return now.difference(turnedOnAt!).inMinutes >= maxOnDurationMinutes!;
  }

  /// helper to parse DeviceType from string
  static DeviceType _typeFromString(String? s) {
    switch (s) {
      case 'outlet':
        return DeviceType.outlet;
      case 'multiSwitch':
        return DeviceType.multiSwitch;
      case 'scheduledAppliance':
        return DeviceType.scheduledAppliance;
      case 'scheduledLight':
        return DeviceType.scheduledLight;
      case 'camera':
        return DeviceType.camera;
      default:
        return DeviceType.outlet;
    }
  }

  static DeviceStatus _statusFromString(String? s) {
    switch (s) {
      case 'on':
        return DeviceStatus.on;
      case 'off':
        return DeviceStatus.off;
      case 'error':
        return DeviceStatus.error;
      case 'disconnected':
        return DeviceStatus.disconnected;
      default:
        return DeviceStatus.off;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'roomId': roomId,
      'type': type.name,
      'status': status.name,
      'iconName': iconName,
      'childSwitches': childSwitches.map((s) => s.toMap()).toList(),
      'maxOnDurationMinutes': maxOnDurationMinutes,
      'turnedOnAt': turnedOnAt != null ? Timestamp.fromDate(turnedOnAt!) : null,
      'scheduleStartTime': scheduleStartTime,
      'scheduleEndTime': scheduleEndTime,
      'cameraImageUrls': cameraImageUrls,
      'lastAlert': lastAlert,
      'powerUsage': powerUsage,
    };
  }

  factory SmartDevice.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    DateTime? turned;
    final t = map['turnedOnAt'];
    if (t != null) {
      if (t is Timestamp) {
        turned = t.toDate();
      } else if (t is String) {
        try {
          turned = DateTime.parse(t).toLocal();
        } catch (_) {
          turned = null;
        }
      }
    }

    final cs = <SwitchChild>[];
    if (map['childSwitches'] is List) {
      for (final e in map['childSwitches']) {
        if (e is Map<String, dynamic>) cs.add(SwitchChild.fromMap(e));
      }
    }

    final cameraUrls = <String>[];
    if (map['cameraImageUrls'] is List) {
      for (final e in map['cameraImageUrls']) {
        if (e is String) cameraUrls.add(e);
      }
    }

    return SmartDevice(
      id: map['id'] ?? doc.id,
      name: map['name'] ?? '',
      roomId: map['roomId'] ?? '',
      type: _typeFromString(map['type']),
      status: _statusFromString(map['status']),
      iconName: map['iconName'],
      childSwitches: cs,
      maxOnDurationMinutes: map['maxOnDurationMinutes'] is int ? map['maxOnDurationMinutes'] as int : null,
      turnedOnAt: turned,
      scheduleStartTime: map['scheduleStartTime'] as String?,
      scheduleEndTime: map['scheduleEndTime'] as String?,
      cameraImageUrls: cameraUrls.isNotEmpty ? cameraUrls : null,
      lastAlert: map['lastAlert'] as String?,
      powerUsage: (map['powerUsage'] is num) ? (map['powerUsage'] as num).toDouble() : 0.0,
    );
  }
}
