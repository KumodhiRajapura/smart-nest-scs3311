import '../models/alert.dart';
import 'firestore_refs.dart';

/// Read-side of the alert feed.
///
/// Alerts are created by the worker. The push notification and this stream are
/// two views of the same event: the push wakes the user, the stream is what the
/// alerts screen renders, and the two cannot drift apart because only one of
/// them is the source of truth.
class AlertRepository {
  const AlertRepository();

  Stream<List<Alert>> watchRecent({int limit = 50}) => Refs.alerts
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map(Alert.fromDoc).toList());

  /// Unread alerts, for the badge on the app bar.
  ///
  /// Needs the composite index on (read, createdAt desc).
  Stream<List<Alert>> watchUnread() => Refs.alerts
      .where('read', isEqualTo: false)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Alert.fromDoc).toList());

  Stream<int> watchUnreadCount() => watchUnread().map((list) => list.length);

  Future<void> markRead(String alertId) =>
      Refs.alerts.doc(alertId).update({'read': true});

  Future<void> markAllRead() async {
    final snap = await Refs.alerts.where('read', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;

    final batch = Refs.db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> delete(String alertId) => Refs.alerts.doc(alertId).delete();
}
