import React from 'react'
import Dashboard from './pages/Dashboard'

export default function App() {
  return (
    <div className="min-h-screen bg-slate-50 text-slate-900">
      <header className="p-4 bg-indigo-600 text-white">
        <div className="max-w-6xl mx-auto">Smart Nest — Web Hardware Simulator</div>
      </header>
      <main className="max-w-6xl mx-auto p-4">
        <Dashboard />
      </main>
    </div>
  )
}
