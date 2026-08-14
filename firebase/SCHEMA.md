Smart Nest — Firestore Schema (Canonical)

Purpose
-------
This document is the canonical schema for the Smart Nest project (SCS3311). Mobile (Member 1) and Web Simulator (Member 3) must read/write exactly these field/collection names and types. The backend (Member 2) implements server-side automation and sets fields that clients MUST NOT set directly (see rules).

Collections
-----------
Top-level collections (all paths are top-level unless noted):

1) floors/{floorId}
- name: string
- order: number (integer for ordering)
- floorPlanImageUrl: string | null (public URL or storage path)

Rationale: small collection, read by clients to show floor list. We keep floors top-level for simplicity.

2) rooms/{roomId}
- id: string (document id)
- floorId: string (reference to floors collection)
- name: string
- gridRow: number (int)
- gridCol: number (int)
- deviceIds: array<string> (optional, denormalized list of device ids in the room)

Rationale: rooms are top-level so we can query across floors easily. Each room references floorId.

3) devices/{deviceId}
Each device is a top-level document so Cloud Functions and workers can query across all devices efficiently.

Common fields (all devices):
- id: string (document id)
- roomId: string
- floorId: string
- name: string
- type: string (enum: "outlet" | "multiSwitch" | "scheduledAppliance" | "scheduledLight" | "camera")
- status: string (enum: "on" | "off" | "error" | "disconnected")
- updatedBy: string ("mobile_app" | "simulator" | "backend_worker")
- lastUpdated: Timestamp (server timestamp — always set on writes)
- lastAlert: string | null (backend-only field — clients MUST NOT write this)
- lastAlertAt: Timestamp | null (backend-only field)

Type-specific fields:
- multiSwitch:
  - childSwitches: array of { id: string, label: string, isOn: boolean }
- scheduledAppliance:
  - maxOnDurationMinutes: number (int) | null
  - turnedOnAt: Timestamp | null (set when status -> "on", cleared when status -> "off")
- scheduledLight:
  - scheduleStartTime: string "HH:mm" | null
  - scheduleEndTime: string "HH:mm" | null
- camera:
  - cameraImageUrls: array<string> | null

Notes:
- turnedOnAt is authoritative for computing elapsed ON time. Backend will compute usageLogs and enforce safety cutoffs.
- Clients may write status changes, but backend Cloud Functions will stamp/compute turnedOnAt / usage logs where applicable.

4) usageLogs/{logId}
- deviceId: string
- event: string ("on" | "off" | "auto_off_safety" | "error" | "disconnected")
- timestamp: Timestamp
- durationOnMinutes: number | null (filled on off events when server computes the duration)
- createdBy: string (usually "backend_worker")

Purpose: store per-device events for reporting. Backend function(s) write these when status flips.

5) alerts/{alertId}
- deviceId: string
- deviceName: string
- message: string
- severity: string ("info" | "warning" | "critical")
- createdAt: Timestamp
- acknowledged: boolean (default false)
- createdBy: string (backend must set this to "backend_worker")

Purpose: persistent alert history for UI and for triggering FCM pushes.

Indexes
-------
Suggested indexes (firestore.indexes.json):
- devices: composite indexes for queries like (type, status), (roomId, type), or (floorId, type) depending on UI queries. At minimum:
  - collection: devices, fields: [{fieldPath: "roomId", order: "ASCENDING"}, {fieldPath: "type", order: "ASCENDING"}]
  - collection: usage_logs, fields: [{fieldPath: "deviceId", order: "ASCENDING"}, {fieldPath: "timestamp", order: "DESCENDING"}]

Security contract (high level)
------------------------------
- Reads: allowed for all collections.
- Writes:
  - devices: clients (mobile_app, simulator) may update allowed fields: status, childSwitches, turnedOnAt (the client can set turnedOnAt when switching on but backend will also stamp if missing), scheduleStartTime/scheduleEndTime, updatedBy, lastUpdated. Clients MUST NOT write lastAlert or lastAlertAt; those are backend-only.
  - usageLogs and alerts: only backend (Admin SDK) or clients with admin custom claim may write. Typical workflow: backend function writes usageLogs and alerts.

Timezones
---------
- Scheduled tasks (lights & safety cutoffs) will run in a chosen timezone. Recommended (project default): Asia/Colombo. Document this choice so front-end times are interpreted the same way.

Decision notes & tradeoffs
-------------------------
- Devices are top-level to simplify cross-device queries by the backend (safety enforcement and reporting).
- Alerts and usageLogs are backend-written to avoid client spoofing. Admin SDK bypasses rules and is used by Cloud Functions.
- Safety cutoff: implement as scheduled worker every minute (simple, robust for an academic project). Optionally, Cloud Tasks could be used for exact per-device scheduling.

Contact
-------
When you (Member 1/3) implement UI or simulator, use these field names exactly. If a change is necessary, discuss and agree before modifying the schema.
