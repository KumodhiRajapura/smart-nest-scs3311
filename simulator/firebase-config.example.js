// Copy to simulator/firebase-config.js and paste your project's web config.
//
// Firebase console -> Project settings -> General -> Your apps -> Web app
// (the same values flutterfire wrote into lib/firebase_options.dart under
// `static const FirebaseOptions web`).
//
// These keys are not secrets -- they identify the project, they do not grant
// access. What protects the data is firestore.rules plus anonymous auth.

export const firebaseConfig = {
  apiKey: 'REPLACE_ME',
  authDomain: 'REPLACE_ME.firebaseapp.com',
  projectId: 'REPLACE_ME',
  storageBucket: 'REPLACE_ME.appspot.com',
  messagingSenderId: 'REPLACE_ME',
  appId: 'REPLACE_ME',
};
