import 'package:flutter/material.dart';
// Removed provider dependency to avoid missing package import.
import 'package:smart_nest_app/config/app_config.dart';
import 'package:smart_nest_app/screens/sign_in_screen.dart';
import 'package:smart_nest_app/screens/main_shell.dart';
import 'package:smart_nest_app/services/cloud_sync_service.dart';
import 'package:smart_nest_app/services/auth_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final cloud = CloudSyncService();
    // Use a direct instance of AuthService instead of Provider to avoid
    // requiring the 'provider' package in this example.
    final auth = AuthService();

    if (!cloud.isFirebaseAvailable && AppConfig.enableLocalDemoFallback) {
      return const MainShell();
    }

    return StreamBuilder(
      stream: auth.authStateChanges(),
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;
        if (user == null) {
          return const SignInScreen();
        }

        return const MainShell();
      },
    );
  }
}
