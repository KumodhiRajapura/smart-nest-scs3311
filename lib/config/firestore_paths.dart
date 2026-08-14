/// Centralized Firestore collection and field name constants.
/// Share these with backend / simulator to keep schema consistent.
class FirestorePaths {
  static const floors = 'floors';
  static const rooms = 'rooms';
  static const devices = 'devices';
  static const alerts = 'alerts';
  static const usageLogs = 'usage_logs';
}

/// Document field names used by the client and expected from the backend.
class Fields {
  static const id = 'id';
  static const name = 'name';
  static const floorId = 'floorId';
  static const roomId = 'roomId';
  static const type = 'type';
  static const status = 'status';
  static const isOn = 'isOn';
  static const switches = 'switches';
  static const maxOnDurationMinutes = 'maxOnDurationMinutes';
  static const lastTurnedOnAt = 'lastTurnedOnAt';
  // New canonical field name used in schema: turnedOnAt (server Timestamp). Keep the
  // legacy lastTurnedOnAt name for compatibility with older code that may still
  // write/read it.
  static const turnedOnAt = 'turnedOnAt';
  static const scheduleStartTime = 'scheduleStartTime';
  static const scheduleEndTime = 'scheduleEndTime';
  static const cameraImageUrls = 'cameraImageUrls';
  static const deviceIds = 'deviceIds';
  static const lastUpdated = 'lastUpdated';
  static const updatedBy = 'updatedBy';
}
