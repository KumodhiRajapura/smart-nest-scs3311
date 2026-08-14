import React, { useEffect, useState } from 'react'
import { db, collection, onSnapshot } from '../services/firebase'
import DeviceCard from '../components/DeviceCard'

export default function Dashboard() {
  const [devices, setDevices] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!db) {
      setLoading(false)
      return
    }

    // Listen to all devices (single page grouped by room)
    const devicesRef = collection(db, 'devices')
    const unsub = onSnapshot(devicesRef, (snap) => {
      const ds: any[] = []
      snap.forEach((d) => ds.push({ id: d.id, ...d.data() }))
      setDevices(ds)
      setLoading(false)
    }, (err) => {
      console.error('devices snapshot error', err)
      setLoading(false)
    })

    return () => unsub()
  }, [])

  // Group devices by room for display
  const byRoom = devices.reduce<Record<string, any[]>>((acc, d) => {
    const r = d.roomId || 'unassigned'
    acc[r] = acc[r] || []
    acc[r].push(d)
    return acc
  }, {})

  return (
    <div>
      {!db && (
        <div className="mb-4 p-4 bg-yellow-100 text-yellow-900 rounded">Firebase not configured. Paste your web config into <code>src/services/firebase.ts</code>.</div>
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

      {!loading && devices.length === 0 && <div className="p-4">No devices found.</div>}
    </div>
  )
}
