import 'package:flutter/material.dart';
import 'package:smart_nest_app/screens/camera_screen.dart';
import 'package:smart_nest_app/screens/floor_selection_screen.dart';
import 'package:smart_nest_app/screens/reports_screen.dart';
import 'package:smart_nest_app/screens/settings_screen.dart';
import 'package:smart_nest_app/services/smart_home_service.dart';
import 'package:smart_nest_app/services/cloud_sync_service.dart';
import 'package:smart_nest_app/widgets/metric_card.dart';
import 'package:smart_nest_app/models/device_model.dart';

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
            child: IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<SmartDevice>>(
        stream: cloud.devicesStream(),
        builder: (context, snapshot) {
          final devices = snapshot.data ?? const SmartHomeService().getDevices();
          final activeCount = devices.where((d) => d.status == DeviceStatus.on).length;
          double estimatePower(SmartDevice d) {
            switch (d.type) {
              case DeviceType.outlet:
                return 0.5; // kW
              case DeviceType.multiSwitch:
                return 1.0;
              case DeviceType.scheduledAppliance:
                return 0.8;
              case DeviceType.scheduledLight:
                return 0.1;
              case DeviceType.camera:
                return 0.02;
            }
          }
          final totalPower = devices.where((d) => d.status == DeviceStatus.on).fold(0.0, (t, d) => t + estimatePower(d));
          final alertCount = devices.where((d) => d.status == DeviceStatus.error).length;

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
                            'All systems are running smoothly',
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
              Row(
                children: [
                  const Text(
                    'Overview',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha((0.12 * 255).round()),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '$alertCount alerts',
                          style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
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
              const Text(
                'Quick access',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _QuickAccessTile(
                title: 'Floor plans',
                subtitle: 'Browse and manage rooms',
                icon: Icons.grid_view_rounded,
                color: const Color(0xFF4F46E5),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FloorSelectionScreen()),
                ),
              ),
              _QuickAccessTile(
                title: 'Security cameras',
                subtitle: 'Monitor live rooms',
                icon: Icons.videocam_outlined,
                color: const Color(0xFF14B8A6),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CameraScreen()),
                ),
              ),
              _QuickAccessTile(
                title: 'Reports',
                subtitle: 'Usage and energy overview',
                icon: Icons.analytics_outlined,
                color: const Color(0xFFF59E0B),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
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

