'use strict';


const COLLECTIONS = {
  floors: 'floors',
  rooms: 'rooms',
  devices: 'devices',
  usageLogs: 'usage_logs',
  alerts: 'alerts',
};

const STATUS = {
  on: 'on',
  off: 'off',
  error: 'error',
  disconnected: 'disconnected',
};

const SOURCE = {
  app: 'mobile_app',
  simulator: 'simulator',
  worker: 'backend_worker',
};

const REASON = {
  manual: 'manual',
  safetyCutoff: 'safety_cutoff',
  schedule: 'schedule',
  heartbeatLost: 'heartbeat_lost',
  heartbeatRecovered: 'heartbeat_recovered',
  simulatorFault: 'simulator_fault',
};

const ALERT_TYPE = {
  safetyCutoff: 'safety_cutoff',
  deviceError: 'device_error',
  deviceOffline: 'device_offline',
  scheduleRun: 'schedule_run',
};

const SEVERITY = {
  info: 'info',
  warning: 'warning',
  critical: 'critical',
};

const DEVICE_TYPE = {
  outlet: 'outlet',
  multiSwitch: 'multiSwitch',
  scheduledAppliance: 'scheduledAppliance',
  scheduledLight: 'scheduledLight',
  camera: 'camera',
};

const USAGE_EVENT = {
  on: 'on',
  off: 'off',
  autoOffSafety: 'auto_off_safety',
  error: 'error',
  disconnected: 'disconnected',
};

module.exports = {
  COLLECTIONS,
  STATUS,
  SOURCE,
  REASON,
  ALERT_TYPE,
  SEVERITY,
  DEVICE_TYPE,
  USAGE_EVENT,
};
