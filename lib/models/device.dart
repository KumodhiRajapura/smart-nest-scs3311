import 'package:cloud_firestore/cloud_firestore.dart';

import 'json_utils.dart';

/// Hardware profile of a device.
///
/// The string [id] is what lands in Firestore. Never persist the enum index --
/// reordering the enum would silently rewrite the meaning of existing data.
enum DeviceType {
  outlet('outlet'),
  multiSwitch('multiswitch'),
  light('light'),
  iron('iron'),
  camera('camera');

  const DeviceType(this.id);

  final String id;

  static DeviceType fromId(String? id) =>
      values.firstWhere((t) => t.id == id, orElse: () => DeviceType.outlet);

  /// Cameras only stream; everything else can be switched.
  bool get isSwitchable => this != DeviceType.camera;

  /// Gang boxes hold a list of individually addressable channels.
  bool get hasChannels => this == DeviceType.multiSwitch;
}

/// Operational status required by the spec.
enum DeviceStatus {
  on('ON'),
  off('OFF'),
  error('ERROR'),
  disconnected('DISCONNECTED');

  const DeviceStatus(this.id);

  final String id;

  static DeviceStatus fromId(String? id) =>
      values.firstWhere((s) => s.id == id, orElse: () => DeviceStatus.off);

  /// Only ON/OFF are reachable from the app. ERROR and DISCONNECTED are
  /// reported by the simulator or the worker, so the UI shows them read-only.
  bool get isUserSettable => this == DeviceStatus.on || this == DeviceStatus.off;
}

/// Who wrote the document last.
///
/// This is the mechanism that stops the app, the simulator and the worker from
/// echoing each other's writes forever, and it is worth surfacing in the UI --
/// "turned OFF by worker" is a much better demo than a value that just changes.
abstract final class UpdateSource {
  static const app = 'app';
  static const worker = 'worker';
  static const simulator = 'simulator';
  static const schedule = 'schedule';
}

/// Reason attached to a status change, when there is one worth recording.
abstract final class StatusReason {
  static const manual = 'manual';
  static const safetyCutoff = 'safety_cutoff';
  static const schedule = 'schedule';
  static const heartbeatLost = 'heartbeat_lost';
  static const simulatorFault = 'simulator_fault';
}

/// One addressable switch inside a multi-switch gang box.
class SwitchChannel {
  const SwitchChannel({
    required this.index,
    required this.label,
    required this.isOn,
  });

  factory SwitchChannel.fromMap(Map<String, dynamic> map) => SwitchChannel(
        index: asInt(map['index']),
        label: asString(map['label'], fallback: 'Switch'),
        isOn: asBool(map['isOn']),
      );

  final int index;
  final String label;
  final bool isOn;

  Map<String, dynamic> toMap() => {'index': index, 'label': label, 'isOn': isOn};

  SwitchChannel copyWith({String? label, bool? isOn}) => SwitchChannel(
        index: index,
        label: label ?? this.label,
        isOn: isOn ?? this.isOn,
      );
}

/// A single entity in the system.
///
/// A gang box with five switches is *one* Device with five [channels], not five
/// documents -- the spec asks for it to be mapped to a single entity, and it
/// also keeps one device to one cell of the floor grid.
class Device {
  const Device({
    required this.id,
    required this.floorId,
    required this.name,
    required this.type,
    required this.status,
    this.room = '',
    this.gridX = 0,
    this.gridY = 0,
    this.channels = const [],
    this.maxOnDurationMinutes,
    this.turnedOnAt,
    this.streamUrl,
    this.lastHeartbeat,
    this.updatedBy,
    this.updatedAt,
    this.statusReason,
  });

  factory Device.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Device(
      id: doc.id,
      floorId: asString(data['floorId']),
      name: asString(data['name'], fallback: 'Unnamed device'),
      type: DeviceType.fromId(asStringOrNull(data['type'])),
      status: DeviceStatus.fromId(asStringOrNull(data['status'])),
      room: asString(data['room']),
      gridX: asInt(data['gridX']),
      gridY: asInt(data['gridY']),
      channels: asMapList(data['channels']).map(SwitchChannel.fromMap).toList()
        ..sort((a, b) => a.index.compareTo(b.index)),
      maxOnDurationMinutes: asIntOrNull(data['maxOnDurationMinutes']),
      turnedOnAt: asDate(data['turnedOnAt']),
      streamUrl: asStringOrNull(data['streamUrl']),
      lastHeartbeat: asDate(data['lastHeartbeat']),
      updatedBy: asStringOrNull(data['updatedBy']),
      updatedAt: asDate(data['updatedAt']),
      statusReason: asStringOrNull(data['statusReason']),
    );
  }

  final String id;
  final String floorId;
  final String name;
  final DeviceType type;
  final DeviceStatus status;
  final String room;

  /// Position on the abstract grid overlaid on the floor plan.
  final int gridX;
  final int gridY;

  /// Populated for [DeviceType.multiSwitch] only.
  final List<SwitchChannel> channels;

  /// Safety cutoff budget, in minutes. Only set for fire-hazard appliances.
  final int? maxOnDurationMinutes;

  /// Server timestamp of the most recent OFF -> ON transition. The worker
  /// derives the whole safety countdown from this one field, which is why the
  /// cutoff survives a worker restart.
  final DateTime? turnedOnAt;

  /// Mock stream / snapshot URI for [DeviceType.camera].
  final String? streamUrl;

  final DateTime? lastHeartbeat;
  final String? updatedBy;
  final DateTime? updatedAt;
  final String? statusReason;

  bool get isOn => status == DeviceStatus.on;

  bool get isOnline =>
      status != DeviceStatus.disconnected && status != DeviceStatus.error;

  bool get hasSafetyLimit =>
      maxOnDurationMinutes != null && maxOnDurationMinutes! > 0;

  int get onChannelCount => channels.where((c) => c.isOn).length;

  /// How long the device has been continuously ON, or null if it is not ON.
  ///
  /// [turnedOnAt] is a server timestamp, so it reads back null for a few
  /// hundred milliseconds while the write is still pending locally.
  Duration? get onDuration {
    if (!isOn || turnedOnAt == null) return null;
    return DateTime.now().difference(turnedOnAt!);
  }

  /// Seconds left before the worker cuts this device off. Null when there is no
  /// limit or the device is off; clamped at zero once the budget is spent.
  int? get remainingSafetySeconds {
    if (!hasSafetyLimit) return null;
    final elapsed = onDuration;
    if (elapsed == null) return null;
    final budget = maxOnDurationMinutes! * 60;
    final left = budget - elapsed.inSeconds;
    return left < 0 ? 0 : left;
  }

  /// Fields written when the device is first created. Status is deliberately
  /// not included -- [DeviceRepository.create] sets it explicitly.
  Map<String, dynamic> toCreateMap() => {
        'floorId': floorId,
        'name': name,
        'type': type.id,
        'room': room,
        'gridX': gridX,
        'gridY': gridY,
        'channels': channels.map((c) => c.toMap()).toList(),
        if (maxOnDurationMinutes != null)
          'maxOnDurationMinutes': maxOnDurationMinutes,
        if (streamUrl != null) 'streamUrl': streamUrl,
      };

  Device copyWith({
    String? name,
    String? room,
    DeviceStatus? status,
    int? gridX,
    int? gridY,
    List<SwitchChannel>? channels,
    int? maxOnDurationMinutes,
    String? streamUrl,
  }) =>
      Device(
        id: id,
        floorId: floorId,
        name: name ?? this.name,
        type: type,
        status: status ?? this.status,
        room: room ?? this.room,
        gridX: gridX ?? this.gridX,
        gridY: gridY ?? this.gridY,
        channels: channels ?? this.channels,
        maxOnDurationMinutes: maxOnDurationMinutes ?? this.maxOnDurationMinutes,
        turnedOnAt: turnedOnAt,
        streamUrl: streamUrl ?? this.streamUrl,
        lastHeartbeat: lastHeartbeat,
        updatedBy: updatedBy,
        updatedAt: updatedAt,
        statusReason: statusReason,
      );
}
