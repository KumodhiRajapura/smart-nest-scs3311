import 'package:flutter/material.dart';
import 'package:smart_nest_app/models/device_model.dart';
import 'package:smart_nest_app/screens/floor_dashboard_screen.dart' show DeviceDetailScreen;
import 'package:smart_nest_app/services/cloud_sync_service.dart';
import 'package:smart_nest_app/widgets/camera_image.dart';
import 'package:smart_nest_app/widgets/status_chip.dart';

/// Every camera in the house, live. Cameras are ordinary [SmartDevice]
/// entries of type [DeviceType.camera] -- there is no separate cameras
/// collection -- so this screen is just [devicesStream] filtered down, which
/// is exactly what keeps it in sync with a camera added from the floor plan.
class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cloud = CloudSyncService();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Security cameras', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<List<SmartDevice>>(
        stream: cloud.devicesStream(),
        builder: (context, snapshot) {
          final cameras = (snapshot.data ?? const [])
              .where((d) => d.type == DeviceType.camera)
              .toList();

          if (cameras.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off_outlined, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text('No cameras yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      'Add a camera-type device from a room to monitor it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: cameras.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _CameraCard(device: cameras[index]),
            ),
          );
        },
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  final SmartDevice device;

  const _CameraCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final live = device.status == DeviceStatus.on;
    final uri = (device.cameraImageUrls != null && device.cameraImageUrls!.isNotEmpty)
        ? device.cameraImageUrls!.first
        : 'mock://cam/${device.id}/snapshot.jpg';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DeviceDetailScreen(device: device)),
        ),
        child: Container(
          height: 220,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraImage(uri: uri, live: live),
              if (live)
                Container(color: Colors.black.withAlpha((0.15 * 255).round()))
              else
                Container(color: Colors.black.withAlpha((0.4 * 255).round())),
              Positioned(
                right: 16,
                top: 16,
                child: StatusChip(status: device.status),
              ),
              Positioned(
                left: 18,
                bottom: 18,
                right: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: live ? const Color(0xFFEF4444) : Colors.white54,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          live ? 'Live feed (simulated)' : 'Feed unavailable',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      uri,
                      style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (device.lastAlert != null && device.lastAlert!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha((0.3 * 255).round()),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                device.lastAlert!,
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
