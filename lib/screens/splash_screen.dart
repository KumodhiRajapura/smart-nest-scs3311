import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smart_nest_app/screens/auth_gate.dart';
import 'package:smart_nest_app/services/cloud_sync_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize cloud sync (Firebase) while showing the splash but
    // don't block navigation in case initialization hangs in test or
    // development environments. Navigate to the auth gate after a
    // short delay regardless.
    CloudSyncService().init();
    Future<void>.delayed(const Duration(milliseconds: 800)).then((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F2A44), Color(0xFF4F46E5)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_rounded, size: 92, color: Colors.white),
            const SizedBox(height: 20),
            const Text(
              'Smart Nest',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Monitoring and control',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withAlpha((0.8 * 255).round()),
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
