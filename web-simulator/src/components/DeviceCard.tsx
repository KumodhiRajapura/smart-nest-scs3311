import React, { useState } from 'react'
import {
  STATUS,
  clearFault,
  nextCameraFrame,
  reportChildSwitch,
  reportDisconnected,
  reportFault,
  reportPower,
} from '../services/firebase'

/**
 * One appliance.
 *
 * Every button writes to Firestore and then does nothing else -- the card
 * repaints when the snapshot comes back. Painting optimistically would let the
 * simulator show a state the database never accepted, and the whole point of a
 * hardware simulator is that it shows what the database says.
 */

function statusColor(status: string | undefined) {
  switch (status) {
    case STATUS.on:
      return 'bg-green-100 text-green-800'
    case STATUS.off:
      return 'bg-gray-100 text-gray-700'
    case STATUS.error:
      return 'bg-red-100 text-red-800'
    case STATUS.disconnected:
      return 'bg-amber-100 text-amber-800'
    default:
      return 'bg-gray-100 text-gray-700'
  }
}

export default function DeviceCard({ device }: { device: any }) {
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Every write goes through here so a rejected one is visible on the card
  // instead of only in the console.
  const run = async (action: () => Promise<void>) => {
    setBusy(true)
    setError(null)
    try {
      await action()
    } catch (e: any) {
      setError(e?.message ?? String(e))
    } finally {
      setBusy(false)
    }
  }

  const isOn = device.status === STATUS.on
  const isFaulted =
    device.status === STATUS.error || device.status === STATUS.disconnected

  return (
    <div className="card">
      <div className="flex items-start justify-between">
        <div>
          <div className="font-semibold">{device.name || device.id}</div>
          <div className="text-sm text-slate-500">
            {device.type} • {device.roomId || 'room'}
          </div>
        </div>
        <div className={`status-badge ${statusColor(device.status)}`}>
          {String(device.status ?? 'unknown').toUpperCase()}
        </div>
      </div>

      <div className="mt-3">
        {device.type === 'multiSwitch' && Array.isArray(device.childSwitches) && (
          <div className="mb-2 space-y-1">
            {device.childSwitches.map((child: any) => (
              <div key={child.id} className="flex items-center gap-2 text-sm">
                <span
                  className={`inline-block w-2 h-2 rounded-full ${
                    child.isOn ? 'bg-green-500' : 'bg-gray-400'
                  }`}
                />
                <span className="flex-1">{child.label}</span>
                <button
                  disabled={busy || isFaulted}
                  onClick={() =>
                    run(() =>
                      reportChildSwitch(device.id, child.id, !child.isOn)
                    )
                  }
                  className="px-2 py-0.5 rounded bg-slate-200 disabled:opacity-50"
                >
                  {child.isOn ? 'off' : 'on'}
                </button>
              </div>
            ))}
          </div>
        )}

        {device.type === 'scheduledAppliance' && (
          <div className="text-sm mb-2">
            Max ON: {device.maxOnDurationMinutes ?? '—'} min
            {isOn && device.turnedOnAt && (
              <span className="ml-2 text-amber-700">
                running since{' '}
                {device.turnedOnAt.toDate?.().toTimeString().slice(0, 8)}
              </span>
            )}
          </div>
        )}

        {device.type === 'scheduledLight' && (
          <div className="text-sm mb-2">
            Schedule: {device.scheduleStartTime ?? '—'} →{' '}
            {device.scheduleEndTime ?? '—'}
          </div>
        )}

        {device.type === 'camera' && Array.isArray(device.cameraImageUrls) && (
          <div className="mb-2">
            <img
              src={device.cameraImageUrls[0]}
              alt="camera snapshot"
              className="w-full rounded mb-2"
            />
            <button
              disabled={busy}
              onClick={() =>
                run(() => nextCameraFrame(device.id, device.cameraImageUrls))
              }
              className="px-3 py-1 rounded bg-indigo-500 text-white disabled:opacity-50"
            >
              New Snapshot
            </button>
          </div>
        )}

        {device.lastAlert && (
          <div className="p-2 rounded bg-red-50 text-red-700 text-sm mb-2">
            Alert: {device.lastAlert}
          </div>
        )}

        {device.statusReason === 'safety_cutoff' && (
          <div className="p-2 rounded bg-amber-50 text-amber-800 text-sm mb-2">
            Switched off by the safety worker
          </div>
        )}

        {error && (
          <div className="p-2 rounded bg-red-50 text-red-700 text-sm mb-2">
            {error}
          </div>
        )}

        <div className="flex gap-2 flex-wrap">
          {device.type !== 'camera' && (
            <button
              disabled={busy || isFaulted}
              onClick={() => run(() => reportPower(device.id, !isOn))}
              className="px-3 py-1 rounded bg-indigo-600 text-white disabled:opacity-50"
            >
              {isOn ? 'Switch off' : 'Switch on'}
            </button>
          )}

          {isFaulted ? (
            <button
              disabled={busy}
              onClick={() => run(() => clearFault(device.id))}
              className="px-3 py-1 rounded bg-green-600 text-white disabled:opacity-50"
            >
              Recover
            </button>
          ) : (
            <>
              <button
                disabled={busy}
                onClick={() => run(() => reportFault(device.id))}
                className="px-3 py-1 rounded bg-red-500 text-white disabled:opacity-50"
              >
                Simulate Error
              </button>
              <button
                disabled={busy}
                onClick={() => run(() => reportDisconnected(device.id))}
                className="px-3 py-1 rounded bg-amber-500 text-white disabled:opacity-50"
              >
                Simulate Disconnect
              </button>
            </>
          )}
        </div>

        <div className="mt-2 text-xs text-slate-400">
          last change by {device.updatedBy ?? '—'}
          {device.statusReason ? ` · ${device.statusReason}` : ''}
        </div>
      </div>
    </div>
  )
}
