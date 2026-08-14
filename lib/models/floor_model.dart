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
      floorPlanImageAsset: map['floorPlanImageAsset'] as String?,
    );
  }
}
