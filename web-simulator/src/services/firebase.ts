import { initializeApp, FirebaseApp } from 'firebase/app'
import {
  getAuth,
  signInAnonymously,
  Auth,
} from 'firebase/auth'

import {
  initializeFirestore,
  collection,
  doc,
  onSnapshot,
  orderBy,
  query,
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

export const isFirebaseConfigured = Boolean(
  firebaseConfig.projectId &&
  firebaseConfig.apiKey
)

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

export type DeviceStatus =
  (typeof STATUS)[keyof typeof STATUS]

const SOURCE = 'simulator'

let app: FirebaseApp | null = null
let db: Firestore | null = null
let auth: Auth | null = null

if (isFirebaseConfigured) {
  try {
    app = initializeApp(firebaseConfig)

    auth = getAuth(app)

    // More reliable in browsers/networks where the normal
    // Firestore streaming transport gets stuck.
    db = initializeFirestore(app, {
      experimentalForceLongPolling: true,
    })
  } catch (e) {
    console.error(
      '[smart-nest] Firebase init failed',
      e
    )

    app = null
    db = null
    auth = null
  }
}

/* =========================================================
   AUTHENTICATION
   ========================================================= */

export async function connect(): Promise<void> {
  if (!app || !db || !auth) {
    throw new Error(
      'Firebase is not configured. Check web-simulator/.env'
    )
  }

  if (!auth.currentUser) {
    await signInAnonymously(auth)
  }

  console.log(
    '[Smart Nest] Firebase authenticated:',
    auth.currentUser?.uid
  )
}

/* =========================================================
   FIRESTORE REFERENCES
   ========================================================= */

function deviceRef(deviceId: string) {
  if (!db) {
    throw new Error('Firestore is not available')
  }

  return doc(
    db,
    COLLECTIONS.devices,
    deviceId
  )
}

/* =========================================================
   FIRESTORE LISTENERS
   ========================================================= */

export function watchDevices(
  onData: (devices: any[]) => void,
  onError?: (err: Error) => void
): Unsubscribe {
  if (!db) {
    throw new Error('Firestore is not available')
  }

  const q = query(
    collection(db, COLLECTIONS.devices),
    orderBy('name')
  )

  return onSnapshot(
    q,
    (snap) => {
      const devices = snap.docs.map((d) => ({
        id: d.id,
        ...d.data(),
      }))

      onData(devices)
    },
    onError ??
      ((err) =>
        console.error(
          '[smart-nest] devices:',
          err
        ))
  )
}

export function watchRooms(
  onData: (rooms: any[]) => void,
  onError?: (err: Error) => void
): Unsubscribe {
  if (!db) {
    throw new Error('Firestore is not available')
  }

  return onSnapshot(
    collection(db, COLLECTIONS.rooms),
    (snap) => {
      onData(
        snap.docs.map((d) => ({
          id: d.id,
          ...d.data(),
        }))
      )
    },
    onError ??
      ((err) =>
        console.error(
          '[smart-nest] rooms:',
          err
        ))
  )
}

export function watchFloors(
  onData: (floors: any[]) => void,
  onError?: (err: Error) => void
): Unsubscribe {
  if (!db) {
    throw new Error('Firestore is not available')
  }

  const q = query(
    collection(db, COLLECTIONS.floors),
    orderBy('order')
  )

  return onSnapshot(
    q,
    (snap) => {
      onData(
        snap.docs.map((d) => ({
          id: d.id,
          ...d.data(),
        }))
      )
    },
    onError ??
      ((err) =>
        console.error(
          '[smart-nest] floors:',
          err
        ))
  )
}

/* =========================================================
   FIRESTORE REST WRITE
   ========================================================= */

function firestoreValue(value: any): any {
  if (value === null) {
    return {
      nullValue: null,
    }
  }

  if (typeof value === 'boolean') {
    return {
      booleanValue: value,
    }
  }

  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? {
          integerValue: String(value),
        }
      : {
          doubleValue: value,
        }
  }

  if (typeof value === 'string') {
    return {
      stringValue: value,
    }
  }

  if (value instanceof Date) {
    return {
      timestampValue: value.toISOString(),
    }
  }

  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map(
          firestoreValue
        ),
      },
    }
  }

  if (typeof value === 'object') {
    const fields: Record<string, any> = {}

    for (const [key, val] of Object.entries(
      value
    )) {
      fields[key] = firestoreValue(val)
    }

    return {
      mapValue: {
        fields,
      },
    }
  }

  return {
    nullValue: null,
  }
}

async function restUpdateDevice(
  deviceId: string,
  data: Record<string, any>
): Promise<void> {
  if (!auth) {
    throw new Error(
      'Firebase authentication is not available'
    )
  }

  if (!auth.currentUser) {
    await connect()
  }

  const user = auth.currentUser

  if (!user) {
    throw new Error(
      'Simulator is not authenticated'
    )
  }

  const token = await user.getIdToken()

  const projectId =
    firebaseConfig.projectId

  const encodedId =
    encodeURIComponent(deviceId)

  const url =
    `https://firestore.googleapis.com/v1/` +
    `projects/${projectId}/databases/(default)/documents/` +
    `devices/${encodedId}`

  const fields: Record<string, any> = {}

  for (const [key, value] of Object.entries(
    data
  )) {
    fields[key] = firestoreValue(value)
  }

  const updateMask = Object.keys(data)
    .map(
      (field) =>
        `updateMask.fieldPaths=${encodeURIComponent(
          field
        )}`
    )
    .join('&')

  console.log(
    '[Smart Nest] REST update:',
    deviceId,
    data
  )

  const response = await fetch(
    `${url}?${updateMask}`,
    {
      method: 'PATCH',
      headers: {
        Authorization:
          `Bearer ${token}`,
        'Content-Type':
          'application/json',
      },
      body: JSON.stringify({
        fields,
      }),
    }
  )

  if (!response.ok) {
    const text =
      await response.text()

    console.error(
      '[Smart Nest] Firestore REST error:',
      response.status,
      text
    )

    throw new Error(
      `Firestore write failed (${response.status}): ${text}`
    )
  }

  console.log(
    '[Smart Nest] REST write successful:',
    deviceId
  )
}

/* =========================================================
   DEVICE POWER
   ========================================================= */

export async function reportPower(
  deviceId: string,
  on: boolean
): Promise<void> {
  const now =
    new Date().toISOString()

  console.log(
    `[Smart Nest] Updating ${deviceId} -> ${
      on ? 'ON' : 'OFF'
    }`
  )

  await restUpdateDevice(
    deviceId,
    {
      status: on
        ? STATUS.on
        : STATUS.off,

      turnedOnAt: on
        ? now
        : null,

      updatedBy: SOURCE,

      statusReason: 'manual',

      lastUpdated: now,
    }
  )

  console.log(
    `[Smart Nest] Successfully updated ${deviceId} -> ${
      on ? 'ON' : 'OFF'
    }`
  )
}

/* =========================================================
   MULTI-SWITCH
   ========================================================= */

export async function reportChildSwitch(
  deviceId: string,
  switchId: string,
  isOn: boolean
): Promise<void> {
  if (!db) {
    throw new Error(
      'Firestore is not available'
    )
  }

  const ref =
    deviceRef(deviceId)

  const snapshot =
    await new Promise<any>(
      (resolve, reject) => {
        const unsubscribe =
          onSnapshot(
            ref,
            (snap) => {
              unsubscribe()
              resolve(snap)
            },
            (err) => {
              unsubscribe()
              reject(err)
            }
          )
      }
    )

  if (!snapshot.exists()) {
    throw new Error(
      `No device ${deviceId}`
    )
  }

  const device =
    snapshot.data()

  const children =
    Array.isArray(
      device.childSwitches
    )
      ? device.childSwitches
      : []

  if (!children.length) {
    throw new Error(
      `${deviceId} has no child switches`
    )
  }

  const next =
    children.map((child: any) =>
      child.id === switchId
        ? {
            ...child,
            isOn,
          }
        : child
    )

  const anyOn =
    next.some(
      (child: any) =>
        child.isOn
    )

  const now =
    new Date().toISOString()

  await restUpdateDevice(
    deviceId,
    {
      childSwitches: next,

      status: anyOn
        ? STATUS.on
        : STATUS.off,

      turnedOnAt: anyOn
        ? now
        : null,

      updatedBy: SOURCE,

      statusReason: 'manual',

      lastUpdated: now,
    }
  )
}

/* =========================================================
   ERROR
   ========================================================= */

export async function reportFault(
  deviceId: string,
  message = 'simulated fault'
): Promise<void> {
  await restUpdateDevice(
    deviceId,
    {
      status: STATUS.error,
      turnedOnAt: null,
      updatedBy: SOURCE,
      statusReason:
        `simulator_fault: ${message}`,
      lastUpdated:
        new Date().toISOString(),
    }
  )
}

/* =========================================================
   DISCONNECT
   ========================================================= */

export async function reportDisconnected(
  deviceId: string
): Promise<void> {
  await restUpdateDevice(
    deviceId,
    {
      status:
        STATUS.disconnected,
      turnedOnAt: null,
      updatedBy: SOURCE,
      statusReason:
        'simulator_disconnect',
      lastUpdated:
        new Date().toISOString(),
    }
  )
}

/* =========================================================
   RECOVER
   ========================================================= */

export async function clearFault(
  deviceId: string
): Promise<void> {
  await restUpdateDevice(
    deviceId,
    {
      status: STATUS.off,
      turnedOnAt: null,
      lastHeartbeat:
        new Date().toISOString(),
      updatedBy: SOURCE,
      statusReason: 'recovered',
      lastUpdated:
        new Date().toISOString(),
    }
  )
}

/* =========================================================
   CAMERA
   ========================================================= */

export async function nextCameraFrame(
  deviceId: string,
  urls: string[]
): Promise<void> {
  if (
    !urls ||
    urls.length < 2
  ) {
    await restUpdateDevice(
      deviceId,
      {
        updatedBy: SOURCE,
        lastUpdated:
          new Date().toISOString(),
      }
    )

    return
  }

  const rotated = [
    ...urls.slice(1),
    urls[0],
  ]

  await restUpdateDevice(
    deviceId,
    {
      cameraImageUrls:
        rotated,

      updatedBy: SOURCE,

      lastUpdated:
        new Date().toISOString(),
    }
  )
}

/* =========================================================
   HEARTBEAT
   ========================================================= */

export function startHeartbeats(
  deviceIds: string[],
  intervalMs = 10000
) {
  // Heartbeats disabled for the web simulator.
  // The backend worker is responsible for device monitoring.
  console.log(
    '[Smart Nest] Simulator heartbeats disabled'
  )

  return () => {
    // Nothing to clean up.
  }
}