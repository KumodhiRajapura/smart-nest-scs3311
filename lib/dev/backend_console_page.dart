import 'dart:async';

import 'package:flutter/material.dart';

import '../models/alert.dart';
import '../models/device.dart';
import '../models/usage_log.dart';
import '../services/alert_repository.dart';
import '../services/device_repository.dart';
import '../services/usage_repository.dart';

/// Developer console for the backend layer.
///
/// This is deliberately ugly. It exists so the Firestore layer, the worker and
/// the notifications can be built and demonstrated before any of the real UI
/// exists, and so a regression in the data layer can be told apart from a
/// regression in the dashboard. Point `home:` at the real dashboard when it
/// lands; keep this reachable from a debug menu.
class BackendConsolePage extends StatelessWidget {
  const BackendConsolePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Backend console'),
          actions: const [_AlertBadge()],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Devices'),
              Tab(text: 'Usage'),
              Tab(text: 'Alerts'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_DeviceTab(), _UsageTab(), _AlertTab()],
        ),
      ),
    );
  }
}

class _AlertBadge extends StatelessWidget {
  const _AlertBadge();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: const AlertRepository().watchUnreadCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Badge(label: Text('$count'), child: const Icon(Icons.notifications)),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ devices

class _DeviceTab extends StatefulWidget {
  const _DeviceTab();

  @override
  State<_DeviceTab> createState() => _DeviceTabState();
}

class _DeviceTabState extends State<_DeviceTab> {
  static const _repo = DeviceRepository();

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // The safety countdown is derived from `turnedOnAt`, not pushed from the
    // server, so nothing would repaint it without a local tick.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on DeviceControlException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Device>>(
      stream: _repo.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorView(error: snapshot.error!);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final devices = snapshot.data!;
        if (devices.isEmpty) {
          return const _EmptyView(
            message: 'No devices.\nRun  npm run seed  in worker/.',
          );
        }

        return ListView.separated(
          itemCount: devices.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) => _DeviceTile(
            device: devices[i],
            onToggle: () => _guard(() => _repo.toggle(devices[i])),
            onChannel: (index, value) => _guard(
              () => _repo.setChannel(
                deviceId: devices[i].id,
                channelIndex: index,
                isOn: value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.onToggle,
    required this.onChannel,
  });

  final Device device;
  final VoidCallback onToggle;
  final void Function(int channelIndex, bool isOn) onChannel;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      device.type.id,
      if (device.room.isNotEmpty) device.room,
      '(${device.gridX},${device.gridY})',
      if (device.updatedBy != null) 'by ${device.updatedBy}',
    ].join(' · ');

    final remaining = device.remainingSafetySeconds;

    final tile = ListTile(
      leading: _StatusDot(status: device.status),
      title: Text(device.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          if (remaining != null)
            Text(
              'auto-off in ${_mmss(remaining)}',
              style: TextStyle(
                color: remaining < 60
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (device.statusReason == StatusReason.safetyCutoff)
            const Text('cut off by safety worker'),
        ],
      ),
      trailing: device.type.isSwitchable
          ? Switch(value: device.isOn, onChanged: (_) => onToggle())
          : const Icon(Icons.videocam),
    );

    if (!device.type.hasChannels || device.channels.isEmpty) return tile;

    return ExpansionTile(
      leading: _StatusDot(status: device.status),
      title: Text('${device.name}  (${device.onChannelCount}/${device.channels.length} on)'),
      subtitle: Text(subtitle),
      children: [
        for (final channel in device.channels)
          SwitchListTile(
            dense: true,
            title: Text(channel.label),
            value: channel.isOn,
            onChanged: (v) => onChannel(channel.index, v),
          ),
      ],
    );
  }

  static String _mmss(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final DeviceStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      DeviceStatus.on => Colors.green,
      DeviceStatus.off => Colors.grey,
      DeviceStatus.error => Colors.red,
      DeviceStatus.disconnected => Colors.orange,
    };
    return Tooltip(
      message: status.id,
      child: CircleAvatar(radius: 8, backgroundColor: color),
    );
  }
}

// -------------------------------------------------------------------- usage

class _UsageTab extends StatelessWidget {
  const _UsageTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UsageLog>>(
      stream: const UsageRepository()
          .watchSince(DateTime.now().subtract(const Duration(days: 7))),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _ErrorView(error: snapshot.error!);
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final summaries = UsageRepository.summarise(snapshot.data!);
        if (summaries.isEmpty) {
          return const _EmptyView(
            message: 'No usage yet.\nToggle a device with the worker running.',
          );
        }

        return ListView(
          children: [
            for (final s in summaries)
              ListTile(
                title: Text(s.deviceName),
                subtitle: Text('${s.sessionCount} sessions'),
                trailing: Text(
                  s.formattedTotal,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------- alerts

class _AlertTab extends StatelessWidget {
  const _AlertTab();

  @override
  Widget build(BuildContext context) {
    const repo = AlertRepository();
    return StreamBuilder<List<Alert>>(
      stream: repo.watchRecent(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _ErrorView(error: snapshot.error!);
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final alerts = snapshot.data!;
        if (alerts.isEmpty) {
          return const _EmptyView(message: 'No alerts.');
        }

        return ListView.separated(
          itemCount: alerts.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final alert = alerts[i];
            return ListTile(
              leading: Icon(
                alert.type.isCritical ? Icons.local_fire_department : Icons.info,
                color: alert.type.isCritical ? Colors.red : null,
              ),
              title: Text(alert.title),
              subtitle: Text(alert.message),
              trailing: alert.read
                  ? null
                  : TextButton(
                      onPressed: () => repo.markRead(alert.id),
                      child: const Text('Mark read'),
                    ),
            );
          },
        );
      },
    );
  }
}

// ------------------------------------------------------------------ shared

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    // A missing composite index shows up here, and the message Firestore
    // returns contains a link that creates it in one click.
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Text(
          '$error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}
