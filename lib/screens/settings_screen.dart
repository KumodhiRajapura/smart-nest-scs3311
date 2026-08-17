import 'package:flutter/material.dart';
import 'package:smart_nest_app/screens/sign_in_screen.dart';
import 'package:smart_nest_app/services/auth_service.dart';
import 'package:smart_nest_app/services/cloud_sync_service.dart';
import 'package:smart_nest_app/widgets/device_action.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _alertsEnabled = true;
  bool _safetyLock = true;

  @override
  Widget build(BuildContext context) {
    final cloud = CloudSyncService();
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionCard(
            title: 'Connection',
            children: [
              ListTile(
                leading: Icon(
                  cloud.isFirebaseAvailable ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                  color: cloud.isFirebaseAvailable ? const Color(0xFF16A34A) : Colors.grey,
                ),
                title: const Text('Cloud sync'),
                subtitle: Text(cloud.isFirebaseAvailable ? 'Connected to Firebase' : 'Running in demo mode'),
              ),
              if (user != null)
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text('Signed in as'),
                  subtitle: Text(user.email ?? user.uid),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Notifications & safety',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Push alerts'),
                subtitle: const Text('Notify me about safety cutoffs and errors'),
                value: _alertsEnabled,
                onChanged: (v) => setState(() => _alertsEnabled = v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.security_outlined),
                title: const Text('Safety lock'),
                subtitle: const Text('Require confirmation before disabling a safety cutoff'),
                value: _safetyLock,
                onChanged: (v) => setState(() => _safetyLock = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Demo data',
            children: [
              ListTile(
                leading: const Icon(Icons.restart_alt_rounded),
                title: const Text('Seed sample house'),
                subtitle: const Text('Writes the demo floors, rooms and devices if the database is empty'),
                onTap: cloud.isFirebaseAvailable
                    ? () async {
                        await runDeviceAction(context, () => cloud.seedSampleData());
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Seed complete (or already seeded).')),
                          );
                        }
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (user != null)
            _SectionCard(
              title: 'Account',
              children: [
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                  title: const Text('Sign out', style: TextStyle(color: Color(0xFFEF4444))),
                  onTap: () async {
                    await AuthService().signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const SignInScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Smart Nest · SCS 3311',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600, letterSpacing: 0.6),
          ),
        ),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(children: children),
        ),
      ],
    );
  }
}
