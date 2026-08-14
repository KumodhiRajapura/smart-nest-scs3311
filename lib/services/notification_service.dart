import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Topic every installation subscribes to.
///
/// Topics instead of device tokens: the worker can then push an alert with one
/// API call and no token registry, no stale-token cleanup, and no extra
/// collection to keep in sync. The trade-off is that alerts go to every phone
/// in the household, which for a home automation app is what you want anyway.
const String kAlertsTopic = 'alerts';

const AndroidNotificationChannel _alertsChannel = AndroidNotificationChannel(
  'smart_nest_alerts',
  'Smart Nest alerts',
  description: 'Safety cutoffs and device faults',
  importance: Importance.high,
);

/// Entry point for notifications that arrive while the app is terminated or
/// backgrounded.
///
/// Must be top level and annotated: the Flutter engine spawns a fresh isolate
/// to run it, so it cannot close over anything from the running app.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Android already draws the system tray notification from the `notification`
  // block of the payload, so there is nothing to do here beyond logging. The
  // durable record of the event is the Firestore alert document, which the app
  // will pick up on its next snapshot.
  debugPrint('[fcm] background alert: ${message.data}');
}

/// Push notifications, plus the plumbing that makes them visible while the app
/// is in the foreground.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  /// Called once during app bootstrap. Safe to call again -- it no-ops.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    await _requestPermission();
    await _setupLocalNotifications();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Android does *not* show a system notification while the app is in the
    // foreground -- it hands the message to the app instead. Without this the
    // safety cutoff alert would appear only when the phone was locked, which
    // makes it look broken during a demo.
    FirebaseMessaging.onMessage.listen(_showForeground);

    await subscribeToAlerts();
  }

  Future<void> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    debugPrint('[fcm] permission: ${settings.authorizationStatus}');
  }

  Future<void> _setupLocalNotifications() async {
    if (kIsWeb) return;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(settings: initSettings);

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_alertsChannel);
  }

  void _showForeground(RemoteMessage message) {
    if (kIsWeb) return;

    final notification = message.notification;
    if (notification == null) return;

    _local.show(
      // Unique per notification so a second alert does not replace the first.
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _alertsChannel.id,
          _alertsChannel.name,
          channelDescription: _alertsChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['deviceId'] as String?,
    );
  }

  /// Web needs a service worker and a VAPID key before topics work, so it is
  /// skipped -- the simulator does not need push anyway.
  Future<void> subscribeToAlerts() async {
    if (kIsWeb) return;
    await FirebaseMessaging.instance.subscribeToTopic(kAlertsTopic);
    debugPrint('[fcm] subscribed to "$kAlertsTopic"');
  }

  Future<void> unsubscribeFromAlerts() async {
    if (kIsWeb) return;
    await FirebaseMessaging.instance.unsubscribeFromTopic(kAlertsTopic);
  }

  /// Handy while testing -- paste the token into the Firebase console to send a
  /// message to this handset alone.
  Future<String?> deviceToken() => FirebaseMessaging.instance.getToken();
}
