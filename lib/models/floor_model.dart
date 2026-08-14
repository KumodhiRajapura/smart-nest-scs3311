import 'package:cloud_firestore/cloud_firestore.dart';

class FloorModel {
  final String id;
  final String name;
  final int order;
  final String? floorPlanImageAsset;

  const FloorModel({required this.id, required this.name, required this.order, this.floorPlanImageAsset});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'order': order,
        'floorPlanImageAsset': floorPlanImageAsset,
      };

  factory FloorModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return FloorModel(
      id: map['id'] ?? doc.id,
      name: map['name'] ?? '',
      order: map['order'] is int ? map['order'] as int : 0,
      // `floorPlanImageUrl` is the canonical name in firebase/SCHEMA.md and is
      // what the seed script and the simulator write. The older
      // `floorPlanImageAsset` key is still read so documents created before the
      // rename keep rendering.
      floorPlanImageAsset: (map['floorPlanImageUrl'] ?? map['floorPlanImageAsset']) as String?,
    );
  }
}
