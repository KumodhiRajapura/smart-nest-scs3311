import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:smart_nest_app/config/firestore_paths.dart';
import 'package:smart_nest_app/models/alert.dart';

import 'app_exception.dart';

/// Read side of the alert feed.
///
/// There is no `raise` method here on purpose: alerts are created by the
/// backend worker through the Admin SDK, and the security rules reject client
/// writes. An app that could invent a "safety cutoff" alert would make the
/// whole feed untrustworthy. The only thing a client may change is the
/// acknowledged flag.
class AlertService {
  AlertService._internal();

  static final AlertService _instance = AlertService._internal();

  factory AlertService() => _instance;

  CollectionReference<Map<String, dynamic>> get _alerts {
    if (Firebase.apps.isEmpty) {
      throw const AppException('Firestore is not initialised');
    }
    return FirebaseFirestore.instance.collection(FirestorePaths.alerts);
  }

  Stream<List<Alert>> streamRecent({int limit = 50}) => _guarded(
        () => _alerts
            .orderBy(AlertFields.createdAt, descending: true)
            .limit(limit)
            .snapshots()
            .map((snap) => snap.docs.map(Alert.fromFirestore).toList()),
      );

  /// Unacknowledged alerts, for the badge on the app bar.
  ///
  /// Needs the composite index on (acknowledged, createdAt desc).
  Stream<List<Alert>> streamUnacknowledged() => _guarded(
        () => _alerts
            .where(AlertFields.acknowledged, isEqualTo: false)
            .orderBy(AlertFields.createdAt, descending: true)
            .snapshots()
            .map((snap) => snap.docs.map(Alert.fromFirestore).toList()),
      );

  Stream<int> streamUnacknowledgedCount() =>
      streamUnacknowledged().map((list) => list.length);

  Stream<List<Alert>> streamForDevice(String deviceId, {int limit = 20}) =>
      _guarded(
        () => _alerts
            .where(AlertFields.deviceId, isEqualTo: deviceId)
            .orderBy(AlertFields.createdAt, descending: true)
            .limit(limit)
            .snapshots()
            .map((snap) => snap.docs.map(Alert.fromFirestore).toList()),
      );

  Future<void> acknowledge(String alertId) =>
      _alerts.doc(alertId).update({AlertFields.acknowledged: true});

  Future<void> acknowledgeAll() async {
    final snap =
        await _alerts.where(AlertFields.acknowledged, isEqualTo: false).get();
    if (snap.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {AlertFields.acknowledged: true});
    }
    await batch.commit();
  }

  Future<void> delete(String alertId) => _alerts.doc(alertId).delete();

  Stream<T> _guarded<T>(Stream<T> Function() build) {
    try {
      return build();
    } on AppException catch (e) {
      return Stream<T>.error(e);
    } catch (e) {
      return Stream<T>.error(AppException('Alert query failed: $e'));
    }
  }
}
