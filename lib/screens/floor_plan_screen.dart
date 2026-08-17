import 'package:flutter/material.dart';
import 'package:smart_nest_app/models/device_model.dart';
import 'package:smart_nest_app/models/floor_model.dart';
import 'package:smart_nest_app/models/room_model.dart';
import 'package:smart_nest_app/screens/floor_dashboard_screen.dart';
import 'package:smart_nest_app/services/cloud_sync_service.dart';
import 'package:smart_nest_app/widgets/device_action.dart';

/// The abstract grid mapping for a single floor.
///
/// Rooms place themselves by `gridRow` / `gridCol`, so the layout is exactly
/// as wide and tall as the furthest room in either direction -- there is no
/// separate "floor size" to keep in sync. A background floor-plan image can
/// be dropped behind the grid later by setting `floorPlanImageAsset` on the
/// [FloorModel]; until then the grid stands on its own, which is enough to
/// demonstrate the room layout without needing real floor-plan artwork.
class FloorPlanScreen extends StatelessWidget {
  final FloorModel floor;

  const FloorPlanScreen({super.key, required this.floor});

  Future<void> _addRoom(BuildContext context, List<Room> existingRooms) async {
    final nameController = TextEditingController();
    int gridRow = 0;
    int gridCol = 0;

    // Suggest the next free cell in row-major order so a demo doesn't have
    // to think about coordinates.
    final occupied = existingRooms.map((r) => '${r.gridRow}:${r.gridCol}').toSet();
    outer:
    for (var r = 0; r < 6; r++) {
      for (var c = 0; c < 4; c++) {
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
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
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
          final rooms = roomSnap.data ?? const [];

          return StreamBuilder<List<SmartDevice>>(
            stream: cloud.devicesStream(),
            builder: (context, deviceSnap) {
              final devices = deviceSnap.data ?? const [];

              if (rooms.isEmpty) {
                return _EmptyRooms(onAdd: () => _addRoom(context, rooms));
              }

              final maxRow = rooms.map((r) => r.gridRow).fold(0, (a, b) => a > b ? a : b);
              final maxCol = rooms.map((r) => r.gridCol).fold(0, (a, b) => a > b ? a : b);
              final byCell = {for (final r in rooms) '${r.gridRow}:${r.gridCol}': r};

              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE7EAFB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.grid_view_rounded, color: Colors.indigo.shade400, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'Room grid',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap a room to see and control its devices',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        for (var row = 0; row <= maxRow; row++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                for (var col = 0; col <= maxCol; col++)
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(right: col == maxCol ? 0 : 10),
                                      child: _GridCell(
                                        room: byCell['$row:$col'],
                                        devices: byCell['$row:$col'] == null
                                            ? const []
                                            : devices
                                                .where((d) => d.roomId == byCell['$row:$col']!.id)
                                                .toList(),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
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
                                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
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
          final rooms = snap.data ?? const [];
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

class _GridCell extends StatelessWidget {
  final Room? room;
  final List<SmartDevice> devices;

  const _GridCell({required this.room, required this.devices});

  @override
  Widget build(BuildContext context) {
    if (room == null) {
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
          ),
        ),
      );
    }

    final activeCount = devices.where((d) => d.status == DeviceStatus.on).length;
    final hasError = devices.any((d) => d.status == DeviceStatus.error);
    final color = hasError
        ? const Color(0xFFEF4444)
        : (activeCount > 0 ? const Color(0xFF16A34A) : const Color(0xFF6366F1));

    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: color.withAlpha((0.10 * 255).round()),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => FloorDashboardScreen(room: room!)),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withAlpha((0.35 * 255).round())),
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.meeting_room_rounded, color: color, size: 18),
                const SizedBox(height: 4),
                Text(
                  room!.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
                ),
                if (devices.isNotEmpty)
                  Text(
                    '$activeCount/${devices.length}',
                    style: TextStyle(fontSize: 9, color: color.withAlpha((0.85 * 255).round())),
                  ),
              ],
            ),
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
            const Text('No rooms on this floor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Add a room to place it on the grid.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add room'),
            ),
          ],
        ),
      ),
    );
  }
}
