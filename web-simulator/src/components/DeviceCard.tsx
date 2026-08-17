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

  const isOn = device.status === STATUS.on

  const isFaulted =
    device.status === STATUS.error ||
    device.status === STATUS.disconnected

  async function runAction(action: () => Promise<void>) {
    console.log('[Smart Nest] Button clicked')
    console.log('[Smart Nest] Device:', device.id)
    console.log('[Smart Nest] Current status:', device.status)

    setBusy(true)
    setError(null)

    try {
      await action()

      console.log('[Smart Nest] Action completed successfully')
    } catch (e: any) {
      console.error('[Smart Nest] Action failed:', e)

      const message =
        e?.message ||
        e?.code ||
        String(e)

      setError(message)
    } finally {
      setBusy(false)
    }
  }

  async function handlePower() {
    const newState = !isOn

    console.log(
      '[Smart Nest] POWER BUTTON',
      device.id,
      'FROM:',
      device.status,
      'TO:',
      newState ? 'ON' : 'OFF'
    )

    await runAction(() =>
      reportPower(device.id, newState)
    )
  }

  return (
    <div className="card">

      {/* HEADER */}
      <div className="flex items-start justify-between">
        <div>
          <div className="font-semibold">
            {device.name || device.id}
          </div>

          <div className="text-sm text-slate-500">
            {device.type} • {device.roomId || 'room'}
          </div>
        </div>

        <div
          className={`status-badge ${statusColor(
            device.status
          )}`}
        >
          {String(
            device.status ?? 'unknown'
          ).toUpperCase()}
        </div>
      </div>

      {/* MULTI SWITCH */}
      {device.type === 'multiSwitch' &&
        Array.isArray(device.childSwitches) && (
          <div className="mt-3 mb-3 space-y-2">

            {device.childSwitches.map((child: any) => (
              <div
                key={child.id}
                className="flex items-center gap-2 text-sm"
              >

                <span
                  className={`inline-block w-2 h-2 rounded-full ${
                    child.isOn
                      ? 'bg-green-500'
                      : 'bg-gray-400'
                  }`}
                />

                <span className="flex-1">
                  {child.label}
                </span>

                <button
                  disabled={busy || isFaulted}
                  onClick={() =>
                    runAction(() =>
                      reportChildSwitch(
                        device.id,
                        child.id,
                        !child.isOn
                      )
                    )
                  }
                  className="px-2 py-1 rounded bg-slate-200 disabled:opacity-50"
                >
                  {child.isOn ? 'off' : 'on'}
                </button>

              </div>
            ))}

          </div>
        )}

      {/* SCHEDULED APPLIANCE */}
      {device.type === 'scheduledAppliance' && (
        <div className="text-sm mb-3">

          <div>
            Max ON:{' '}
            {device.maxOnDurationMinutes ?? '—'} min
          </div>

          {isOn && device.turnedOnAt && (
            <div className="text-amber-700 mt-1">
              Running since{' '}
              {device.turnedOnAt.toDate?.()
                ?.toTimeString()
                .slice(0, 8)}
            </div>
          )}

        </div>
      )}

      {/* SCHEDULED LIGHT */}
      {device.type === 'scheduledLight' && (
        <div className="text-sm mb-3">
          Schedule:{' '}
          {device.scheduleStartTime ?? '—'}
          {' → '}
          {device.scheduleEndTime ?? '—'}
        </div>
      )}

      {/* CAMERA */}
      {device.type === 'camera' && (
        <div className="mb-3">

          <div className="relative overflow-hidden rounded mb-2 bg-slate-900">

            <img
              src={
                Array.isArray(device.cameraImageUrls) &&
                device.cameraImageUrls.length
                  ? device.cameraImageUrls[0]
                  : '/mock-cameras/front_porch.jpg'
              }
              alt="camera snapshot"
              className="w-full aspect-video object-cover"
              onError={(event) => {
                event.currentTarget.src =
                  '/mock-cameras/front_porch.jpg'
              }}
            />

            <span className="absolute left-2 top-2 px-2 py-1 rounded-full bg-black/60 text-white text-xs font-semibold">
              {isOn
                ? '● LIVE (simulated)'
                : 'OFFLINE'}
            </span>

          </div>

          <button
            disabled={busy}
            onClick={() =>
              runAction(() =>
                nextCameraFrame(
                  device.id,
                  Array.isArray(
                    device.cameraImageUrls
                  ) &&
                  device.cameraImageUrls.length
                    ? device.cameraImageUrls
                    : [
                        '/mock-cameras/front_porch.jpg?frame=1',
                        '/mock-cameras/front_porch.jpg?frame=2',
                      ]
                )
              )
            }
            className="px-3 py-1 rounded bg-indigo-500 text-white disabled:opacity-50"
          >
            New Snapshot
          </button>

        </div>
      )}

      {/* ALERT */}
      {device.lastAlert && (
        <div className="p-2 rounded bg-red-50 text-red-700 text-sm mb-2">
          Alert: {device.lastAlert}
        </div>
      )}

      {/* SAFETY CUTOFF */}
      {device.statusReason === 'safety_cutoff' && (
        <div className="p-2 rounded bg-amber-50 text-amber-800 text-sm mb-2">
          Switched off by the safety worker
        </div>
      )}

      {/* ERROR */}
      {error && (
        <div className="p-2 rounded bg-red-50 text-red-700 text-sm mb-3">
          ERROR: {error}
        </div>
      )}

      {/* CONTROLS */}
      <div className="flex gap-2 flex-wrap">

        {/* POWER */}
        {device.type !== 'camera' && (
          <button
            disabled={busy || isFaulted}
            onClick={handlePower}
            className="px-3 py-1 rounded bg-indigo-600 text-white disabled:opacity-50"
          >
            {busy
              ? 'Updating...'
              : isOn
                ? 'Switch off'
                : 'Switch on'}
          </button>
        )}

        {/* ERROR / RECOVER */}
        {isFaulted ? (

          <button
            disabled={busy}
            onClick={() =>
              runAction(() =>
                clearFault(device.id)
              )
            }
            className="px-3 py-1 rounded bg-green-600 text-white disabled:opacity-50"
          >
            Recover
          </button>

        ) : (

          <>
            <button
              disabled={busy}
              onClick={() =>
                runAction(() =>
                  reportFault(device.id)
                )
              }
              className="px-3 py-1 rounded bg-red-500 text-white disabled:opacity-50"
            >
              Simulate Error
            </button>

            <button
              disabled={busy}
              onClick={() =>
                runAction(() =>
                  reportDisconnected(device.id)
                )
              }
              className="px-3 py-1 rounded bg-amber-500 text-white disabled:opacity-50"
            >
              Simulate Disconnect
            </button>
          </>

        )}

      </div>

      {/* LAST CHANGE */}
      <div className="mt-3 text-xs text-slate-400">
        Last change by{' '}
        {device.updatedBy ?? '—'}

        {device.statusReason
          ? ` · ${device.statusReason}`
          : ''}
      </div>

    </div>
  )
}