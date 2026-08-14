import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:smart_nest_app/config/firestore_paths.dart';
import 'package:smart_nest_app/models/usage_log.dart';

import 'app_exception.dart';

/// Read side of usage tracking, plus the aggregation the reports screen needs.
///
/// Writes live in the backend worker. See [UsageLog] for why that matters.
class UsageService {
  UsageService._internal();

  static final UsageService _instance = UsageService._internal();

  factory UsageService() => _instance;

  CollectionReference<Map<String, dynamic>> get _logs {
    if (Firebase.apps.isEmpty) {
      throw const AppException('Firestore is not initialised');
    }
    return FirebaseFirestore.instance.collection(FirestorePaths.usageLogs);
  }

  /// Most recent events across the whole house.
  Stream<List<UsageLog>> streamRecent({int limit = 100}) => _guarded(
        () => _logs
            .orderBy(UsageFields.timestamp, descending: true)
            .limit(limit)
            .snapshots()
            .map((snap) => snap.docs.map(UsageLog.fromFirestore).toList()),
      );

  /// Events for one device, newest first.
  ///
  /// Needs the composite index on (deviceId, timestamp desc).
  Stream<List<UsageLog>> streamForDevice(String deviceId, {int limit = 50}) =>
      _guarded(
        () => _logs
            .where(UsageFields.deviceId, isEqualTo: deviceId)
            .orderBy(UsageFields.timestamp, descending: true)
            .limit(limit)
            .snapshots()
            .map((snap) => snap.docs.map(UsageLog.fromFirestore).toList()),
      );

  /// Everything since [from] -- what the reports screen listens to.
  Stream<List<UsageLog>> streamSince(DateTime from) => _guarded(
        () => _logs
            .where(UsageFields.timestamp, isGreaterThanOrEqualTo: from)
            .orderBy(UsageFields.timestamp, descending: true)
            .snapshots()
            .map((snap) => snap.docs.map(UsageLog.fromFirestore).toList()),
      );

  /// Per-device totals over the last [days] days, busiest first.
  Future<List<DeviceUsageSummary>> summaryForLastDays(int days) async {
    final from = DateTime.now().subtract(Duration(days: days));
    final snap = await _logs
        .where(UsageFields.timestamp, isGreaterThanOrEqualTo: from)
        .orderBy(UsageFields.timestamp, descending: true)
        .get();

    return summarise(snap.docs.map(UsageLog.fromFirestore).toList());
  }

  /// Fold raw events into per-device totals.
  ///
  /// Only session-ending events carry a duration, so those are the ones that
  /// count -- an `on` row has nothing to add and would inflate the session
  /// count if it did. Aggregating on the client is deliberate: a house has tens
  /// of devices and a demo a few hundred rows, which folds in microseconds and
  /// avoids maintaining rollup documents that can drift out of date.
  static List<DeviceUsageSummary> summarise(List<UsageLog> logs) {
    final totals = <String, int>{};
    final counts = <String, int>{};
    final cutoffs = <String, int>{};
    final names = <String, String>{};

    for (final log in logs) {
      if (!log.event.endsSession) continue;

      totals[log.deviceId] =
          (totals[log.deviceId] ?? 0) + (log.durationOnSeconds ?? 0);
      counts[log.deviceId] = (counts[log.deviceId] ?? 0) + 1;
      if (log.wasCutOff) {
        cutoffs[log.deviceId] = (cutoffs[log.deviceId] ?? 0) + 1;
      }
      if (log.deviceName.isNotEmpty) names[log.deviceId] = log.deviceName;
    }

    final summaries = totals.entries
        .map((e) => DeviceUsageSummary(
              deviceId: e.key,
              deviceName: names[e.key] ?? e.key,
              totalDuration: Duration(seconds: e.value),
              sessionCount: counts[e.key] ?? 0,
              safetyCutoffCount: cutoffs[e.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.totalDuration.compareTo(a.totalDuration));

    return summaries;
  }

  /// Total ON time per day for the last [days] days, oldest first.
  ///
  /// Shaped for a bar chart: index 0 is [days] - 1 days ago, the last entry is
  /// today, and quiet days are present as zero rather than missing, so the bars
  /// line up with the weekday labels.
  static List<Duration> dailyTotals(List<UsageLog> logs, int days) {
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    final buckets = List<int>.filled(days, 0);

    for (final log in logs) {
      if (!log.event.endsSession) continue;

      final logDay =
          DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day);
      final ago = midnight.difference(logDay).inDays;
      if (ago < 0 || ago >= days) continue;

      buckets[days - 1 - ago] += log.durationOnSeconds ?? 0;
    }

    return buckets.map((s) => Duration(seconds: s)).toList();
  }

  Stream<T> _guarded<T>(Stream<T> Function() build) {
    try {
      return build();
    } on AppException catch (e) {
      return Stream<T>.error(e);
    } catch (e) {
      return Stream<T>.error(AppException('Usage query failed: $e'));
    }
  }
}
