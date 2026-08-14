import { initializeApp } from 'firebase/app'
import { getFirestore, collection, onSnapshot, query, where, doc, updateDoc, serverTimestamp } from 'firebase/firestore'

// Paste your Firebase web config object here (get it from Firebase Console -> Project settings -> Web app)
// Example:
// const firebaseConfig = {
//   apiKey: "...",
//   authDomain: "...",
//   projectId: "...",
//   storageBucket: "...",
//   messagingSenderId: "...",
//   appId: "..."
// }

const firebaseConfig = {
  // TODO: REPLACE WITH YOUR WEB APP CONFIG
}

export const isFirebaseConfigured = Boolean(firebaseConfig && firebaseConfig.projectId)

let db: ReturnType<typeof getFirestore> | null = null
if (isFirebaseConfigured) {
  try {
    const app = initializeApp(firebaseConfig)
    db = getFirestore(app)
  } catch (e) {
    console.error('Firebase init failed', e)
    db = null
  }
}

export { db, collection, onSnapshot, query, where, doc, updateDoc, serverTimestamp }
