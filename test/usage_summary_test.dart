import 'package:flutter_test/flutter_test.dart';
import 'package:smart_nest_app/models/usage_log.dart';
import 'package:smart_nest_app/services/usage_service.dart';

/// Aggregation of the worker's event log into the figures the reports screen
/// shows. Pure Dart -- no Firebase needed.

UsageLog logOf({
  required String deviceId,
  required String name,
  required UsageEvent event,
  int? seconds,
  DateTime? at,
}) =>
    UsageLog(
      id: '$deviceId-${at ?? DateTime.now()}-${event.id}',
      deviceId: deviceId,
      deviceName: name,
      event: event,
      timestamp: at ?? DateTime(2026, 8, 13, 10),
      durationOnSeconds: seconds,
    );

void main() {
  group('summarise', () {
    test('totals session-ending events per device, busiest first', () {
      final summaries = UsageService.summarise([
        logOf(
            deviceId: 'iron',
            name: 'Clothes Iron',
            event: UsageEvent.off,
            seconds: 600),
        logOf(
            deviceId: 'light',
            name: 'Porch Light',
            event: UsageEvent.off,
            seconds: 3600),
        logOf(
            deviceId: 'iron',
            name: 'Clothes Iron',
            event: UsageEvent.off,
            seconds: 300),
      ]);

      expect(summaries, hasLength(2));
      expect(summaries.first.deviceId, 'light');
      expect(summaries.first.totalDuration, const Duration(hours: 1));

      final iron = summaries.last;
      expect(iron.totalDuration, const Duration(minutes: 15));
      expect(iron.sessionCount, 2);
      expect(iron.averageSession, const Duration(seconds: 450));
    });

    test('ignores `on` rows', () {
      // An `on` row has no duration to contribute. Counting it would inflate
      // the session count to double the real number.
      final summaries = UsageService.summarise([
        logOf(deviceId: 'iron', name: 'Iron', event: UsageEvent.on),
        logOf(
            deviceId: 'iron',
            name: 'Iron',
            event: UsageEvent.off,
            seconds: 120),
      ]);

      expect(summaries, hasLength(1));
      expect(summaries.first.sessionCount, 1);
      expect(summaries.first.totalDuration, const Duration(minutes: 2));
    });

    test('counts safety cutoffs separately', () {
      final summaries = UsageService.summarise([
        logOf(
            deviceId: 'iron',
            name: 'Iron',
            event: UsageEvent.autoOffSafety,
            seconds: 120),
        logOf(
            deviceId: 'iron',
            name: 'Iron',
            event: UsageEvent.off,
            seconds: 60),
      ]);

      final iron = summaries.single;
      expect(iron.sessionCount, 2);
      expect(iron.safetyCutoffCount, 1);
      expect(iron.totalDuration, const Duration(minutes: 3));
    });

    test('formats totals compactly', () {
      final summaries = UsageService.summarise([
        logOf(deviceId: 'a', name: 'A', event: UsageEvent.off, seconds: 45),
        logOf(deviceId: 'b', name: 'B', event: UsageEvent.off, seconds: 300),
        logOf(deviceId: 'c', name: 'C', event: UsageEvent.off, seconds: 8040),
      ]);

      final byId = {for (final s in summaries) s.deviceId: s.formattedTotal};
      expect(byId['a'], '45s');
      expect(byId['b'], '5m');
      expect(byId['c'], '2h 14m');
    });

    test('is empty for no logs', () {
      expect(UsageService.summarise(const []), isEmpty);
    });
  });

  group('dailyTotals', () {
    test('buckets by day, oldest first, with zeros for quiet days', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12);
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      final totals = UsageService.dailyTotals([
        logOf(
            deviceId: 'a',
            name: 'A',
            event: UsageEvent.off,
            seconds: 60,
            at: today),
        logOf(
            deviceId: 'a',
            name: 'A',
            event: UsageEvent.off,
            seconds: 120,
            at: twoDaysAgo),
      ], 7);

      expect(totals, hasLength(7));
      // Last bucket is today.
      expect(totals.last, const Duration(minutes: 1));
      expect(totals[4], const Duration(minutes: 2));
      expect(totals[5], Duration.zero);
    });

    test('drops events older than the window', () {
      final old = DateTime.now().subtract(const Duration(days: 30));
      final totals = UsageService.dailyTotals([
        logOf(
            deviceId: 'a',
            name: 'A',
            event: UsageEvent.off,
            seconds: 600,
            at: old),
      ], 7);

      expect(totals.every((d) => d == Duration.zero), isTrue);
    });
  });
}
