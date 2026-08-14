import { initializeApp, FirebaseApp } from 'firebase/app'
import { getAuth, signInAnonymously } from 'firebase/auth'
import {
  getFirestore,
  collection,
  doc,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  updateDoc,
  where,
  Firestore,
  Unsubscribe,
} from 'firebase/firestore'

/**
 * The simulator's Firestore layer.
 *
 * No UI in here on purpose: the dashboard decides how an appliance looks, this
 * decides what it means to write one. Mirrors lib/services/firestore_service.dart
 * on the Flutter side -- the two clients share one database, so they have to
 * share one set of rules about how documents are maintained.
 *
 * Canonical schema: firebase/SCHEMA.md
 */

// Config comes from web-simulator/.env (see .env.example). Vite inlines
// anything prefixed VITE_ at build time. These keys are not secrets -- they
// identify the project, they do not grant access. What protects the data is
// firestore.rules plus an authenticated session.
const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
}

export const isFirebaseConfigured = Boolean(firebaseConfig.projectId)

export const COLLECTIONS = {
  floors: 'floors',
  rooms: 'rooms',
  devices: 'devices',
  usageLogs: 'usage_logs',
  alerts: 'alerts',
} as const

export const STATUS = {
  on: 'on',
  off: 'off',
  error: 'error',
  disconnected: 'disconnected',
} as const

export type DeviceStatus = (typeof STATUS)[keyof typeof STATUS]

const SOURCE = 'simulator'

let app: FirebaseApp | null = null
let db: Firestore | null = null

if (isFirebaseConfigured) {
  try {
    app = initializeApp(firebaseConfig)
    db = getFirestore(app)
  } catch (e) {
    console.error('[smart-nest] Firebase init failed', e)
    db = null
  }
}

/**
 * Sign in anonymously.
 *
 * Not optional: firestore.rules require `request.auth != null`, so a simulator
 * that skips this gets an empty device list and a permission-denied buried in
 * the console. Call it once before attaching any listener.
 */
export async function connect(): Promise<void> {
  if (!app || !db) {
    throw new Error(
      'Firebase is not configured. Copy .env.example to .env and fill it in.'
    )
  }
  const auth = getAuth(app)
  if (!auth.currentUser) {
    await signInAnonymously(auth)
  }
}

function deviceRef(deviceId: string) {
  if (!db) throw new Error('Firestore is not available')
  return doc(db, COLLECTIONS.devices, deviceId)
}

/** Stamped on every write, so the app and worker can tell our changes apart. */
function stamp(reason?: string) {
  return {
    updatedBy: SOURCE,
    lastUpdated: serverTimestamp(),
    ...(reason ? { statusReason: reason } : {}),
  }
}

// -------------------------------------------------------------------- reads

/**
 * Live device list. Returns an unsubscribe function.
 *
 * onSnapshot, not a polling loop: a toggle on the phone lands here in a few
 * hundred milliseconds, which is what makes the simulator look like real
 * hardware reacting rather than a page that refreshes.
 */
export function watchDevices(
  onData: (devices: any[]) => void,
  onError?: (err: Error) => void
): Unsubscribe {
  if (!db) throw new Error('Firestore is not available')
  const q = query(collection(db, COLLECTIONS.devices), orderBy('name'))
  return onSnapshot(
    q,
    (snap) => onData(snap.docs.map((d) => ({ id: d.id, ...d.data() }))),
    onError ?? ((err) => console.error('[smart-nest] devices:', err))
  )
}

export function watchRooms(
  onData: (rooms: any[]) => void,
  onError?: (err: Error) => void
): Unsubscribe {
  if (!db) throw new Error('Firestore is not available')
  return onSnapshot(
    collection(db, COLLECTIONS.rooms),
    (snap) => onData(snap.docs.map((d) => ({ id: d.id, ...d.data() }))),
    onError ?? ((err) => console.error('[smart-nest] rooms:', err))
  )
}

export function watchFloors(
  onData: (floors: any[]) => void,
  onError?: (err: Error) => void
): Unsubscribe {
  if (!db) throw new Error('Firestore is not available')
  const q = query(collection(db, COLLECTIONS.floors), orderBy('order'))
  return onSnapshot(
    q,
    (snap) => onData(snap.docs.map((d) => ({ id: d.id, ...d.data() }))),
    onError ?? ((err) => console.error('[smart-nest] floors:', err))
  )
}

// ------------------------------------------------------------------- writes

/**
 * Someone pressed the physical switch on the appliance.
 *
 * Runs in a transaction, and returns early when the device is already in the
 * requested state. Without that guard, pressing ON on a device that is already
 * ON rewrites `turnedOnAt` and hands a running iron a brand new safety budget --
 * the cutoff would then never fire, and nothing would look wrong until
 * something caught fire.
 */
export async function reportPower(deviceId: string, on: boolean): Promise<void> {
  if (!db) throw new Error('Firestore is not available')
  const ref = deviceRef(deviceId)

  await runTransaction(db, async (txn) => {
    const snap = await txn.get(ref)
    if (!snap.exists()) throw new Error(`No device ${deviceId}`)

    const device = snap.data()
    if (device.status === (on ? STATUS.on : STATUS.off)) return

    const update: Record<string, unknown> = {
      status: on ? STATUS.on : STATUS.off,
      // A server timestamp: the safety countdown must not depend on the
      // browser's clock, which the person running the demo can change.
      turnedOnAt: on ? serverTimestamp() : null,
      ...stamp('manual'),
    }

    if (Array.isArray(device.childSwitches) && device.childSwitches.length) {
      update.childSwitches = device.childSwitches.map((c: any) => ({
        ...c,
        isOn: on,
      }))
    }

    txn.update(ref, update)
  })
}

/**
 * One child switch of a gang box.
 *
 * A transaction, because Firestore cannot update a single array element:
 * without it, two switches flipped at the same moment would each write back a
 * copy of the array that discards the other, and one change would vanish with
 * nothing to show it happened.
 */
export async function reportChildSwitch(
  deviceId: string,
  switchId: string,
  isOn: boolean
): Promise<void> {
  if (!db) throw new Error('Firestore is not available')
  const ref = deviceRef(deviceId)

  await runTransaction(db, async (txn) => {
    const snap = await txn.get(ref)
    if (!snap.exists()) throw new Error(`No device ${deviceId}`)

    const device = snap.data()
    const children = (device.childSwitches ?? []) as any[]
    if (!children.length) throw new Error(`${deviceId} has no child switches`)

    const next = children.map((c) => (c.id === switchId ? { ...c, isOn } : c))
    const anyOn = next.some((c) => c.isOn)
    const wasOn = device.status === STATUS.on

    const update: Record<string, unknown> = {
      childSwitches: next,
      status: anyOn ? STATUS.on : STATUS.off,
      ...stamp('manual'),
    }

    // Only a genuine OFF -> ON edge restarts the safety clock.
    if (anyOn && !wasOn) update.turnedOnAt = serverTimestamp()
    if (!anyOn) update.turnedOnAt = null

    txn.update(ref, update)
  })
}

/** The appliance has failed. The worker turns this into an alert. */
export async function reportFault(
  deviceId: string,
  message = 'simulated fault'
): Promise<void> {
  await updateDoc(deviceRef(deviceId), {
    status: STATUS.error,
    turnedOnAt: null,
    ...stamp(`simulator_fault: ${message}`),
  })
}

/** The appliance stopped answering. */
export async function reportDisconnected(deviceId: string): Promise<void> {
  await updateDoc(deviceRef(deviceId), {
    status: STATUS.disconnected,
    turnedOnAt: null,
    ...stamp('simulator_disconnect'),
  })
}

/**
 * Recover from a fault or a disconnect.
 *
 * Comes back OFF rather than to whatever it was doing before: nobody knows what
 * the appliance did while it was unreachable, and ON is the dangerous guess.
 */
export async function clearFault(deviceId: string): Promise<void> {
  await updateDoc(deviceRef(deviceId), {
    status: STATUS.off,
    turnedOnAt: null,
    lastHeartbeat: serverTimestamp(),
    ...stamp('recovered'),
  })
}

/** Rotate a camera's mock snapshots so the app shows a new frame. */
export async function nextCameraFrame(
  deviceId: string,
  urls: string[]
): Promise<void> {
  if (!urls || urls.length < 2) {
    await updateDoc(deviceRef(deviceId), { ...stamp() })
    return
  }
  const rotated = [...urls.slice(1), urls[0]]
  await updateDoc(deviceRef(deviceId), {
    cameraImageUrls: rotated,
    ...stamp(),
  })
}

/**
 * "I am still here."
 *
 * The worker's watchdog flips a device to DISCONNECTED when these stop. Note it
 * writes only `lastHeartbeat` -- stamping `updatedBy` on every beat would make
 * the app's "last changed by" useless, showing `simulator` every ten seconds no
 * matter who actually touched the device.
 */
export async function heartbeat(deviceId: string): Promise<void> {
  await updateDoc(deviceRef(deviceId), { lastHeartbeat: serverTimestamp() })
}

/**
 * Beat for a set of devices on an interval. Returns a stop function.
 * Ten seconds against a 30-second timeout leaves room for two missed beats.
 */
export function startHeartbeats(deviceIds: string[], intervalMs = 10000) {
  const beat = () => {
    deviceIds.forEach((id) =>
      heartbeat(id).catch((err) =>
        console.error(`[smart-nest] heartbeat ${id}:`, err)
      )
    )
  }
  beat()
  const handle = setInterval(beat, intervalMs)
  return () => clearInterval(handle)
}

export { db, collection, onSnapshot, query, where, doc, updateDoc, serverTimestamp }
