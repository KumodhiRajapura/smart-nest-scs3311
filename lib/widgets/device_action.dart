import 'package:flutter/material.dart';
import 'package:smart_nest_app/services/app_exception.dart';

/// Run a device write and show the user when it is refused.
///
/// `FirestoreService.toggleDevice` throws rather than writing ON over a device
/// the simulator reports as faulty or unreachable. Without this the refusal is
/// invisible: the write is correctly rejected, the stream never changes, and the
/// switch springs back on its own. The app looks broken instead of careful, and
/// nobody can tell a refused toggle from a dropped one.
Future<void> runDeviceAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
  } on AppException catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(e.message),
        backgroundColor: const Color(0xFFB45309),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Could not reach the device. $e'),
        backgroundColor: const Color(0xFFB91C1C),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
