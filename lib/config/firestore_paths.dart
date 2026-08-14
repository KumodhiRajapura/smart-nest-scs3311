/// Centralized Firestore collection and field name constants.
///
/// This is the schema contract. The Flutter app, the web simulator
/// (`web-simulator/src/services/firebase.ts`) and the backend worker
/// (`worker/src/constants.js`) must all use these exact names -- a rename here
/// is a three-file change, and a mismatch is invisible until a field silently
/// stops arriving.
///
/// Canonical definition: `firebase/SCHEMA.md`.
class FirestorePaths {
  static const floors = 'floors';
  static const rooms = 'rooms';
  static const devices = 'devices';
  static const usageLogs = 'usage_logs';
  static const alerts = 'alerts';
}

/// Document field names used by the client and expected from the backend.
class Fields {
  // --- identity / placement -------------------------------------------------
  static const id = 'id';
  static const name = 'name';
  static const floorId = 'floorId';
  static const roomId = 'roomId';
  static const type = 'type';

  // --- state ----------------------------------------------------------------
  static const status = 'status';
  static const switches = 'switches';
  static const childSwitches = 'childSwitches';

  /// Server timestamp of the most recent OFF -> ON edge, cleared on OFF.
  ///
  /// The safety worker derives its entire countdown from this one field, so
  /// every writer must maintain it the same way: set it *only* on a real
  /// transition to ON (never refresh it on a device that is already on, which
  /// would hand the appliance a fresh budget), and null it on OFF.
  static const turnedOnAt = 'turnedOnAt';

  /// Legacy alias kept so older documents still parse. Do not write it.
  static const lastTurnedOnAt = 'lastTurnedOnAt';

  // --- configuration --------------------------------------------------------
  static const maxOnDurationMinutes = 'maxOnDurationMinutes';
  static const scheduleStartTime = 'scheduleStartTime';
  static const scheduleEndTime = 'scheduleEndTime';
  static const scheduleDays = 'scheduleDays';
  static const scheduleEnabled = 'scheduleEnabled';
  static const cameraImageUrls = 'cameraImageUrls';
  static const deviceIds = 'deviceIds';

  // --- provenance -----------------------------------------------------------
  static const lastUpdated = 'lastUpdated';
  static const updatedBy = 'updatedBy';

  /// Why the status last changed: `manual`, `safety_cutoff`, `schedule`,
  /// `heartbeat_lost`. Shown in the UI and invaluable in a demo -- "switched
  /// off by the safety worker" reads very differently from a value that just
  /// changed on its own.
  static const statusReason = 'statusReason';

  /// Written by the simulator on a timer. When it goes stale the worker marks
  /// the device DISCONNECTED.
  static const lastHeartbeat = 'lastHeartbeat';

  // --- backend-only ---------------------------------------------------------
  // Clients must never write these; firestore.rules rejects it.
  static const lastAlert = 'lastAlert';
  static const lastAlertAt = 'lastAlertAt';
}

/// Field names inside a `usage_logs` document.
class UsageFields {
  static const deviceId = 'deviceId';
  static const deviceName = 'deviceName';
  static const roomId = 'roomId';

  /// `on` | `off` | `auto_off_safety` | `error` | `disconnected`
  static const event = 'event';
  static const timestamp = 'timestamp';
  static const durationOnMinutes = 'durationOnMinutes';

  /// Seconds alongside minutes: a two-minute safety demo rounds to "2 min"
  /// either way, but the report needs the real figure to be believable.
  static const durationOnSeconds = 'durationOnSeconds';
  static const createdBy = 'createdBy';
}

/// Field names inside an `alerts` document.
class AlertFields {
  static const deviceId = 'deviceId';
  static const deviceName = 'deviceName';
  static const message = 'message';
  static const severity = 'severity';
  static const type = 'type';
  static const createdAt = 'createdAt';
  static const acknowledged = 'acknowledged';
  static const createdBy = 'createdBy';
}

/// Legal values for [Fields.status]. Lowercase on the wire; the UI uppercases
/// them for display, which is what the specification shows.
class DeviceStatusValues {
  static const on = 'on';
  static const off = 'off';
  static const error = 'error';
  static const disconnected = 'disconnected';

  static const all = [on, off, error, disconnected];
}

/// Legal values for [Fields.updatedBy].
class UpdateSources {
  static const app = 'mobile_app';
  static const simulator = 'simulator';
  static const worker = 'backend_worker';

  static const all = [app, simulator, worker];
}

/// Legal values for [Fields.statusReason].
class StatusReasons {
  static const manual = 'manual';
  static const safetyCutoff = 'safety_cutoff';
  static const schedule = 'schedule';
  static const heartbeatLost = 'heartbeat_lost';
  static const heartbeatRecovered = 'heartbeat_recovered';
  static const simulatorFault = 'simulator_fault';
}
