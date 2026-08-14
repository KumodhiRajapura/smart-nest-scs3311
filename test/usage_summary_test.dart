import 'package:flutter_test/flutter_test.dart';
import 'package:smart_nest_app/models/usage_log.dart';
import 'package:smart_nest_app/services/usage_repository.dart';

UsageLog logOf({
  required String deviceId,
  required String name,
  required int seconds,
}) {
  final onAt = DateTime(2026, 8, 13, 10);
  return UsageLog(
    id: '$deviceId-$seconds',
    deviceId: deviceId,
    deviceName: name,
    onAt: onAt,
    offAt: onAt.add(Duration(seconds: seconds)),
    durationSeconds: seconds,
  );
}

void main() {
  group('usage summary', () {
    test('totals sessions per device, busiest first', () {
      final summaries = UsageRepository.summarise([
        logOf(deviceId: 'iron', name: 'Clothes Iron', seconds: 600),
        logOf(deviceId: 'light', name: 'Porch Light', seconds: 3600),
        logOf(deviceId: 'iron', name: 'Clothes Iron', seconds: 300),
      ]);

      expect(summaries, hasLength(2));
      expect(summaries.first.deviceId, 'light');
      expect(summaries.first.totalDuration, const Duration(hours: 1));
      expect(summaries.first.sessionCount, 1);

      final iron = summaries.last;
      expect(iron.totalDuration, const Duration(minutes: 15));
      expect(iron.sessionCount, 2);
      expect(iron.averageSession, const Duration(seconds: 450));
    });

    test('formats totals compactly', () {
      final summaries = UsageRepository.summarise([
        logOf(deviceId: 'a', name: 'A', seconds: 45),
        logOf(deviceId: 'b', name: 'B', seconds: 300),
        logOf(deviceId: 'c', name: 'C', seconds: 8040),
      ]);

      final byId = {for (final s in summaries) s.deviceId: s.formattedTotal};
      expect(byId['a'], '45s');
      expect(byId['b'], '5m');
      expect(byId['c'], '2h 14m');
    });

    test('an open session counts up to now instead of being skipped', () {
      final log = UsageLog(
        id: 'open',
        deviceId: 'iron',
        deviceName: 'Clothes Iron',
        onAt: DateTime.now().subtract(const Duration(minutes: 3)),
      );

      expect(log.isOpen, isTrue);
      expect(log.duration.inMinutes, 3);
    });

    test('is empty for no logs', () {
      expect(UsageRepository.summarise(const []), isEmpty);
    });
  });
}
