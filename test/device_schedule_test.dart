import 'package:flutter_test/flutter_test.dart';
import 'package:smart_nest_app/models/device_model.dart';

/// Schedule-window and safety-budget logic.
///
/// The backend worker (`worker/src/scheduler.js` and `safety.js`) evaluates the
/// same two rules against the same fields, so a bug here is a bug in the
/// automation. These run without Firebase -- nothing in [SmartDevice] touches
/// the network.

SmartDevice lightWith({
  String? start = '18:30',
  String? end = '22:00',
}) =>
    SmartDevice(
      id: 'dev_porch_light',
      name: 'Porch Light',
      roomId: 'room_porch',
      type: DeviceType.scheduledLight,
      status: DeviceStatus.off,
      scheduleStartTime: start,
      scheduleEndTime: end,
    );

SmartDevice ironWith({int? budget = 2, DateTime? turnedOnAt}) => SmartDevice(
      id: 'dev_iron',
      name: 'Clothes Iron',
      roomId: 'room_utility',
      type: DeviceType.scheduledAppliance,
      status: turnedOnAt == null ? DeviceStatus.off : DeviceStatus.on,
      maxOnDurationMinutes: budget,
      turnedOnAt: turnedOnAt,
    );

void main() {
  // 2026-08-13 is a Thursday.
  DateTime at(int hour, int minute) => DateTime(2026, 8, 13, hour, minute);

  group('schedule window', () {
    test('is active inside a same-day window', () {
      final light = lightWith();
      expect(light.scheduledShouldBeOn(at(18, 30)), isTrue);
      expect(light.scheduledShouldBeOn(at(20, 0)), isTrue);
      expect(light.scheduledShouldBeOn(at(21, 59)), isTrue);
    });

    test('is inactive outside a same-day window', () {
      final light = lightWith();
      expect(light.scheduledShouldBeOn(at(18, 29)), isFalse);
      // The end minute is exclusive: the light switches off at 22:00, so it is
      // no longer inside the window at 22:00.
      expect(light.scheduledShouldBeOn(at(22, 0)), isFalse);
      expect(light.scheduledShouldBeOn(at(3, 0)), isFalse);
    });

    test('handles a window that wraps past midnight', () {
      final light = lightWith(start: '22:00', end: '06:00');
      expect(light.scheduledShouldBeOn(at(23, 30)), isTrue);
      expect(light.scheduledShouldBeOn(at(2, 0)), isTrue);
      expect(light.scheduledShouldBeOn(at(5, 59)), isTrue);
      expect(light.scheduledShouldBeOn(at(6, 0)), isFalse);
      expect(light.scheduledShouldBeOn(at(12, 0)), isFalse);
    });

    test('a device with no schedule is never scheduled on', () {
      expect(lightWith(start: null, end: null).scheduledShouldBeOn(at(20, 0)),
          isFalse);
      expect(lightWith(end: null).scheduledShouldBeOn(at(20, 0)), isFalse);
    });
  });

  group('safety budget', () {
    test('is not exceeded before the budget runs out', () {
      final now = DateTime(2026, 8, 13, 10, 0);
      final iron = ironWith(
        budget: 2,
        turnedOnAt: now.subtract(const Duration(seconds: 90)),
      );
      expect(iron.hasExceededMaxDuration(now), isFalse);
    });

    test('is exceeded once the budget is spent', () {
      final now = DateTime(2026, 8, 13, 10, 0);
      final iron = ironWith(
        budget: 2,
        turnedOnAt: now.subtract(const Duration(minutes: 2)),
      );
      expect(iron.hasExceededMaxDuration(now), isTrue);
    });

    test('a device that is off has nothing to exceed', () {
      // turnedOnAt is cleared on the way off, which is exactly what stops the
      // worker cutting off a device that is already idle.
      final iron = ironWith(budget: 2, turnedOnAt: null);
      expect(iron.hasExceededMaxDuration(DateTime(2026, 8, 13, 10, 0)), isFalse);
    });

    test('a device with no budget is never cut off', () {
      final now = DateTime(2026, 8, 13, 10, 0);
      final device = ironWith(
        budget: null,
        turnedOnAt: now.subtract(const Duration(hours: 9)),
      );
      expect(device.hasExceededMaxDuration(now), isFalse);
    });
  });

  group('multi-switch', () {
    test('reports itself as a gang box only when it has children', () {
      final gang = SmartDevice(
        id: 'dev_kitchen_gang',
        name: 'Kitchen Gang Box',
        roomId: 'room_kitchen',
        type: DeviceType.multiSwitch,
        status: DeviceStatus.off,
        childSwitches: const [
          SwitchChild(id: 's0', label: 'Ceiling Light', isOn: false),
          SwitchChild(id: 's1', label: 'Exhaust Fan', isOn: true),
        ],
      );

      expect(gang.isMultiSwitch, isTrue);
      expect(gang.switches, [false, true]);
      expect(lightWith().isMultiSwitch, isFalse);
    });
  });
}
