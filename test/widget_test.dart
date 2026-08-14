// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_nest_app/main.dart';
import 'package:smart_nest_app/services/auth_service.dart';
import 'package:smart_nest_app/services/firestore_service.dart';

void main() {
  testWidgets('Smart Nest app loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      ServicesProvider(
        authService: AuthService(),
        firestoreService: FirestoreService(),
        child: const SmartNestApp(),
      ),
    );
    expect(find.text('Smart Nest'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    // App may show the home screen or the sign-in screen depending on Firebase
    // configuration in the test environment. Accept either.
    final foundWelcome = find.text('Welcome home').evaluate().isNotEmpty;
    final foundSignIn = find.text('Sign in').evaluate().isNotEmpty;
    expect(foundWelcome || foundSignIn, isTrue);
  });
}
