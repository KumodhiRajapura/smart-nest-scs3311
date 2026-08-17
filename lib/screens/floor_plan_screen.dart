import 'package:flutter/material.dart';
import 'package:smart_nest_app/models/device_model.dart';
import 'package:smart_nest_app/models/floor_model.dart';
import 'package:smart_nest_app/models/room_model.dart';
import 'package:smart_nest_app/screens/floor_dashboard_screen.dart';
import 'package:smart_nest_app/services/cloud_sync_service.dart';
import 'package:smart_nest_app/widgets/device_action.dart';

/// Floor representation required by SCS 3311: a sample plan is shown as the
/// background and the live room grid is overlaid on top of it.
class FloorPlanScreen extends StatelessWidget {
  final FloorModel floor;

  const FloorPlanScreen({super.key, required this.floor});

  Future<void> _addRoom(BuildContext context, List<Room> existingRooms) async {
    final nameController = TextEditingController();
    int gridRow = 0;
    int gridCol = 0;

    final occupied = existingRooms.map((r) => '${r.gridRow}:${r.gridCol}').toSet();
    outer:
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 6; c++) {
        if (!occupied.contains('$r:$c')) {
          gridRow = r;
          gridCol = c;
          break outer;
        }
      }
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add room'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Room name', hintText: 'e.g. Study'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StepperField(
                      label: 'Grid row',
                      value: gridRow,
                      onChanged: (v) => setDialogState(() => gridRow = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StepperField(
                      label: 'Grid col',
                      value: gridCol,
                      onChanged: (v) => setDialogState(() => gridCol = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop({
                'name': nameController.text.trim(),
                'row': gridRow,
                'col': gridCol,
              }),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == null || (result['name'] as String).isEmpty || !context.mounted) return;
    await runDeviceAction(
      context,
      () => CloudSyncService().createRoom(
        floorId: floor.id,
        name: result['name'] as String,
        gridRow: result['row'] as int,
        gridCol: result['col'] as int,
      ),
    );
  }

  Future<void> _deleteRoom(BuildContext context, Room room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${room.name}?'),
        content: const Text('This also removes devices assigned to the room.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await runDeviceAction(context, () => CloudSyncService().deleteRoom(room.id));
  }

  @override
  Widget build(BuildContext context) {
    final cloud = CloudSyncService();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(floor.name, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<List<Room>>(
        stream: cloud.roomsForFloorStream(floor.id),
        builder: (context, roomSnap) {
          final rooms = roomSnap.data ?? const <Room>[];

          return StreamBuilder<List<SmartDevice>>(
            stream: cloud.devicesStream(),
            builder: (context, deviceSnap) {
              final devices = deviceSnap.data ?? const <SmartDevice>[];

              if (rooms.isEmpty) {
                return _EmptyRooms(onAdd: () => _addRoom(context, rooms));
              }

              final maxRow = rooms.map((r) => r.gridRow).fold(0, (a, b) => a > b ? a : b);
              final maxCol = rooms.map((r) => r.gridCol).fold(0, (a, b) => a > b ? a : b);
              final byCell = {for (final r in rooms) '${r.gridRow}:${r.gridCol}': r};

              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                children: [
                  _FloorMapCard(
                    floor: floor,
                    maxRow: maxRow,
                    maxCol: maxCol,
                    byCell: byCell,
                    devices: devices,
                  ),
                  const SizedBox(height: 20),
                  const Text('Rooms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  ...rooms.map((room) {
                    final roomDevices = devices.where((d) => d.roomId == room.id).toList();
                    final activeCount = roomDevices.where((d) => d.status == DeviceStatus.on).length;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => FloorDashboardScreen(room: room)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withAlpha((0.1 * 255).round()),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.door_front_door_outlined, color: Colors.indigo),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(room.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${roomDevices.length} devices · $activeCount active · row ${room.gridRow}, col ${room.gridCol}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'delete') _deleteRoom(context, room);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'delete', child: Text('Delete room')),
                                  ],
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder<List<Room>>(
        stream: cloud.roomsForFloorStream(floor.id),
        builder: (context, snap) {
          final rooms = snap.data ?? const <Room>[];
          return FloatingActionButton.extended(
            onPressed: () => _addRoom(context, rooms),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add room'),
          );
        },
      ),
    );
  }
}

class _FloorMapCard extends StatelessWidget {
  final FloorModel floor;
  final int maxRow;
  final int maxCol;
  final Map<String, Room> byCell;
  final List<SmartDevice> devices;

  const _FloorMapCard({
    required this.floor,
    required this.maxRow,
    required this.maxCol,
    required this.byCell,
    required this.devices,
  });

  @override
  Widget build(BuildContext context) {
    final rows = maxRow + 1;
    final cols = maxCol + 1;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7EAFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map_outlined, color: Colors.indigo.shade400, size: 19),
              const SizedBox(width: 8),
              const Text('Interactive floor plan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              Text('$rows × $cols grid', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'The room grid is overlaid on a sample floor layout. Tap a room to control its devices.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 360,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _FloorPlanBackground(asset: floor.floorPlanImageAsset),
                  Container(color: Colors.white.withAlpha((0.48 * 255).round())),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rows * cols,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.45,
                      ),
                      itemBuilder: (context, index) {
                        final row = index ~/ cols;
                        final col = index % cols;
                        final room = byCell['$row:$col'];
                        final roomDevices = room == null
                            ? const <SmartDevice>[]
                            : devices.where((d) => d.roomId == room.id).toList();
                        return _OverlayRoomCell(room: room, devices: roomDevices);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloorPlanBackground extends StatelessWidget {
  final String? asset;

  const _FloorPlanBackground({required this.asset});

  @override
  Widget build(BuildContext context) {
    if (asset == null || asset!.isEmpty) {
      return Container(color: const Color(0xFFF8FAFC));
    }
    if (asset!.startsWith('assets/')) {
      return Image.asset(
        asset!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF8FAFC)),
      );
    }
    if (asset!.startsWith('http')) {
      return Image.network(
        asset!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF8FAFC)),
      );
    }
    return Container(color: const Color(0xFFF8FAFC));
  }
}

class _OverlayRoomCell extends StatelessWidget {
  final Room? room;
  final List<SmartDevice> devices;

  const _OverlayRoomCell({required this.room, required this.devices});

  @override
  Widget build(BuildContext context) {
    if (room == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((0.30 * 255).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha((0.7 * 255).round())),
        ),
      );
    }

    final activeCount = devices.where((d) => d.status == DeviceStatus.on).length;
    final hasError = devices.any((d) => d.status == DeviceStatus.error);
    final color = hasError
        ? const Color(0xFFDC2626)
        : activeCount > 0
            ? const Color(0xFF16A34A)
            : const Color(0xFF4F46E5);

    return Material(
      color: color.withAlpha((0.82 * 255).round()),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FloorDashboardScreen(room: room!)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.meeting_room_rounded, color: Colors.white, size: 19),
              const SizedBox(height: 4),
              Text(
                room!.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '${devices.length} devices · $activeCount on',
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _StepperField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: value > 0 ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => onChanged(value + 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyRooms({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No rooms yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Add rooms and place them on the floor grid.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: const Text('Add room')),
          ],
        ),
      ),
    );
  }
}
