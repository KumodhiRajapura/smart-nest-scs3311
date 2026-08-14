/**
 * Smart Nest -- Firestore client for the Hardware Simulator.
 *
 * This module is the simulator's half of the sync contract. It has no UI in it
 * on purpose: drop it into whatever dashboard you are building, call
 * `connectSmartNest()` once, and drive your visuals from the callbacks.
 *
 * Mirrors lib/services/device_repository.dart. The two clients maintain the
 * same fields in the same way -- especially `turnedOnAt`, which the safety
 * worker reads to decide when an appliance has been on too long. A write that
 * forgets it would disarm the cutoff.
 *
 * Usage:
 *
 *   import { connectSmartNest } from './smart-nest-firestore.js';
 *   const nest = await connectSmartNest(firebaseConfig);
 *   nest.watchDevices(devices => render(devices));
 *   nest.reportPower('dev_porch_light', true);   // physical switch pressed
 */

import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.12.5/firebase-app.js';
import {
  getAuth,
  signInAnonymously,
} from 'https://www.gstatic.com/firebasejs/10.12.5/firebase-auth.js';
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
} from 'https://www.gstatic.com/firebasejs/10.12.5/firebase-firestore.js';

export const COLLECTIONS = {
  floors: 'floors',
  devices: 'devices',
  schedules: 'schedules',
  usageLogs: 'usage_logs',
  alerts: 'alerts',
};

export const STATUS = {
  on: 'ON',
  off: 'OFF',
  error: 'ERROR',
  disconnected: 'DISCONNECTED',
};

const SOURCE = 'simulator';

/**
 * Connect, sign in and return the simulator API.
 *
 * Anonymous sign-in is required: the security rules reject unauthenticated
 * reads, so a simulator that skips this gets an empty list and no error that
 * points at the cause.
 */
export async function connectSmartNest(firebaseConfig) {
  const app = initializeApp(firebaseConfig);
  const db = getFirestore(app);
  const auth = getAuth(app);

  await signInAnonymously(auth);

  const deviceRef = (id) => doc(db, COLLECTIONS.devices, id);

  /** Stamped on every write so the app and worker can spot our echo. */
  const meta = (reason) => ({
    updatedBy: SOURCE,
    updatedAt: serverTimestamp(),
    ...(reason ? { statusReason: reason } : {}),
  });

  return {
    app,
    db,
    auth,

    // ------------------------------------------------------------- reads

    /**
     * Live device list. Returns an unsubscribe function.
     *
     * onSnapshot, not a fetch loop: a toggle on the phone lands here in a few
     * hundred milliseconds, which is what makes the simulator look like real
     * hardware reacting.
     */
    watchDevices(callback, onError) {
      const q = query(collection(db, COLLECTIONS.devices), orderBy('name'));
      return onSnapshot(
        q,
        (snap) => {
          callback(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
        },
        onError || ((err) => console.error('[smart-nest] devices:', err))
      );
    },

    watchFloors(callback, onError) {
      const q = query(collection(db, COLLECTIONS.floors), orderBy('level'));
      return onSnapshot(
        q,
        (snap) => callback(snap.docs.map((d) => ({ id: d.id, ...d.data() }))),
        onError || ((err) => console.error('[smart-nest] floors:', err))
      );
    },

    // ------------------------------------------------------------ writes

    /**
     * Someone pressed the physical switch on the appliance.
     *
     * `turnedOnAt` uses a server timestamp so the safety countdown does not
     * depend on the browser's clock.
     */
    async reportPower(deviceId, on) {
      await updateDoc(deviceRef(deviceId), {
        status: on ? STATUS.on : STATUS.off,
        turnedOnAt: on ? serverTimestamp() : null,
        ...meta('manual'),
      });
    },

    /**
     * One switch of a gang box.
     *
     * A transaction, because Firestore cannot update a single array element:
     * without it, two switches flipped at once would each write back a copy of
     * the array that discards the other.
     */
    async reportChannel(deviceId, channelIndex, isOn) {
      await runTransaction(db, async (txn) => {
        const ref = deviceRef(deviceId);
        const snap = await txn.get(ref);
        if (!snap.exists()) throw new Error(`No device ${deviceId}`);

        const device = snap.data();
        const channels = (device.channels || []).map((c) =>
          Number(c.index) === Number(channelIndex) ? { ...c, isOn } : c
        );

        const anyOn = channels.some((c) => c.isOn);
        const wasOn = device.status === STATUS.on;

        txn.update(ref, {
          channels,
          status: anyOn ? STATUS.on : STATUS.off,
          // Only a real OFF -> ON edge restarts the safety clock.
          ...(anyOn && !wasOn ? { turnedOnAt: serverTimestamp() } : {}),
          ...(anyOn ? {} : { turnedOnAt: null }),
          ...meta('manual'),
        });
      });
    },

    /** The appliance has failed. The worker turns this into an alert. */
    async reportFault(deviceId, message = 'simulated fault') {
      await updateDoc(deviceRef(deviceId), {
        status: STATUS.error,
        turnedOnAt: null,
        ...meta(`simulator_fault: ${message}`),
      });
    },

    /** Recover from a fault. */
    async clearFault(deviceId) {
      await updateDoc(deviceRef(deviceId), {
        status: STATUS.off,
        turnedOnAt: null,
        ...meta('recovered'),
      });
    },

    /**
     * "I am still here."
     *
     * The worker's watchdog flips a device to DISCONNECTED when these stop.
     * Note this writes only `lastHeartbeat` -- stamping `updatedBy` on every
     * beat would make the app's "last changed by" field useless.
     */
    async heartbeat(deviceId) {
      await updateDoc(deviceRef(deviceId), {
        lastHeartbeat: serverTimestamp(),
      });
    },

    /**
     * Beat for a set of devices on an interval. Returns a stop function.
     * Ten seconds against a 30-second timeout leaves room for two misses.
     */
    startHeartbeats(deviceIds, intervalMs = 10000) {
      const beat = () => {
        deviceIds.forEach((id) =>
          this.heartbeat(id).catch((err) =>
            console.error(`[smart-nest] heartbeat ${id}:`, err)
          )
        );
      };
      beat();
      const handle = setInterval(beat, intervalMs);
      return () => clearInterval(handle);
    },
  };
}
