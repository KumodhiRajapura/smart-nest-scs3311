Web Simulator integration (for Member 3)

Purpose
-------
The web hardware simulator should read/write the same Firestore schema as the mobile app. Use the following collection and field names exactly so the backend and mobile app stay in sync.

Read (live update):
- Subscribe to devices collection to receive device state changes in real time.
  _db.collection('devices').where('floorId','==', <floorId>).onSnapshot(...)

Write (simulate hardware):
- To simulate a device state change (e.g., physical button toggled), update the device doc's allowed fields:
  - status: 'on' | 'off' | 'error' | 'disconnected'
  - childSwitches: array[{id,label,isOn}] for multiSwitch
  - updatedBy: 'simulator'
  - lastUpdated: FieldValue.serverTimestamp()

Important rules & contracts
--------------------------
- Do NOT write to lastAlert or lastAlertAt (backend-only).
- When setting a device to 'on', the simulator MAY set turnedOnAt to FieldValue.serverTimestamp() but backend will stamp it if missing.
- Use the Fields defined in firebase/SCHEMA.md exactly.

Testing suggestions
-------------------
- Provide simulator buttons: "simulate error", "simulate disconnected" which set status accordingly.
- Provide a manual "toggle" button that flips status between on/off and sets updatedBy: 'simulator'.
- For scheduled lights: allow editing scheduleStartTime / scheduleEndTime fields (HH:mm) so backend scheduler can turn lights on/off.

Example update (JavaScript):
await db.collection('devices').doc(deviceId).set({
  status: 'on',
  updatedBy: 'simulator',
  lastUpdated: firebase.firestore.FieldValue.serverTimestamp(),
  turnedOnAt: firebase.firestore.FieldValue.serverTimestamp(),
}, { merge: true });

Contact Member 2 for schema questions and for any needed test data seeding.
