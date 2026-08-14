import 'package:cloud_firestore/cloud_firestore.dart';

/// Every collection path in the system, in one place.
///
/// The Flutter app, the web simulator and the Node worker all address the same
/// five collections. Keeping the names here (and mirroring them in
/// `worker/collections.js` and the simulator client) means a rename is a
/// three-file change instead of a hunt through string literals.
abstract final class Collections {
  static const floors = 'floors';
  static const devices = 'devices';
  static const schedules = 'schedules';
  static const usageLogs = 'usage_logs';
  static const alerts = 'alerts';
}

/// Raw typed references. Repositories map these into model objects.
abstract final class Refs {
  static FirebaseFirestore get db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get floors =>
      db.collection(Collections.floors);

  static CollectionReference<Map<String, dynamic>> get devices =>
      db.collection(Collections.devices);

  static CollectionReference<Map<String, dynamic>> get schedules =>
      db.collection(Collections.schedules);

  static CollectionReference<Map<String, dynamic>> get usageLogs =>
      db.collection(Collections.usageLogs);

  static CollectionReference<Map<String, dynamic>> get alerts =>
      db.collection(Collections.alerts);

  static DocumentReference<Map<String, dynamic>> device(String id) =>
      devices.doc(id);

  static DocumentReference<Map<String, dynamic>> floor(String id) =>
      floors.doc(id);

  static DocumentReference<Map<String, dynamic>> schedule(String id) =>
      schedules.doc(id);
}
