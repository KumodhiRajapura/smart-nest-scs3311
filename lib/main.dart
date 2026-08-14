import 'package:flutter/material.dart';

import 'dev/backend_console_page.dart';
import 'services/app_bootstrap.dart';

Future<void> main() async {
  // Firebase, anonymous auth and messaging all have to be up before the first
  // widget tries to attach a Firestore listener.
  await bootstrapBackend();
  runApp(const SmartNestApp());
}

class SmartNestApp extends StatelessWidget {
  const SmartNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Nest',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      // TODO(ui): swap for the dashboard once the floor-plan UI lands. The
      // backend console stays reachable behind a debug menu.
      home: const BackendConsolePage(),
    );
  }
}
