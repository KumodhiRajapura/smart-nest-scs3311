'use strict';

require('dotenv').config();

const { db, FieldValue, log } = require('./src/firebase');
const { COLLECTIONS, STATUS, DEVICE_TYPE, SOURCE, REASON } = require('./src/constants');

/**
 * Demo data.
 *
 * Document ids are fixed rather than generated, so re-running this overwrites
 * the same documents instead of piling up a second copy of the house. Run it as
 * often as you like.
 *
 *   npm run seed          write floors, devices and schedules
 *   npm run seed:wipe     delete usage logs and alerts first
 */

const FLOORS = [
  {
    id: 'floor_ground',
    name: 'Ground Floor',
    level: 0,
    planImageUrl: 'assets/floorplans/ground.png',
    gridCols: 8,
    gridRows: 6,
  },
  {
    id: 'floor_upper',
    name: 'Upper Floor',
    level: 1,
    planImageUrl: 'assets/floorplans/upper.png',
    gridCols: 8,
    gridRows: 6,
  },
];

const DEVICES = [
  // --- ground floor -------------------------------------------------------
  {
    id: 'dev_living_outlet',
    floorId: 'floor_ground',
    name: 'Living Room Outlet',
    type: DEVICE_TYPE.outlet,
    room: 'Living Room',
    gridX: 1,
    gridY: 1,
  },
  {
    id: 'dev_tv_outlet',
    floorId: 'floor_ground',
    name: 'TV Outlet',
    type: DEVICE_TYPE.outlet,
    room: 'Living Room',
    gridX: 3,
    gridY: 1,
  },
  {
    id: 'dev_kitchen_gang',
    floorId: 'floor_ground',
    name: 'Kitchen Gang Box',
    type: DEVICE_TYPE.multiSwitch,
    room: 'Kitchen',
    gridX: 5,
    gridY: 2,
    channels: [
      { index: 0, label: 'Ceiling Light', isOn: false },
      { index: 1, label: 'Exhaust Fan', isOn: false },
      { index: 2, label: 'Counter Light', isOn: false },
    ],
  },
  {
    id: 'dev_porch_light',
    floorId: 'floor_ground',
    name: 'Porch Light',
    type: DEVICE_TYPE.light,
    room: 'Porch',
    gridX: 0,
    gridY: 4,
  },
  {
    id: 'dev_front_camera',
    floorId: 'floor_ground',
    name: 'Front Door Camera',
    type: DEVICE_TYPE.camera,
    room: 'Porch',
    gridX: 1,
    gridY: 5,
    // Mock stream. Any always-available image URL works for the demo.
    streamUrl: 'https://picsum.photos/seed/frontdoor/640/360',
  },
  {
    id: 'dev_iron',
    floorId: 'floor_ground',
    name: 'Clothes Iron',
    type: DEVICE_TYPE.iron,
    room: 'Utility',
    gridX: 6,
    gridY: 4,
    // Two minutes so the cutoff is watchable in a demo video. A real iron
    // would be 15-30; the mechanism is identical either way.
    maxOnDurationMinutes: 2,
  },

  // --- upper floor --------------------------------------------------------
  {
    id: 'dev_bedroom_gang',
    floorId: 'floor_upper',
    name: 'Bedroom Gang Box',
    type: DEVICE_TYPE.multiSwitch,
    room: 'Master Bedroom',
    gridX: 2,
    gridY: 1,
    channels: [
      { index: 0, label: 'Ceiling Light', isOn: false },
      { index: 1, label: 'Bedside Lamp', isOn: false },
    ],
  },
  {
    id: 'dev_bedroom_outlet',
    floorId: 'floor_upper',
    name: 'Bedroom Outlet',
    type: DEVICE_TYPE.outlet,
    room: 'Master Bedroom',
    gridX: 4,
    gridY: 1,
  },
  {
    id: 'dev_study_light',
    floorId: 'floor_upper',
    name: 'Study Light',
    type: DEVICE_TYPE.light,
    room: 'Study',
    gridX: 6,
    gridY: 2,
  },
  {
    id: 'dev_hallway_camera',
    floorId: 'floor_upper',
    name: 'Hallway Camera',
    type: DEVICE_TYPE.camera,
    room: 'Hallway',
    gridX: 3,
    gridY: 4,
    streamUrl: 'https://picsum.photos/seed/hallway/640/360',
  },
];

const SCHEDULES = [
  {
    id: 'sch_porch_evening',
    deviceId: 'dev_porch_light',
    label: 'Porch light, evening',
    startTime: '18:30',
    endTime: '22:00',
    daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
    channelIndex: null,
    enabled: true,
  },
  {
    id: 'sch_study_weeknights',
    deviceId: 'dev_study_light',
    label: 'Study light, weeknights',
    startTime: '19:00',
    endTime: '23:00',
    daysOfWeek: [1, 2, 3, 4, 5],
    channelIndex: null,
    enabled: true,
  },
  {
    id: 'sch_kitchen_ceiling',
    deviceId: 'dev_kitchen_gang',
    label: 'Kitchen ceiling light, morning',
    startTime: '06:00',
    endTime: '08:00',
    daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
    // Targets one switch of the gang box, leaving the fan alone.
    channelIndex: 0,
    enabled: true,
  },
];

async function deleteCollection(name) {
  const snap = await db().collection(name).get();
  if (snap.empty) return;

  const batch = db().batch();
  snap.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  log(`wiped ${snap.size} docs from ${name}`);
}

async function seed() {
  const wipe = process.argv.includes('--wipe');

  if (wipe) {
    await deleteCollection(COLLECTIONS.usageLogs);
    await deleteCollection(COLLECTIONS.alerts);
  }

  const batch = db().batch();

  for (const floor of FLOORS) {
    const { id, ...data } = floor;
    batch.set(db().collection(COLLECTIONS.floors).doc(id), {
      ...data,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  for (const device of DEVICES) {
    const { id, ...data } = device;
    batch.set(db().collection(COLLECTIONS.devices).doc(id), {
      channels: [],
      maxOnDurationMinutes: null,
      streamUrl: null,
      lastHeartbeat: null,
      ...data,
      // Seeding always parks the house in a known state.
      status: STATUS.off,
      turnedOnAt: null,
      statusReason: REASON.manual,
      updatedBy: SOURCE.worker,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  for (const schedule of SCHEDULES) {
    const { id, ...data } = schedule;
    batch.set(db().collection(COLLECTIONS.schedules).doc(id), {
      ...data,
      lastRunAt: null,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();

  log(
    `seeded ${FLOORS.length} floors, ${DEVICES.length} devices, ` +
      `${SCHEDULES.length} schedules`
  );
}

seed()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
