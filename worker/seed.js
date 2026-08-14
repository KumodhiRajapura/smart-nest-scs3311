'use strict';

require('dotenv').config();

const { db, FieldValue, log } = require('./src/firebase');
const { COLLECTIONS, STATUS, SOURCE, REASON, DEVICE_TYPE } = require('./src/constants');

/**
 * Demo data, matching firebase/SCHEMA.md.
 *
 * Document ids are fixed rather than generated, so re-running overwrites the
 * same documents instead of piling up a second copy of the house. Run it as
 * often as you like -- it is the fastest way back to a known state after a
 * demo goes sideways.
 *
 *   npm run seed          write floors, rooms and devices
 *   npm run seed:wipe     clear usage logs and alerts first
 */

const FLOORS = [
  {
    id: 'floor_ground',
    name: 'Ground Floor',
    order: 0,
    floorPlanImageUrl: null,
  },
  {
    id: 'floor_upper',
    name: 'Upper Floor',
    order: 1,
    floorPlanImageUrl: null,
  },
];

const ROOMS = [
  { id: 'room_living', floorId: 'floor_ground', name: 'Living Room', gridRow: 0, gridCol: 0 },
  { id: 'room_kitchen', floorId: 'floor_ground', name: 'Kitchen', gridRow: 0, gridCol: 1 },
  { id: 'room_porch', floorId: 'floor_ground', name: 'Porch', gridRow: 1, gridCol: 0 },
  { id: 'room_utility', floorId: 'floor_ground', name: 'Utility', gridRow: 1, gridCol: 1 },
  { id: 'room_bedroom', floorId: 'floor_upper', name: 'Master Bedroom', gridRow: 0, gridCol: 0 },
  { id: 'room_study', floorId: 'floor_upper', name: 'Study', gridRow: 0, gridCol: 1 },
  { id: 'room_hallway', floorId: 'floor_upper', name: 'Hallway', gridRow: 1, gridCol: 0 },
];

const DEVICES = [
  // --- ground floor -------------------------------------------------------
  {
    id: 'dev_living_outlet',
    name: 'Living Room Outlet',
    roomId: 'room_living',
    type: DEVICE_TYPE.outlet,
  },
  {
    id: 'dev_tv_outlet',
    name: 'TV Outlet',
    roomId: 'room_living',
    type: DEVICE_TYPE.outlet,
  },
  {
    id: 'dev_kitchen_gang',
    name: 'Kitchen Gang Box',
    roomId: 'room_kitchen',
    type: DEVICE_TYPE.multiSwitch,
    childSwitches: [
      { id: 's0', label: 'Ceiling Light', isOn: false },
      { id: 's1', label: 'Exhaust Fan', isOn: false },
      { id: 's2', label: 'Counter Light', isOn: false },
    ],
  },
  {
    id: 'dev_porch_light',
    name: 'Porch Light',
    roomId: 'room_porch',
    type: DEVICE_TYPE.scheduledLight,
    scheduleStartTime: '18:30',
    scheduleEndTime: '22:00',
    scheduleDays: [1, 2, 3, 4, 5, 6, 7],
    scheduleEnabled: true,
  },
  {
    id: 'dev_front_camera',
    name: 'Front Door Camera',
    roomId: 'room_porch',
    type: DEVICE_TYPE.camera,
    // Mock snapshots. Any always-available image URL works; the simulator
    // rotates the array to fake a new frame.
    cameraImageUrls: [
      'https://picsum.photos/seed/frontdoor1/640/360',
      'https://picsum.photos/seed/frontdoor2/640/360',
      'https://picsum.photos/seed/frontdoor3/640/360',
    ],
  },
  {
    id: 'dev_iron',
    name: 'Clothes Iron',
    roomId: 'room_utility',
    type: DEVICE_TYPE.scheduledAppliance,
    // Two minutes so the cutoff is watchable inside a demo video. A real iron
    // would be 15-30; the mechanism is identical either way.
    maxOnDurationMinutes: 2,
  },

  // --- upper floor --------------------------------------------------------
  {
    id: 'dev_bedroom_gang',
    name: 'Bedroom Gang Box',
    roomId: 'room_bedroom',
    type: DEVICE_TYPE.multiSwitch,
    childSwitches: [
      { id: 's0', label: 'Ceiling Light', isOn: false },
      { id: 's1', label: 'Bedside Lamp', isOn: false },
    ],
  },
  {
    id: 'dev_bedroom_outlet',
    name: 'Bedroom Outlet',
    roomId: 'room_bedroom',
    type: DEVICE_TYPE.outlet,
  },
  {
    id: 'dev_study_light',
    name: 'Study Light',
    roomId: 'room_study',
    type: DEVICE_TYPE.scheduledLight,
    scheduleStartTime: '19:00',
    scheduleEndTime: '23:00',
    // Weeknights only -- proves the day filter in the demo.
    scheduleDays: [1, 2, 3, 4, 5],
    scheduleEnabled: true,
  },
  {
    id: 'dev_hallway_camera',
    name: 'Hallway Camera',
    roomId: 'room_hallway',
    type: DEVICE_TYPE.camera,
    cameraImageUrls: [
      'https://picsum.photos/seed/hallway1/640/360',
      'https://picsum.photos/seed/hallway2/640/360',
    ],
  },
];

function floorOf(roomId) {
  const room = ROOMS.find((r) => r.id === roomId);
  return room ? room.floorId : '';
}

async function deleteCollection(name) {
  const snap = await db().collection(name).get();
  if (snap.empty) return;

  const batch = db().batch();
  snap.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  log(`wiped ${snap.size} docs from ${name}`);
}

async function seed() {
  if (process.argv.includes('--wipe')) {
    await deleteCollection(COLLECTIONS.usageLogs);
    await deleteCollection(COLLECTIONS.alerts);
  }

  const batch = db().batch();

  for (const floor of FLOORS) {
    batch.set(db().collection(COLLECTIONS.floors).doc(floor.id), floor);
  }

  for (const room of ROOMS) {
    batch.set(db().collection(COLLECTIONS.rooms).doc(room.id), {
      ...room,
      // Denormalised so a room card can show a count without a second query.
      deviceIds: DEVICES.filter((d) => d.roomId === room.id).map((d) => d.id),
    });
  }

  for (const device of DEVICES) {
    batch.set(db().collection(COLLECTIONS.devices).doc(device.id), {
      // Explicit nulls so every document has the same shape -- a missing field
      // and a null one behave differently in Firestore queries.
      childSwitches: [],
      maxOnDurationMinutes: null,
      scheduleStartTime: null,
      scheduleEndTime: null,
      scheduleDays: null,
      scheduleEnabled: false,
      cameraImageUrls: null,
      lastHeartbeat: null,
      lastAlert: null,
      lastAlertAt: null,
      ...device,
      floorId: floorOf(device.roomId),
      // Seeding always parks the house in a known state. A device left ON with
      // a stale turnedOnAt would be cut off seconds later, which looks like a
      // bug and is really just bad seed data.
      status: STATUS.off,
      turnedOnAt: null,
      statusReason: REASON.manual,
      updatedBy: SOURCE.worker,
      lastUpdated: FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();

  log(
    `seeded ${FLOORS.length} floors, ${ROOMS.length} rooms, ` +
      `${DEVICES.length} devices`
  );
}

seed()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
