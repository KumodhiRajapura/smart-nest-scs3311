import 'package:flutter/material.dart';
import 'package:smart_nest_app/config/app_config.dart';
import 'package:smart_nest_app/services/cloud_sync_service.dart';
import 'package:smart_nest_app/screens/home_screen.dart';
import 'package:smart_nest_app/main.dart';
import 'package:smart_nest_app/services/auth_service.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  void _showSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signInEmail() async {
    final cloud = CloudSyncService();
    final auth = ServicesProvider.of(context).authService;

    // Local demo fallback: navigate to Home when Firebase not configured
    if (!cloud.isFirebaseAvailable && AppConfig.enableLocalDemoFallback) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await auth.signInWithEmail(_emailController.text.trim(), _passwordController.text);
    } catch (e) {
      _showSnackBar('Sign in failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInGoogle() async {
    setState(() => _loading = true);
    try {
      final cloud = CloudSyncService();
      final auth = ServicesProvider.of(context).authService;
      if (!cloud.isFirebaseAvailable && AppConfig.enableLocalDemoFallback) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
        return;
      }

      // Use AuthService for Google sign-in (CloudSyncService still offers web popup path)
      final cred = await auth.signInWithGoogle();
      if (cred == null) {
        _showSnackBar('Google sign-in canceled or not configured');
        return;
      }
    } catch (e) {
      _showSnackBar('Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.isEmpty) ? 'Enter email' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) => (v == null || v.isEmpty) ? 'Enter password' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _signInEmail,
                child: _loading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign in'),
              ),
              const SizedBox(height: 12),
              if (AppConfig.enableGoogleSignIn)
                OutlinedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                  onPressed: _loading ? null : _signInGoogle,
                )
              else
                const SizedBox.shrink(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _loading ? null : () async {
                        // registration flow
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _loading = true);
                        try {
                           final cloud = CloudSyncService();
                           final auth = ServicesProvider.of(context).authService;
                           if (!cloud.isFirebaseAvailable && AppConfig.enableLocalDemoFallback) {
                             if (!mounted) return;
                             Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
                             return;
                           }

                           await auth.signUpWithEmail(_emailController.text.trim(), _passwordController.text);
                           _showSnackBar('Account created. You are signed in.');
                        } catch (e) {
                           _showSnackBar('Registration failed: $e');
                        } finally {
                           if (mounted) setState(() => _loading = false);
                        }
                      },
                      child: const Text('Register'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: _loading ? null : () async {
                        final email = _emailController.text.trim();
                        if (email.isEmpty) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter email to reset password')));
                          return;
                        }
                        setState(() => _loading = true);
                        try {
                          final cloud = CloudSyncService();
                          final auth = ServicesProvider.of(context).authService;
                          if (!cloud.isFirebaseAvailable && AppConfig.enableLocalDemoFallback) {
                            _showSnackBar('Local demo: password resets are simulated.');
                            return;
                          }

                          await auth.sendPasswordResetEmail(email);
                          _showSnackBar('Password reset sent');
                        } catch (e) {
                          _showSnackBar('Password reset failed: $e');
                        } finally {
                          if (mounted) setState(() => _loading = false);
                        }
                      },
                      child: const Text('Reset password'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  // Developer helper: seed sample data when Firebase available or local demo.
                  try {
                    final cloud = CloudSyncService();
                    if (!cloud.isFirebaseAvailable && AppConfig.enableLocalDemoFallback) {
                      _showSnackBar('Local demo: sample data is already available');
                      if (!mounted) return;
                      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
                      return;
                    }

                    await cloud.seedSampleData();
                    _showSnackBar('Seeded sample data (if Firebase configured)');
                  } catch (e) {
                    _showSnackBar('Seeding failed: $e');
                  }
                },
                child: const Text('Seed sample data (dev)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
