FCM Integration — Mobile app contract

Topic
-----
All mobile clients should subscribe to the topic: "safety_alerts"
(This is the simplest approach for an academic prototype.)

When backend creates an alert document with severity "warning" or "critical", it will also publish a topic notification to "safety_alerts".

Notification payload (recommended):
{
  "notification": {
    "title": "Smart Nest Alert",
    "body": "Auto shut-off on Iron: exceeded 15 minutes",
  },
  "data": {
    "deviceId": "<deviceId>",
    "alertId": "<alertId>",
    "severity": "critical"
  }
}

Client responsibilities (Member 1):
- Add firebase_messaging (or compatible) to pubspec.yaml.
- Request user permission for notifications (iOS) and obtain FCM token for debugging.
- Subscribe to topic "safety_alerts" after sign-in / app start: FirebaseMessaging.instance.subscribeToTopic('safety_alerts')
- On message tap, route to device detail screen using data.deviceId

Security notes
--------------
- Do NOT embed server keys in the mobile client. Cloud Functions will send notifications using the Admin SDK.
- For per-user targeting (optional), backend must maintain device tokens and send to specific tokens rather than a public topic.
