import React from 'react'
import { db, doc, updateDoc, serverTimestamp } from '../services/firebase'

function statusColor(status: string | undefined) {
  switch (status) {
    case 'on': return 'bg-green-100 text-green-800'
    case 'off': return 'bg-gray-100 text-gray-700'
    case 'error': return 'bg-red-100 text-red-800'
    case 'disconnected': return 'bg-amber-100 text-amber-800'
    default: return 'bg-gray-100 text-gray-700'
  }
}

export default function DeviceCard({ device }: { device: any }) {
  const toggle = async () => {
    if (!db) return
    const dref = doc(db, 'devices', device.id)
    const newStatus = device.status === 'on' ? 'off' : 'on'
    try {
      await updateDoc(dref, {
        status: newStatus,
        updatedBy: 'simulator',
        lastUpdated: serverTimestamp(),
        ...(newStatus === 'on' ? { turnedOnAt: serverTimestamp() } : { turnedOnAt: null })
      })
    } catch (e) {
      console.error('toggle failed', e)
    }
  }

  const simulate = async (s: string) => {
    if (!db) return
    const dref = doc(db, 'devices', device.id)
    try {
      await updateDoc(dref, { status: s, updatedBy: 'simulator', lastUpdated: serverTimestamp() })
    } catch (e) {
      console.error('simulate failed', e)
    }
  }

  return (
    <div className="card">
      <div className="flex items-start justify-between">
        <div>
          <div className="font-semibold">{device.name || device.id}</div>
          <div className="text-sm text-slate-500">{device.type} • {device.roomId || 'room'}</div>
        </div>
        <div className={`status-badge ${statusColor(device.status)}`}>{device.status}</div>
      </div>

      <div className="mt-3">
        {/* type-specific quick view */}
        {device.type === 'multiSwitch' && device.childSwitches && (
          <div className="text-sm mb-2">Child switches: {device.childSwitches.map((c:any)=>c.label).join(', ')}</div>
        )}
        {device.type === 'scheduledAppliance' && (
          <div className="text-sm mb-2">Max: {device.maxOnDurationMinutes ?? '—'} min</div>
        )}
        {device.type === 'scheduledLight' && (
          <div className="text-sm mb-2">Schedule: {device.scheduleStartTime ?? '—'} → {device.scheduleEndTime ?? '—'}</div>
        )}
        {device.type === 'camera' && device.cameraImageUrls && (
          <div className="mb-2">
            <img src={device.cameraImageUrls[0]} alt="cam" className="w-full rounded mb-2" />
            <div className="flex gap-2">
              <button onClick={async ()=>{
                if (!db) return
                const dref = doc(db, 'devices', device.id)
                try {
                  // rotate cameraImageUrls so the next image appears first
                  const arr = Array.isArray(device.cameraImageUrls) ? [...device.cameraImageUrls] : []
                  if (arr.length > 1) {
                    const first = arr.shift()
                    arr.push(first)
                    await updateDoc(dref, { cameraImageUrls: arr, updatedBy: 'simulator', lastUpdated: serverTimestamp() })
                  } else {
                    // if only one image, re-write timestamp so mobile shows new snapshot
                    await updateDoc(dref, { updatedBy: 'simulator', lastUpdated: serverTimestamp() })
                  }
                } catch (e) {
                  console.error('snapshot failed', e)
                }
              }} className="px-3 py-1 rounded bg-indigo-500 text-white">New Snapshot</button>
            </div>
          </div>
        )}

        {device.lastAlert && (
          <div className="p-2 rounded bg-red-50 text-red-700 text-sm mb-2">Alert: {device.lastAlert}</div>
        )}

        <div className="flex gap-2">
          <button onClick={toggle} className="px-3 py-1 rounded bg-indigo-600 text-white">Toggle</button>
          <button onClick={()=>simulate('error')} className="px-3 py-1 rounded bg-red-500 text-white">Simulate Error</button>
          <button onClick={()=>simulate('disconnected')} className="px-3 py-1 rounded bg-amber-500 text-white">Simulate Disconnect</button>
          <button onClick={()=>simulate('off')} className="px-3 py-1 rounded bg-gray-300">Simulate Reconnect(off)</button>
        </div>
      </div>
    </div>
  )
}
