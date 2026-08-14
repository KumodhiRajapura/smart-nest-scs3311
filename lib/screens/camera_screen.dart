import 'package:flutter/material.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cameras = [
      {'name': 'Front Door', 'status': 'Live', 'color': const Color(0xFF2A3E7A)},
      {'name': 'Garden', 'status': 'Recording', 'color': const Color(0xFF1F7A8C)},
      {'name': 'Garage', 'status': 'Motion', 'color': const Color(0xFF5D5FEF)},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Security cameras')),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: cameras.length,
        itemBuilder: (context, index) {
          final camera = cameras[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: camera['color'] as Color,
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 16,
                  top: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((0.25 * 255).round()),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      camera['status'] as String,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camera['name'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Camera feed available',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
