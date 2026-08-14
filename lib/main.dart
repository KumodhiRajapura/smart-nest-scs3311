import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Provider package removed; provide simple InheritedWidget locally instead.
import 'package:smart_nest_app/screens/splash_screen.dart';
import 'package:smart_nest_app/config/app_theme.dart';
import 'package:smart_nest_app/services/auth_service.dart';
import 'package:smart_nest_app/services/firestore_service.dart';
// If lib/firebase_options.dart exists, use it for platform-specific options.
import 'package:smart_nest_app/firebase_options.dart' show DefaultFirebaseOptions;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options != null) {
      await Firebase.initializeApp(options: options);
    } else {
      // If no generated options are present, initialize only on non-web platforms
      // without options. On web, options are required; fall back to demo mode.
      if (!kIsWeb) await Firebase.initializeApp();
      else debugPrint('No Firebase options for web; running demo fallback.');
    }
  } catch (e) {
    // If Firebase isn't configured or initialization fails, the app will fall back to demo behavior.
    debugPrint('Firebase.initializeApp failed: $e');
  }

  runApp(ServicesProvider(
    authService: AuthService(),
    firestoreService: FirestoreService(),
    child: const SmartNestApp(),
  ));
}

class ServicesProvider extends InheritedWidget {
  final AuthService authService;
  final FirestoreService firestoreService;

  const ServicesProvider({
    required this.authService,
    required this.firestoreService,
    required super.child,
    super.key,
  });

  static ServicesProvider of(BuildContext context) {
    final ServicesProvider? result = context.dependOnInheritedWidgetOfExactType<ServicesProvider>();
    assert(result != null, 'No ServicesProvider found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(ServicesProvider oldWidget) =>
      authService != oldWidget.authService || firestoreService != oldWidget.firestoreService;
}

class SmartNestApp extends StatelessWidget {
  const SmartNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Nest',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const SplashScreen(),
    );
  }
}
