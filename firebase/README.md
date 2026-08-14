Firebase folder — setup & deploy

This folder contains the recommended Firestore schema, security rules, indexes, and Cloud Functions skeleton for the Smart Nest (SCS3311) project.

Files:
- SCHEMA.md                Canonical schema to be agreed by all team members.
- firestore.rules          Current repo rules (owner-scoped). See firestore.rules.recommended for the backend-recommended rules that allow open reads and restrict writes to backend/admin where required.
- firestore.rules.recommended  Backend-recommended rules (use Admin SDK for backend writes to alerts/usage_logs).
- FCM_INTEGRATION.md       FCM contract for the mobile app.
- SIMULATOR_INTEGRATION.md Integration notes for the web simulator.
- functions/               Cloud Functions (TypeScript) skeleton — deploy with `firebase deploy --only functions` after installing dependencies.

Quick start
-----------
1. Install Firebase CLI: https://firebase.google.com/docs/cli
   firebase login
   firebase init firestore,functions

2. To deploy rules & functions (after review):
   firebase deploy --only firestore:rules,functions

3. When using admin-only writes (alerts/usage_logs), Cloud Functions must use the Admin SDK (functions use admin.initializeApp()).

Notes on current repo state
---------------------------
- The repo currently contains an existing firestore.rules file that scopes reads/writes by ownerId. The recommended rules in firestore.rules.recommended are tailored for the project backend approach and must be agreed with the team before replacing the existing rules.
- Keep secrets out of git (do not commit service-account.json). Use Firebase CLI auth or CI secrets when deploying.
