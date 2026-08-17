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

function stamp(reason?: string) {
  return {
    updatedBy: SOURCE,
    lastUpdated: serverTimestamp(),
    ...(reason ? { statusReason: reason } : {}),
  }
}

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

export async function reportPower(
  deviceId: string,
  on: boolean
): Promise<void> {
  if (!db) {
    throw new Error('Firestore is not available')
  }

  const ref = deviceRef(deviceId)

  console.log(
    `[Smart Nest] Updating ${deviceId} -> ${on ? 'ON' : 'OFF'}`
  )

  await updateDoc(ref, {
    status: on ? STATUS.on : STATUS.off,
    turnedOnAt: on ? serverTimestamp() : null,
    updatedBy: SOURCE,
    statusReason: 'manual',
    lastUpdated: serverTimestamp(),
  })

  console.log(
    `[Smart Nest] Successfully updated ${deviceId} -> ${on ? 'ON' : 'OFF'}`
  )
}

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

    if (anyOn && !wasOn) update.turnedOnAt = serverTimestamp()
    if (!anyOn) update.turnedOnAt = null

    txn.update(ref, update)
  })
}

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

export async function reportDisconnected(deviceId: string): Promise<void> {
  await updateDoc(deviceRef(deviceId), {
    status: STATUS.disconnected,
    turnedOnAt: null,
    ...stamp('simulator_disconnect'),
  })
}

export async function clearFault(deviceId: string): Promise<void> {
  await updateDoc(deviceRef(deviceId), {
    status: STATUS.off,
    turnedOnAt: null,
    lastHeartbeat: serverTimestamp(),
    ...stamp('recovered'),
  })
}

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


export async function heartbeat(deviceId: string): Promise<void> {
  await updateDoc(deviceRef(deviceId), { lastHeartbeat: serverTimestamp() })
}

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
