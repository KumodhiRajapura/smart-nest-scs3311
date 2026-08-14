'use strict';

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

/**
 * Admin SDK bootstrap.
 *
 * The Admin SDK talks to Firestore as a service account, which means it
 * bypasses security rules entirely. That is exactly what we want for a trusted
 * worker -- the rules can stay tight enough to reject a rogue client while the
 * worker still writes the fields no client is allowed to touch (safety
 * cutoffs, usage logs).
 */

let app = null;

function init() {
  if (app) return app;

  const keyPath = path.resolve(
    process.env.SERVICE_ACCOUNT_PATH || './serviceAccount.json'
  );

  if (!fs.existsSync(keyPath)) {
    console.error(
      `\nMissing service account key at ${keyPath}\n\n` +
        'Firebase console -> Project settings -> Service accounts ->\n' +
        '"Generate new private key", save it as worker/serviceAccount.json.\n' +
        'It is git-ignored. Never commit it.\n'
    );
    process.exit(1);
  }

  app = admin.initializeApp({
    credential: admin.credential.cert(require(keyPath)),
  });

  return app;
}

function db() {
  init();
  return admin.firestore();
}

function messaging() {
  init();
  return admin.messaging();
}

const { FieldValue, Timestamp } = admin.firestore;

/** Firestore timestamp -> JS Date, tolerating nulls and already-Date values. */
function toDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === 'function') return value.toDate();
  return null;
}

/** Timestamped console line, so the log reads like a device log. */
function log(...args) {
  const now = new Date().toISOString().slice(11, 19);
  console.log(`[${now}]`, ...args);
}

module.exports = { init, db, messaging, FieldValue, Timestamp, toDate, log };
