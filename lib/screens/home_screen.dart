import 'package:flutter/material.dart';
import 'package:smart_nest_app/models/alert.dart';
import 'package:smart_nest_app/screens/alerts_screen.dart';
import 'package:smart_nest_app/screens/floor_dashboard_screen.dart';
import 'package:smart_nest_app/screens/settings_screen.dart';
import 'package:smart_nest_app/services/alert_service.dart';
import 'package:smart_nest_app/services/cloud_sync_service.dart';
import 'package:smart_nest_app/services/smart_home_service.dart';
import 'package:smart_nest_app/widgets/device_action.dart';
import 'package:smart_nest_app/widgets/metric_card.dart';
import 'package:smart_nest_app/models/device_model.dart';
import 'package:smart_nest_app/widgets/status_chip.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cloud = CloudSyncService();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart Nest',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Home Control',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.06 * 255).round()),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: cloud.isFirebaseAvailable
                ? StreamBuilder<List<Alert>>(
                    stream: AlertService().streamUnacknowledged(),
                    builder: (context, snapshot) {
                      final count = (snapshot.data ?? const <Alert>[]).length;
                      return _AlertBell(count: count);
                    },
                  )
                : const _AlertBell(count: 0),
          ),
        ],
      ),
      body: StreamBuilder<List<SmartDevice>>(
        stream: cloud.devicesStream(),
        builder: (context, snapshot) {
          final devices = snapshot.data ?? const SmartHomeService().getDevices();
          final activeCount = devices.where((d) => d.status == DeviceStatus.on).length;
          final totalPower = devices.where((d) => d.status == DeviceStatus.on).fold(0.0, (t, d) => t + d.powerUsage);
          final errorCount = devices.where((d) => d.status == DeviceStatus.error).length;
          final disconnectedCount = devices.where((d) => d.status == DeviceStatus.disconnected).length;
          final issueCount = errorCount + disconnectedCount;

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1F2A44), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withAlpha((0.25 * 255).round()),
                      blurRadius: 18,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome home',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            issueCount == 0
                                ? 'All systems are running smoothly'
                                : '$issueCount device${issueCount > 1 ? 's' : ''} need attention',
                            style: TextStyle(
                              color: Colors.white.withAlpha((0.8 * 255).round()),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((0.12 * 255).round()),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.home_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Overview',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  MetricCard(
                    label: 'Active devices',
                    value: '$activeCount',
                    icon: Icons.power_settings_new_rounded,
                    color: Colors.indigo,
                  ),
                  MetricCard(
                    label: 'Power usage',
                    value: '${totalPower.toStringAsFixed(1)} kW',
                    icon: Icons.bolt_rounded,
                    color: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text(
                    'Devices',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    '${devices.length} total',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (devices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'No devices yet. Run the worker seed to create them.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              else
                ...devices.map((device) => _DeviceTile(device: device)),
              const SizedBox(height: 24),
              const Text(
                'Quick access',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _QuickAccessTile(
                title: 'Alerts',
                subtitle: issueCount == 0 ? 'No active issues' : '$issueCount device issue(s)',
                icon: Icons.notifications_none_rounded,
                color: const Color(0xFFB45309),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AlertsScreen()),
                ),
              ),
              _QuickAccessTile(
                title: 'Settings',
                subtitle: 'System and safety controls',
                icon: Icons.settings_outlined,
                color: const Color(0xFFEF4444),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AlertBell extends StatelessWidget {
  final int count;

  const _AlertBell({required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AlertsScreen()),
          ),
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(999)),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

/// One row in the home device list.
///
/// A gang box gets no master switch: its children are independent, and there is
/// no single "off" that is honest about three switches. It reads how many are
/// on and sends you to the detail screen, which is where they are controlled.
class _DeviceTile extends StatelessWidget {
  final SmartDevice device;

  const _DeviceTile({required this.device});

  String get _subtitle {
    if (device.isMultiSwitch) {
      final on = device.multiSwitchStates.where((s) => s).length;
      return '${deviceTypeLabel(device.type)} · $on/${device.multiSwitchStates.length} on';
    }
    return deviceTypeLabel(device.type);
  }

  @override
  Widget build(BuildContext context) {
    final color = statusColor(device.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DeviceDetailScreen(device: device)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withAlpha((0.12 * 255).round()),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(deviceTypeIcon(device.type), color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (device.isMultiSwitch)
                  Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400)
                else
                  Switch(
                    value: device.isOn,
                    onChanged: device.status == DeviceStatus.error || device.status == DeviceStatus.disconnected
                        ? null
                        : (value) => runDeviceAction(
                              context,
                              () => CloudSyncService().updateDeviceState(device.id, isOn: value),
                            ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withAlpha((0.12 * 255).round()),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
