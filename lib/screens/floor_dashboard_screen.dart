import 'dart:async';

import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:smart_nest_app/models/device_model.dart';
import 'package:smart_nest_app/models/room_model.dart';
import 'package:smart_nest_app/models/usage_log.dart';
import 'package:smart_nest_app/services/cloud_sync_service.dart';
import 'package:smart_nest_app/services/usage_service.dart';
import 'package:smart_nest_app/widgets/camera_image.dart';
import 'package:smart_nest_app/widgets/device_action.dart';
import 'package:smart_nest_app/widgets/status_chip.dart';

/// Devices for one room, live. Reached from a room card in [FloorPlanScreen].
class FloorDashboardScreen extends StatelessWidget {
  final Room room;

  const FloorDashboardScreen({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final cloud = CloudSyncService();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<List<SmartDevice>>(
        stream: cloud.devicesForRoomStream(room.id),
        builder: (context, snapshot) {
          final roomDevices = snapshot.data ?? const [];
          final activeCount = roomDevices.where((d) => d.status == DeviceStatus.on).length;
          final totalPower = roomDevices
              .where((d) => d.status == DeviceStatus.on)
              .fold(0.0, (t, d) => t + d.powerUsage);

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1F2A44), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    if (room.description != null && room.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        room.description!,
                        style: TextStyle(color: Colors.white.withAlpha((0.8 * 255).round()), fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _HeaderStat(label: 'Devices', value: '${roomDevices.length}'),
                        const SizedBox(width: 24),
                        _HeaderStat(label: 'Active', value: '$activeCount'),
                        const SizedBox(width: 24),
                        _HeaderStat(label: 'Power draw', value: '${totalPower.toStringAsFixed(2)} kW'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text('Devices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (roomDevices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                  child: Text('No devices in this room yet.', style: TextStyle(color: Colors.grey.shade600)),
                )
              else
                ...roomDevices.map((device) => _RoomDeviceCard(device: device)),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: Colors.white.withAlpha((0.75 * 255).round()), fontSize: 11)),
      ],
    );
  }
}

class _RoomDeviceCard extends StatelessWidget {
  final SmartDevice device;

  const _RoomDeviceCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(device.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DeviceDetailScreen(device: device)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withAlpha((0.12 * 255).round()),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(deviceTypeIcon(device.type), color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(device.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            deviceTypeLabel(device.type),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(status: device.status),
                  ],
                ),
                if (device.isMultiSwitch) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(device.childSwitches.length, (i) {
                      final child = device.childSwitches[i];
                      return _MiniSwitchChip(
                        label: child.label.isEmpty ? 'Switch ${i + 1}' : child.label,
                        isOn: child.isOn,
                        onTap: () => runDeviceAction(
                          context,
                          () => CloudSyncService().updateMultiSwitchState(device.id, i, !child.isOn),
                        ),
                      );
                    }),
                  ),
                ] else if (device.status != DeviceStatus.error && device.status != DeviceStatus.disconnected) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        device.type == DeviceType.scheduledAppliance && device.isOn
                            ? 'Tap for the safety countdown'
                            : 'Manual control',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                      Switch(
                        value: device.isOn,
                        onChanged: (value) => runDeviceAction(
                          context,
                          () => CloudSyncService().updateDeviceState(device.id, isOn: value),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniSwitchChip extends StatelessWidget {
  final String label;
  final bool isOn;
  final VoidCallback onTap;

  const _MiniSwitchChip({required this.label, required this.isOn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isOn ? const Color(0xFF16A34A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isOn ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

/// Full detail + control screen for one device.
///
/// The body is type-specific: a safety-critical appliance gets a live
/// countdown to its automatic cutoff, a scheduled light gets a window editor,
/// a camera gets a mock preview, and a gang box gets its addressable
/// switches. Every type shares the same header, manual-control affordance
/// (where it makes sense) and recent-activity list.
class DeviceDetailScreen extends StatefulWidget {
  final SmartDevice device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Redraws the countdown once a second. Cheap: it only rebuilds this
    // screen, and only while a safety-critical appliance is on screen.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _rename(BuildContext context, SmartDevice device) async {
    final controller = TextEditingController(text: device.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename device'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    await runDeviceAction(context, () => CloudSyncService().renameDevice(device.id, name));
  }

  @override
  Widget build(BuildContext context) {
    final cloud = CloudSyncService();

    // Prefer the live stream so edits made from this very screen (schedule,
    // max duration, toggles) reflect immediately without a manual refresh.
    return StreamBuilder<List<SmartDevice>>(
      stream: cloud.devicesStream(),
      initialData: [widget.device],
      builder: (context, snapshot) {
        var device = widget.device;
        for (final d in snapshot.data ?? const <SmartDevice>[]) {
          if (d.id == widget.device.id) {
            device = d;
            break;
          }
        }

        final color = statusColor(device.status);

        return Scaffold(
          backgroundColor: const Color(0xFFF4F7FF),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _rename(context, device),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: color.withAlpha((0.10 * 255).round()),
                  border: Border.all(color: color.withAlpha((0.25 * 255).round())),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
                          child: Icon(deviceTypeIcon(device.type), color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(deviceTypeLabel(device.type), style: TextStyle(fontSize: 13, color: color)),
                              const SizedBox(height: 2),
                              Text(
                                'Power draw: ${device.powerUsage.toStringAsFixed(2)} kW',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        StatusChip(status: device.status, fontSize: 12),
                      ],
                    ),
                    if (device.lastAlert != null && device.lastAlert!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((0.6 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(device.lastAlert!, style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ..._buildTypeSpecificBody(context, device, cloud),
              const SizedBox(height: 20),
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Room'),
                trailing: Text(device.roomId),
              ),
              const SizedBox(height: 20),
              const Text('Recent activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _UsageHistory(deviceId: device.id, available: cloud.isFirebaseAvailable),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildTypeSpecificBody(BuildContext context, SmartDevice device, CloudSyncService cloud) {
    switch (device.type) {
      case DeviceType.multiSwitch:
        return [_MultiSwitchSection(device: device)];
      case DeviceType.scheduledAppliance:
        return [_SafetyCutoffSection(device: device)];
      case DeviceType.scheduledLight:
        return [_ScheduleSection(device: device)];
      case DeviceType.camera:
        return [_CameraPreviewSection(device: device)];
      case DeviceType.outlet:
        return [_ManualControlSection(device: device)];
    }
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: child,
    );
  }
}

class _ManualControlSection extends StatelessWidget {
  final SmartDevice device;

  const _ManualControlSection({required this.device});

  @override
  Widget build(BuildContext context) {
    final disabled = device.status == DeviceStatus.error || device.status == DeviceStatus.disconnected;
    return _Card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Power', style: TextStyle(fontWeight: FontWeight.w700)),
          Switch(
            value: device.isOn,
            onChanged: disabled
                ? null
                : (value) => runDeviceAction(
                      context,
                      () => CloudSyncService().updateDeviceState(device.id, isOn: value),
                    ),
          ),
        ],
      ),
    );
  }
}

class _MultiSwitchSection extends StatelessWidget {
  final SmartDevice device;

  const _MultiSwitchSection({required this.device});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Switches', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Each switch on this unit is controlled independently.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          ...List.generate(device.childSwitches.length, (i) {
            final child = device.childSwitches[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(child.label.isEmpty ? 'Switch ${i + 1}' : child.label),
                  Switch(
                    value: child.isOn,
                    onChanged: (value) => runDeviceAction(
                      context,
                      () => CloudSyncService().updateMultiSwitchState(device.id, i, value),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Live countdown to the automatic safety cutoff for a fire-hazard appliance
/// (e.g. an iron). The backend worker enforces the actual cutoff; this is
/// the same arithmetic run client-side so the person watching the phone sees
/// the same number ticking down that the worker is acting on.
class _SafetyCutoffSection extends StatelessWidget {
  final SmartDevice device;

  const _SafetyCutoffSection({required this.device});

  Future<void> _editBudget(BuildContext context) async {
    final controller = TextEditingController(
      text: (device.maxOnDurationMinutes ?? 15).toString(),
    );
    final minutes = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Maximum ON duration'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutes', suffixText: 'min'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(int.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (minutes == null || minutes <= 0 || !context.mounted) return;
    await runDeviceAction(context, () => CloudSyncService().updateApplianceSchedule(device.id, minutes));
  }

  @override
  Widget build(BuildContext context) {
    final budget = device.maxOnDurationMinutes;
    final isOn = device.isOn;
    final turnedOnAt = device.turnedOnAt;

    Duration elapsed = Duration.zero;
    Duration remaining = Duration.zero;
    double percent = 0;
    if (isOn && budget != null && turnedOnAt != null) {
      elapsed = DateTime.now().difference(turnedOnAt);
      final total = Duration(minutes: budget);
      remaining = total - elapsed;
      if (remaining.isNegative) remaining = Duration.zero;
      percent = (elapsed.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    }

    final barColor = percent > 0.85
        ? const Color(0xFFEF4444)
        : (percent > 0.6 ? const Color(0xFFF59E0B) : const Color(0xFF16A34A));

    String fmt(Duration d) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return h > 0 ? '$h:$m:$s' : '$m:$s';
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 18, color: Color(0xFFB45309)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Automatic safety cutoff', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              TextButton(onPressed: () => _editBudget(context), child: const Text('Edit')),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            budget == null
                ? 'No maximum set. Set a budget so this appliance cannot be left on unattended.'
                : 'Automatically switches off after $budget minutes continuously ON.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 18),
          if (isOn && budget != null && turnedOnAt != null)
            Center(
              child: CircularPercentIndicator(
                radius: 64,
                lineWidth: 12,
                percent: percent,
                circularStrokeCap: CircularStrokeCap.round,
                backgroundColor: Colors.grey.shade200,
                progressColor: barColor,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(fmt(remaining), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const Text('remaining', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.power_off_rounded, color: Colors.grey.shade400, size: 18),
                const SizedBox(width: 8),
                Text('Not currently running', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Manual power', style: TextStyle(fontWeight: FontWeight.w700)),
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
        ],
      ),
    );
  }
}

/// Editor for a scheduled light's automatic ON/OFF window.
class _ScheduleSection extends StatelessWidget {
  final SmartDevice device;

  const _ScheduleSection({required this.device});

  Future<void> _pickTime(BuildContext context, {required bool isStart}) async {
    final current = isStart ? device.scheduleStartTime : device.scheduleEndTime;
    TimeOfDay initial = TimeOfDay.now();
    if (current != null) {
      final parts = current.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) initial = TimeOfDay(hour: h, minute: m);
      }
    }
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !context.mounted) return;

    final hhmm = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    final start = isStart ? hhmm : (device.scheduleStartTime ?? '18:00');
    final end = isStart ? (device.scheduleEndTime ?? '23:00') : hhmm;

    await runDeviceAction(context, () => CloudSyncService().updateLightSchedule(device.id, start, end));
  }

  @override
  Widget build(BuildContext context) {
    final hasSchedule = device.scheduleStartTime != null && device.scheduleEndTime != null;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Automatic schedule', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (hasSchedule)
                TextButton(
                  onPressed: () => runDeviceAction(context, () => CloudSyncService().clearLightSchedule(device.id)),
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'This light switches itself on and off during the window below, independent of the manual switch.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TimeTile(
                  label: 'Turns on',
                  value: device.scheduleStartTime ?? '--:--',
                  onTap: () => _pickTime(context, isStart: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeTile(
                  label: 'Turns off',
                  value: device.scheduleEndTime ?? '--:--',
                  onTap: () => _pickTime(context, isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Manual power', style: TextStyle(fontWeight: FontWeight.w700)),
              Switch(
                value: device.isOn,
                onChanged: (value) => runDeviceAction(
                  context,
                  () => CloudSyncService().updateDeviceState(device.id, isOn: value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeTile({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

/// Mock camera preview: a stand-in for a real streaming widget. Shows the
/// snapshot URI the simulator would publish rather than a fake photo, which
/// is a more honest demo of "the app reads a URI the backend controls" than
/// a picture pulled from the open internet.
class _CameraPreviewSection extends StatelessWidget {
  final SmartDevice device;

  const _CameraPreviewSection({required this.device});

  @override
  Widget build(BuildContext context) {
    final uri = 'assets/images/cameras/front_porch.jpg';
    final live = device.status == DeviceStatus.on;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Camera feed', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraImage(uri: uri, live: live),
                  if (!live) Container(color: Colors.black.withAlpha((0.35 * 255).round())),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((0.45 * 255).round()),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: live ? const Color(0xFFEF4444) : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            live ? 'LIVE (simulated)' : 'OFFLINE',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('Snapshot URI', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          SelectableText(uri, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Camera power', style: TextStyle(fontWeight: FontWeight.w700)),
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
        ],
      ),
    );
  }
}

class _UsageHistory extends StatelessWidget {
  final String deviceId;
  final bool available;

  const _UsageHistory({required this.deviceId, required this.available});

  @override
  Widget build(BuildContext context) {
    if (!available) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Text(
          'Usage history appears once this app is connected to Firebase.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      );
    }

    return StreamBuilder<List<UsageLog>>(
      stream: UsageService().streamForDevice(deviceId, limit: 10),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? const [];
        if (logs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Text('No activity recorded yet.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          );
        }

        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: List.generate(logs.length, (i) {
              final log = logs[i];
              final icon = log.wasCutOff
                  ? Icons.shield_outlined
                  : (log.event == UsageEvent.on ? Icons.power_settings_new_rounded : Icons.power_off_rounded);
              final color = log.wasCutOff
                  ? const Color(0xFFB45309)
                  : (log.event == UsageEvent.on ? const Color(0xFF16A34A) : Colors.grey.shade500);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        log.wasCutOff
                            ? 'Switched off by safety worker after ${DeviceUsageSummary.formatDuration(log.duration)}'
                            : (log.event == UsageEvent.on ? 'Turned on' : 'Turned off'),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
