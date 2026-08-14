import '../models/usage_log.dart';
import 'firestore_refs.dart';

/// Read-side of usage tracking.
///
/// There is no write method here on purpose. Sessions are opened and closed by
/// the Node worker, which observes every status transition regardless of who
/// caused it -- app, simulator, schedule or safety cutoff. If the app wrote its
/// own logs, a change made from the simulator would never be counted, and a
/// crash between ON and OFF would leave a session that is never closed.
class UsageRepository {
  const UsageRepository();

  /// Most recent sessions across the whole house.
  Stream<List<UsageLog>> watchRecent({int limit = 50}) => Refs.usageLogs
      .orderBy('onAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map(UsageLog.fromDoc).toList());

  /// Sessions for one device, newest first.
  ///
  /// Needs the composite index on (deviceId, onAt desc).
  Stream<List<UsageLog>> watchForDevice(String deviceId, {int limit = 50}) =>
      Refs.usageLogs
          .where('deviceId', isEqualTo: deviceId)
          .orderBy('onAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) => snap.docs.map(UsageLog.fromDoc).toList());

  /// Everything that happened since [from], for the report screen.
  Stream<List<UsageLog>> watchSince(DateTime from) => Refs.usageLogs
      .where('onAt', isGreaterThanOrEqualTo: from)
      .orderBy('onAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(UsageLog.fromDoc).toList());

  /// Per-device totals over the last [days] days, busiest device first.
  ///
  /// Aggregated on the client: a house has tens of devices and a demo has
  /// hundreds of logs, so pulling the window and folding it locally is cheaper
  /// and far simpler than maintaining rollup documents.
  Future<List<DeviceUsageSummary>> summaryForLastDays(int days) async {
    final from = DateTime.now().subtract(Duration(days: days));
    final snap = await Refs.usageLogs
        .where('onAt', isGreaterThanOrEqualTo: from)
        .orderBy('onAt', descending: true)
        .get();

    return summarise(snap.docs.map(UsageLog.fromDoc).toList());
  }

  /// Fold raw sessions into per-device totals.
  ///
  /// Exposed separately so a screen already listening to [watchSince] can
  /// summarise without a second read.
  static List<DeviceUsageSummary> summarise(List<UsageLog> logs) {
    final totals = <String, Duration>{};
    final counts = <String, int>{};
    final names = <String, String>{};

    for (final log in logs) {
      totals[log.deviceId] = (totals[log.deviceId] ?? Duration.zero) + log.duration;
      counts[log.deviceId] = (counts[log.deviceId] ?? 0) + 1;
      if (log.deviceName.isNotEmpty) names[log.deviceId] = log.deviceName;
    }

    final summaries = totals.entries
        .map((e) => DeviceUsageSummary(
              deviceId: e.key,
              deviceName: names[e.key] ?? e.key,
              totalDuration: e.value,
              sessionCount: counts[e.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.totalDuration.compareTo(a.totalDuration));

    return summaries;
  }
}
