class AppConfig {
  /// Set this to true only for local demo/testing when Firebase is unavailable.
  /// Production builds should leave this as false so the app requires auth.
  static const bool enableLocalDemoFallback = true;

  /// Toggle Google Sign-in if you enable the Google provider in Firebase.
  static const bool enableGoogleSignIn = true;
}
