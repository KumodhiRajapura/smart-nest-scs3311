import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'app_exception.dart';

class AuthService {
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  FirebaseAuth? _auth;

  FirebaseAuth? get _firebaseAuth {
    if (_auth != null) return _auth;
    try {
      // Only access FirebaseAuth.instance if a Firebase app exists.
      if (Firebase.apps.isNotEmpty) {
        _auth = FirebaseAuth.instance;
      }
    } catch (_) {
      _auth = null;
    }
    return _auth;
  }

  Stream<User?> authStateChanges() {
    final a = _firebaseAuth;
    if (a == null) return Stream.value(null);
    return a.authStateChanges();
  }

  User? get currentUser => _firebaseAuth?.currentUser;

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final a = _firebaseAuth;
      if (a == null) throw AppException('Firebase not initialized');
      return await a.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AppException(e.message ?? 'Sign-in failed');
    } catch (e) {
      throw AppException('Sign-in failed');
    }
  }

  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      final a = _firebaseAuth;
      if (a == null) throw AppException('Firebase not initialized');
      return await a.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AppException(e.message ?? 'Registration failed');
    } catch (e) {
      throw AppException('Registration failed');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final a = _firebaseAuth;
      if (a == null) throw AppException('Firebase not initialized');
      await a.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AppException(e.message ?? 'Reset failed');
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        final a = _firebaseAuth;
        if (a == null) throw AppException('Firebase not initialized');
        return await a.signInWithPopup(provider);
      }

      // Mobile Google sign-in is not implemented here. Mobile clients should use google_sign_in plugin.
      return null;
    } on FirebaseAuthException catch (e) {
      throw AppException(e.message ?? 'Google sign-in failed');
    } catch (e) {
      throw AppException('Google sign-in failed');
    }
  }

  Future<void> signOut() async {
    final a = _firebaseAuth;
    if (a == null) return;
    await a.signOut();
  }
}