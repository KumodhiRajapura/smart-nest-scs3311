import 'package:flutter/material.dart';
import 'package:smart_nest_app/models/alert.dart';
import 'package:smart_nest_app/services/alert_service.dart';
import 'package:smart_nest_app/services/cloud_sync_service.dart';

/// The alert feed the backend worker writes to (and pushes over FCM). A
/// client can acknowledge an alert but never create one -- see
/// [AlertService] for why that split matters.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final available = CloudSyncService().isFirebaseAvailable;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Alerts', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (available)
            TextButton(
              onPressed: () => AlertService().acknowledgeAll(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: !available
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text('Live alerts need Firebase', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      'Alerts are raised by the backend safety worker when it cuts power to a device or loses its heartbeat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          : StreamBuilder<List<Alert>>(
              stream: AlertService().streamRecent(),
              builder: (context, snapshot) {
                final alerts = snapshot.data ?? const [];
                if (alerts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 56, color: Colors.green.shade300),
                          const SizedBox(height: 16),
                          const Text('All clear', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text(
                            'No alerts have been raised yet.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AlertTile(alert: alerts[index]),
                  ),
                );
              },
            ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final Alert alert;

  const _AlertTile({required this.alert});

  Color get _color {
    switch (alert.severity) {
      case AlertSeverity.critical:
        return const Color(0xFFEF4444);
      case AlertSeverity.warning:
        return const Color(0xFFF59E0B);
      case AlertSeverity.info:
        return const Color(0xFF4F46E5);
    }
  }

  IconData get _icon {
    switch (alert.type) {
      case AlertType.safetyCutoff:
        return Icons.shield_outlined;
      case AlertType.deviceError:
        return Icons.error_outline_rounded;
      case AlertType.deviceOffline:
        return Icons.wifi_off_rounded;
      case AlertType.scheduleRun:
        return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: alert.acknowledged ? Colors.white : _color.withAlpha((0.06 * 255).round()),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: alert.acknowledged ? null : () => AlertService().acknowledge(alert.id),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _color.withAlpha((0.2 * 255).round())),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _color.withAlpha((0.12 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: _color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        if (!alert.acknowledged)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(alert.message, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    const SizedBox(height: 6),
                    Text(
                      '${alert.deviceName.isNotEmpty ? '${alert.deviceName} · ' : ''}'
                      '${alert.createdAt.hour.toString().padLeft(2, '0')}:${alert.createdAt.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
