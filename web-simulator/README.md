Web Hardware Simulator — Smart Nest (Member 3)

Quick start
-----------
1. Install dependencies
   cd web-simulator
   npm install

2. Add Firebase web config
   - Open src/services/firebase.ts and paste your Firebase web app config (from Firebase Console → Project settings → Web app).
   - Example keys: apiKey, authDomain, projectId, storageBucket, messagingSenderId, appId

3. Run locally
   npm run dev
   Open http://localhost:5173

What this simulator does
------------------------
- Subscribes to the `devices` collection and displays all devices grouped by room.
- Allows toggling device status (on/off) and simulating error/disconnect via buttons.
- When writing to Firestore, the simulator sets updatedBy: 'simulator' and lastUpdated: serverTimestamp().
- Camera devices: provide cameraImageUrls (array of strings) in device docs; simulator shows the first image.

Notes for Member 2 (backend)
---------------------------
- The simulator writes only allowed fields (status, childSwitches, turnedOnAt, scheduleStartTime/EndTime, updatedBy, lastUpdated). It DOES NOT write lastAlert or lastAlertAt.
- For testing scheduled lights / safety cutoffs, use the seed script and/or set turnedOnAt to a past timestamp.

Notes for Member 1 (mobile)
---------------------------
- The simulator will write simulator-originated changes to the same Firestore project the mobile app connects to. Mobile should reflect those writes automatically via its live streams.

Files of interest
-----------------
- src/pages/Dashboard.tsx — main dashboard and listeners
- src/components/DeviceCard.tsx — device card UI + write helpers
- src/services/firebase.ts — modular Firebase SDK init (paste web config here)

Security
--------
- Do not commit Firebase config with secrets to git if it includes private keys. The web config is typically safe (apiKey) but do not commit service account or admin credentials.

If you want me to: I can add Tailwind config and a few example mock images in public/mock-cameras, or create an example .env with placeholders for the firebase config. Which would you prefer?