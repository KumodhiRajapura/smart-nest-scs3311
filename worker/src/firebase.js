'use strict';

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');


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

function toDate(value) {
  if (!value) return null;

  if (value instanceof Date) {
    return value;
  }

  if (typeof value.toDate === 'function') {
    return value.toDate();
  }

  if (typeof value === 'string') {
    const parsed = new Date(value);

    if (!Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }

  return null;
}

function log(...args) {
  const now = new Date().toISOString().slice(11, 19);
  console.log(`[${now}]`, ...args);
}

module.exports = { init, db, messaging, FieldValue, Timestamp, toDate, log };
