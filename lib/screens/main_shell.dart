import 'package:flutter/material.dart';
import 'package:smart_nest_app/screens/camera_screen.dart';
import 'package:smart_nest_app/screens/floor_selection_screen.dart';
import 'package:smart_nest_app/screens/home_screen.dart';
import 'package:smart_nest_app/screens/reports_screen.dart';

/// The app's main navigation shell.
///
/// Four tabs cover the primary jobs the spec asks for -- overview, the
/// multi-floor dashboard, reporting, and cameras. Settings and Alerts stay
/// one tap away from Home rather than taking a fifth tab, since they are
/// visited far less often than the other four.
///
/// Each tab keeps its own [Scaffold] and [AppBar]; [IndexedStack] keeps all
/// four alive underneath so switching tabs never re-subscribes their
/// Firestore streams or loses scroll position.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _tabs = [
    HomeScreen(),
    FloorSelectionScreen(),
    ReportsScreen(),
    CameraScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.apartment_outlined), selectedIcon: Icon(Icons.apartment_rounded), label: 'Floors'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.videocam_outlined), selectedIcon: Icon(Icons.videocam_rounded), label: 'Cameras'),
        ],
      ),
    );
  }
}
