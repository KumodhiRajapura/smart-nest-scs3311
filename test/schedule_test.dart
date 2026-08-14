import 'package:flutter_test/flutter_test.dart';
import 'package:smart_nest_app/models/schedule.dart';

/// The worker decides when a light comes on by evaluating this same logic, so a
/// bug here is a bug in the automation. These run without Firebase -- nothing
/// in [Schedule] touches the network.

Schedule scheduleOf({
  String start = '18:30',
  String end = '22:00',
  List<int> days = const [1, 2, 3, 4, 5, 6, 7],
  bool enabled = true,
}) =>
    Schedule(
      id: 's1',
      deviceId: 'd1',
      startTime: start,
      endTime: end,
      daysOfWeek: days,
      enabled: enabled,
    );

void main() {
  group('Schedule window', () {
    // 2026-08-13 is a Thursday (ISO weekday 4).
    DateTime at(int hour, int minute) => DateTime(2026, 8, 13, hour, minute);

    test('is active inside a same-day window', () {
      final schedule = scheduleOf();
      expect(schedule.isActiveAt(at(18, 30)), isTrue);
      expect(schedule.isActiveAt(at(20, 0)), isTrue);
      expect(schedule.isActiveAt(at(21, 59)), isTrue);
    });

    test('is inactive outside a same-day window', () {
      final schedule = scheduleOf();
      expect(schedule.isActiveAt(at(18, 29)), isFalse);
      // The end minute is exclusive: the device switches off at 22:00, so it
      // is no longer inside the window at 22:00.
      expect(schedule.isActiveAt(at(22, 0)), isFalse);
      expect(schedule.isActiveAt(at(3, 0)), isFalse);
    });

    test('handles a window that wraps past midnight', () {
      final schedule = scheduleOf(start: '22:00', end: '06:00');
      expect(schedule.isOvernight, isTrue);
      expect(schedule.isActiveAt(at(23, 30)), isTrue);
      expect(schedule.isActiveAt(at(2, 0)), isTrue);
      expect(schedule.isActiveAt(at(5, 59)), isTrue);
      expect(schedule.isActiveAt(at(6, 0)), isFalse);
      expect(schedule.isActiveAt(at(12, 0)), isFalse);
    });

    test('respects the day filter', () {
      // Weekdays only; the 13th is a Thursday, the 15th a Saturday.
      final schedule = scheduleOf(days: const [1, 2, 3, 4, 5]);
      expect(schedule.isActiveAt(DateTime(2026, 8, 13, 20)), isTrue);
      expect(schedule.isActiveAt(DateTime(2026, 8, 15, 20)), isFalse);
    });

    test('a disabled schedule is never active', () {
      expect(scheduleOf(enabled: false).isActiveAt(at(20, 0)), isFalse);
    });

    test('parses minutes from HH:mm', () {
      final schedule = scheduleOf(start: '06:05', end: '23:45');
      expect(schedule.startMinutes, 365);
      expect(schedule.endMinutes, 1425);
    });
  });
}
