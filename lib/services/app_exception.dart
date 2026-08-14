/// A failure worth showing the user, rather than a raw Firestore error string.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}
