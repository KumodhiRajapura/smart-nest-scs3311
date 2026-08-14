import 'package:flutter/material.dart';
import 'package:smart_nest_app/models/room_model.dart';

class RoomCard extends StatelessWidget {
  final Room room;

  const RoomCard({
    super.key,
    required this.room,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                room.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(
                room.climateEnabled ? Icons.ac_unit : Icons.sensor_door,
                color: room.climateEnabled ? Colors.blue : Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            room.description ?? '',
            style: TextStyle(
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${room.devicesCount} devices'),
              Text('${room.temperature.toStringAsFixed(1)}°C'),
            ],
          ),
        ],
      ),
    );
  }
}
