import React, { useEffect, useState } from 'react'
import {
  connect,
  isFirebaseConfigured,
  startHeartbeats,
  watchDevices,
} from '../services/firebase'
import DeviceCard from '../components/DeviceCard'

export default function Dashboard() {
  const [devices, setDevices] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!isFirebaseConfigured) {
      setLoading(false)
      return
    }

    let unsubDevices: (() => void) | undefined
    let stopBeats: (() => void) | undefined
    let cancelled = false

    // Sign in first. The security rules require an authenticated session, so a
    // listener attached before this returns nothing and reports
    // permission-denied -- which looks exactly like "there are no devices".
    connect()
      .then(() => {
        if (cancelled) return

        unsubDevices = watchDevices(
          (list) => {
            setDevices(list)
            setLoading(false)

            // Keep every appliance looking alive while this page is open, so
            // the worker's heartbeat watchdog can be enabled without the whole
            // house falling offline. Restarted only when the set of devices
            // actually changes, not on every snapshot -- otherwise the interval
            // is reset before it ever fires.
            const ids = list.map((d) => d.id)
            stopBeats?.()
            stopBeats = startHeartbeats(ids, 10000)
          },
          (err) => {
            setError(err.message)
            setLoading(false)
          }
        )
      })
      .catch((err: Error) => {
        setError(err.message)
        setLoading(false)
      })

    return () => {
      cancelled = true
      unsubDevices?.()
      stopBeats?.()
    }
  }, [])

  // Group devices by room for display.
  const byRoom = devices.reduce<Record<string, any[]>>((acc, d) => {
    const r = d.roomId || 'unassigned'
    acc[r] = acc[r] || []
    acc[r].push(d)
    return acc
  }, {})

  return (
    <div>
      {!isFirebaseConfigured && (
        <div className="mb-4 p-4 bg-yellow-100 text-yellow-900 rounded">
          Firebase not configured. Copy <code>.env.example</code> to{' '}
          <code>.env</code> and fill in the web config, then restart{' '}
          <code>npm run dev</code>.
        </div>
      )}

      {error && (
        <div className="mb-4 p-4 bg-red-100 text-red-900 rounded">
          {error}
          <div className="text-sm mt-1 opacity-80">
            A permission error usually means Anonymous sign-in is not enabled in
            the Firebase console.
          </div>
        </div>
      )}

      {loading && <div>Loading devices...</div>}

      {!loading && (
        <div>
          {Object.keys(byRoom).map((roomId) => (
            <section key={roomId} className="mb-6">
              <h3 className="mb-2 font-semibold">Room: {roomId}</h3>
              <div className="device-grid">
                {byRoom[roomId].map((d) => (
                  <DeviceCard key={d.id} device={d} />
                ))}
              </div>
            </section>
          ))}
        </div>
      )}

      {!loading && !error && devices.length === 0 && (
        <div className="p-4">
          No devices found. Run <code>npm run seed</code> in{' '}
          <code>worker/</code>.
        </div>
      )}
    </div>
  )
}
