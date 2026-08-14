import 'package:cloud_firestore/cloud_firestore.dart';

class Room {
  final String id;
  final String floorId;
  final String name;
  final int gridRow;
  final int gridCol;
  final List<String> deviceIds;

  // Optional UI fields for older widgets / fixtures
  final String? description;
  final int devicesCount;
  final double temperature;
  final bool climateEnabled;

  const Room({
    required this.id,
    required this.floorId,
    required this.name,
    required this.gridRow,
    required this.gridCol,
    this.deviceIds = const [],
    this.description,
    this.devicesCount = 0,
    this.temperature = 0.0,
    this.climateEnabled = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'floorId': floorId,
        'name': name,
        'gridRow': gridRow,
        'gridCol': gridCol,
        'deviceIds': deviceIds,
        'description': description,
        'devicesCount': devicesCount,
        'temperature': temperature,
        'climateEnabled': climateEnabled,
      };

  factory Room.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    final ids = <String>[];
    if (map['deviceIds'] is List) {
      for (final e in map['deviceIds']) {
        if (e is String) ids.add(e);
      }
    }
    return Room(
      id: map['id'] ?? doc.id,
      floorId: map['floorId'] ?? '',
      name: map['name'] ?? '',
      gridRow: map['gridRow'] is int ? map['gridRow'] as int : 0,
      gridCol: map['gridCol'] is int ? map['gridCol'] as int : 0,
      deviceIds: ids,
      description: map['description'] as String?,
      devicesCount: map['devicesCount'] is int ? map['devicesCount'] as int : (ids.length),
      temperature: map['temperature'] is num ? (map['temperature'] as num).toDouble() : 0.0,
      climateEnabled: map['climateEnabled'] == true,
    );
  }
}
