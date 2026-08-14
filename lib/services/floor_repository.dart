import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/floor.dart';
import 'firestore_refs.dart';

/// CRUD for floor plans.
///
/// Deleting a floor deletes its devices too. Firestore has no cascade and no
/// foreign keys, so orphaned devices would keep appearing in the "all devices"
/// stream pointing at a floor that no longer exists.
class FloorRepository {
  const FloorRepository();

  Stream<List<Floor>> watchAll() => Refs.floors
      .orderBy('level')
      .snapshots()
      .map((snap) => snap.docs.map(Floor.fromDoc).toList());

  Stream<Floor?> watchFloor(String floorId) => Refs.floor(floorId)
      .snapshots()
      .map((doc) => doc.exists ? Floor.fromDoc(doc) : null);

  Future<List<Floor>> getAll() async {
    final snap = await Refs.floors.orderBy('level').get();
    return snap.docs.map(Floor.fromDoc).toList();
  }

  Future<String> create(Floor floor) async {
    final ref = await Refs.floors.add({
      ...floor.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(
    String floorId, {
    String? name,
    int? level,
    String? planImageUrl,
    int? gridCols,
    int? gridRows,
  }) =>
      Refs.floor(floorId).update({
        if (name != null) 'name': name,
        if (level != null) 'level': level,
        if (planImageUrl != null) 'planImageUrl': planImageUrl,
        if (gridCols != null) 'gridCols': gridCols,
        if (gridRows != null) 'gridRows': gridRows,
      });

  /// Delete a floor and every device standing on it, in one batch.
  Future<void> delete(String floorId) async {
    final devices =
        await Refs.devices.where('floorId', isEqualTo: floorId).get();

    final batch = Refs.db.batch();
    for (final doc in devices.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(Refs.floor(floorId));
    await batch.commit();
  }
}
