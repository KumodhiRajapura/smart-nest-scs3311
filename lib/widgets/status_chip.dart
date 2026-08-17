import 'package:flutter/material.dart';
import 'package:smart_nest_app/models/device_model.dart';

/// Colour used consistently for a device status, across every screen.
Color statusColor(DeviceStatus status) {
  switch (status) {
    case DeviceStatus.on:
      return const Color(0xFF16A34A);
    case DeviceStatus.off:
      return const Color(0xFF64748B);
    case DeviceStatus.error:
      return const Color(0xFFEF4444);
    case DeviceStatus.disconnected:
      return const Color(0xFFF59E0B);
  }
}

String statusLabel(DeviceStatus status) {
  switch (status) {
    case DeviceStatus.on:
      return 'ON';
    case DeviceStatus.off:
      return 'OFF';
    case DeviceStatus.error:
      return 'ERROR';
    case DeviceStatus.disconnected:
      return 'DISCONNECTED';
  }
}

IconData deviceTypeIcon(DeviceType type) {
  switch (type) {
    case DeviceType.outlet:
      return Icons.power_outlined;
    case DeviceType.multiSwitch:
      return Icons.dashboard_customize_outlined;
    case DeviceType.scheduledAppliance:
      return Icons.iron_outlined;
    case DeviceType.scheduledLight:
      return Icons.lightbulb_outline_rounded;
    case DeviceType.camera:
      return Icons.videocam_outlined;
  }
}

String deviceTypeLabel(DeviceType type) {
  switch (type) {
    case DeviceType.outlet:
      return 'Outlet';
    case DeviceType.multiSwitch:
      return 'Multi-switch unit';
    case DeviceType.scheduledAppliance:
      return 'Safety-critical appliance';
    case DeviceType.scheduledLight:
      return 'Scheduled light';
    case DeviceType.camera:
      return 'Security camera';
  }
}

/// A small pill showing a device's live status, in a consistent colour.
class StatusChip extends StatelessWidget {
  final DeviceStatus status;
  final double fontSize;

  const StatusChip({super.key, required this.status, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            statusLabel(status),
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
