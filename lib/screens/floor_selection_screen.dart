import 'package:flutter/material.dart';
import 'package:smart_nest_app/models/room_model.dart';
import 'package:smart_nest_app/screens/floor_dashboard_screen.dart';
import 'package:smart_nest_app/services/smart_home_service.dart';
import 'package:smart_nest_app/widgets/room_card.dart';

class FloorSelectionScreen extends StatelessWidget {
  const FloorSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Room> rooms = const SmartHomeService().getRooms();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor plans'),
      ),
      body: ListView.builder(
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
      ),
    );
  }
}
