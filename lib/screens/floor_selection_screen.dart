import 'package:flutter/material.dart';
import 'package:smart_nest_app/models/device_model.dart';
import 'package:smart_nest_app/models/floor_model.dart';
import 'package:smart_nest_app/models/room_model.dart';
import 'package:smart_nest_app/screens/floor_plan_screen.dart';
import 'package:smart_nest_app/services/cloud_sync_service.dart';
import 'package:smart_nest_app/widgets/device_action.dart';

/// Multi-floor dashboard required by SCS 3311.
///
/// Each floor is live from Firestore, can be added/renamed/deleted, and opens
/// into its own room grid/floor-plan view.
class FloorSelectionScreen extends StatelessWidget {
  const FloorSelectionScreen({super.key});

  Future<void> _addFloor(BuildContext context, int nextOrder) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add floor'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Floor name',
            hintText: 'e.g. Second Floor',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty || !context.mounted) return;

    final plan = nextOrder == 0
        ? 'assets/images/floor_plans/ground_floor.png'
        : 'assets/images/floor_plans/upper_floor.png';

    await runDeviceAction(
      context,
      () => CloudSyncService().createFloor(
        name: name,
        order: nextOrder,
        floorPlanImageUrl: plan,
      ),
    );
  }

  Future<void> _renameFloor(BuildContext context, FloorModel floor) async {
    final controller = TextEditingController(text: floor.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename floor'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Floor name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty || !context.mounted) return;
    await runDeviceAction(
      context,
      () => CloudSyncService().updateFloor(floor.id, name: name),
    );
  }

  Future<void> _deleteFloor(BuildContext context, FloorModel floor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${floor.name}?'),
        content: const Text(
          'This removes the floor, its rooms, and devices belonging to those rooms.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await runDeviceAction(context, () => CloudSyncService().deleteFloor(floor.id));
  }

  @override
  Widget build(BuildContext context) {
    final cloud = CloudSyncService();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Floors', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<List<FloorModel>>(
        stream: cloud.floorsStream(),
        builder: (context, floorSnap) {
          final floors = [...(floorSnap.data ?? const <FloorModel>[])]
            ..sort((a, b) => a.order.compareTo(b.order));

          return StreamBuilder<List<Room>>(
            stream: cloud.roomsStream(),
            builder: (context, roomSnap) {
              final rooms = roomSnap.data ?? const <Room>[];

              return StreamBuilder<List<SmartDevice>>(
                stream: cloud.devicesStream(),
                builder: (context, deviceSnap) {
                  final devices = deviceSnap.data ?? const <SmartDevice>[];

                  if (floors.isEmpty) {
                    return _EmptyFloors(onAdd: () => _addFloor(context, 0));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                    itemCount: floors.length,
                    itemBuilder: (context, index) {
                      final floor = floors[index];
                      final floorRooms = rooms.where((r) => r.floorId == floor.id).toList();
                      final roomIds = floorRooms.map((r) => r.id).toSet();
                      final floorDevices = devices.where((d) => roomIds.contains(d.roomId)).toList();
                      final activeCount = floorDevices.where((d) => d.status == DeviceStatus.on).length;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _FloorCard(
                          floor: floor,
                          roomCount: floorRooms.length,
                          deviceCount: floorDevices.length,
                          activeCount: activeCount,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => FloorPlanScreen(floor: floor)),
                          ),
                          onRename: () => _renameFloor(context, floor),
                          onDelete: () => _deleteFloor(context, floor),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder<List<FloorModel>>(
        stream: cloud.floorsStream(),
        builder: (context, snap) {
          final nextOrder = (snap.data ?? const <FloorModel>[]).length;
          return FloatingActionButton.extended(
            onPressed: () => _addFloor(context, nextOrder),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add floor'),
          );
        },
      ),
    );
  }
}

class _FloorCard extends StatelessWidget {
  final FloorModel floor;
  final int roomCount;
  final int deviceCount;
  final int activeCount;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _FloorCard({
    required this.floor,
    required this.roomCount,
    required this.deviceCount,
    required this.activeCount,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(floor.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      '$roomCount rooms · $deviceCount devices',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$activeCount active',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'rename') onRename();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFloors extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyFloors({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apartment_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No floors yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Add your first floor to start laying out rooms and devices.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add floor'),
            ),
          ],
        ),
      ),
    );
  }
}
