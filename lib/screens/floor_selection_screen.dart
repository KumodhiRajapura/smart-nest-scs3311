import 'package:flutter/material.dart';
import 'package:smart_nest_app/models/room_model.dart';
import 'package:smart_nest_app/screens/floor_dashboard_screen.dart';
import 'package:smart_nest_app/services/cloud_sync_service.dart';
import 'package:smart_nest_app/services/smart_home_service.dart';
import 'package:smart_nest_app/widgets/room_card.dart';

class FloorSelectionScreen extends StatelessWidget {
  const FloorSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cloud = CloudSyncService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor plans'),
      ),
      // The room ids have to come from the same place the device ids do.
      // FloorDashboardScreen filters devices by `device.roomId == room.id`, so a
      // fixture room ('room-living') can never match a seeded device
      // ('room_living') and every room reads as empty.
      body: StreamBuilder<List<Room>>(
        stream: cloud.roomsStream(),
        builder: (context, snapshot) {
          final rooms = snapshot.data ?? const SmartHomeService().getRooms();

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FloorDashboardScreen(room: room),
                      ),
                    );
                  },
                  child: RoomCard(room: room),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
