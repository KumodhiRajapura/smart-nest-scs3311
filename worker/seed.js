'use strict';

require('dotenv').config();

const { db, FieldValue, log } = require('./src/firebase');
const { COLLECTIONS, STATUS, SOURCE, REASON, DEVICE_TYPE } = require('./src/constants');
const FLOORS = [
  {
    id: 'floor_ground',
    name: 'Ground Floor',
    order: 0,
    floorPlanImageUrl: 'assets/images/floor_plans/ground_floor.png',
  },
  {
    id: 'floor_upper',
    name: 'Upper Floor',
    order: 1,
    floorPlanImageUrl: 'assets/images/floor_plans/upper_floor.png',
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
    cameraImageUrls: [
      '/mock-cameras/front_porch.jpg?frame=1',
      '/mock-cameras/front_porch.jpg?frame=2',
      '/mock-cameras/front_porch.jpg?frame=3',
    ],
  },
  {
    id: 'dev_iron',
    name: 'Clothes Iron',
    roomId: 'room_utility',
    type: DEVICE_TYPE.scheduledAppliance,

    maxOnDurationMinutes: 2,
  },

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
    scheduleDays: [1, 2, 3, 4, 5],
    scheduleEnabled: true,
  },
  {
    id: 'dev_hallway_camera',
    name: 'Hallway Camera',
    roomId: 'room_hallway',
    type: DEVICE_TYPE.camera,
    cameraImageUrls: [
      '/mock-cameras/front_porch.jpg?frame=hallway1',
      '/mock-cameras/front_porch.jpg?frame=hallway2',
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
      deviceIds: DEVICES.filter((d) => d.roomId === room.id).map((d) => d.id),
    });
  }

  for (const device of DEVICES) {
    batch.set(db().collection(COLLECTIONS.devices).doc(device.id), {
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
