'use strict';

/**
 * Collection names and enum values, mirrored from lib/services/firestore_refs.dart
 * and lib/models/device.dart. If you rename something there, rename it here.
 */

const COLLECTIONS = {
  floors: 'floors',
  devices: 'devices',
  schedules: 'schedules',
  usageLogs: 'usage_logs',
  alerts: 'alerts',
};

const STATUS = {
  on: 'ON',
  off: 'OFF',
  error: 'ERROR',
  disconnected: 'DISCONNECTED',
};

const SOURCE = {
  app: 'app',
  worker: 'worker',
  simulator: 'simulator',
  schedule: 'schedule',
};

const REASON = {
  manual: 'manual',
  safetyCutoff: 'safety_cutoff',
  schedule: 'schedule',
  heartbeatLost: 'heartbeat_lost',
  simulatorFault: 'simulator_fault',
};

const ALERT_TYPE = {
  safetyCutoff: 'safety_cutoff',
  deviceError: 'device_error',
  deviceOffline: 'device_offline',
  scheduleRun: 'schedule_run',
};

const DEVICE_TYPE = {
  outlet: 'outlet',
  multiSwitch: 'multiswitch',
  light: 'light',
  iron: 'iron',
  camera: 'camera',
};

module.exports = { COLLECTIONS, STATUS, SOURCE, REASON, ALERT_TYPE, DEVICE_TYPE };
