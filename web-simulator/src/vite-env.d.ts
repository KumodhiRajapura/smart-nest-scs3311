/// <reference types="vite/client" />

/**
 * Typed access to the Firebase config Vite inlines at build time.
 *
 * Values live in web-simulator/.env -- see .env.example. Declaring them here
 * means a typo in a variable name is a compile error rather than an
 * `undefined` that surfaces later as an unhelpful Firebase init failure.
 */
interface ImportMetaEnv {
  readonly VITE_FIREBASE_API_KEY: string
  readonly VITE_FIREBASE_AUTH_DOMAIN: string
  readonly VITE_FIREBASE_PROJECT_ID: string
  readonly VITE_FIREBASE_STORAGE_BUCKET: string
  readonly VITE_FIREBASE_MESSAGING_SENDER_ID: string
  readonly VITE_FIREBASE_APP_ID: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
