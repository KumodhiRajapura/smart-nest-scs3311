// Seed script for demo data (Node admin SDK). Run with `node seed_script.js` after building.
// NOTE: This is a helper script for Member 2 to create demo floors/rooms/devices.

const admin = require('firebase-admin');

// Initialize with application default credentials or a local service account
try {
  admin.initializeApp();
} catch (e) {
  console.error('Initialize admin failed:', e);
}

const db = admin.firestore();

async function seed() {
  // Floors
  const f1 = { id: 'floor1', name: 'Ground Floor', order: 0 };
  const f2 = { id: 'floor2', name: 'First Floor', order: 1 };
  await db.collection('floors').doc(f1.id).set(f1);
  await db.collection('floors').doc(f2.id).set(f2);

  // Rooms
  const r1 = { id: 'living', floorId: f1.id, name: 'Living Room', gridRow: 0, gridCol: 0 };
  const r2 = { id: 'kitchen', floorId: f1.id, name: 'Kitchen', gridRow: 0, gridCol: 1 };
  const r3 = { id: 'bed1', floorId: f2.id, name: 'Bedroom 1', gridRow: 0, gridCol: 0 };
  await db.collection('rooms').doc(r1.id).set(r1);
  await db.collection('rooms').doc(r2.id).set(r2);
  await db.collection('rooms').doc(r3.id).set(r3);

  // Devices
  const devices = [
    { id: 'outlet1', roomId: r1.id, floorId: f1.id, name: 'Lamp Outlet', type: 'outlet', status: 'off', updatedBy: 'backend_worker', lastUpdated: admin.firestore.FieldValue.serverTimestamp() },
    { id: 'multi1', roomId: r1.id, floorId: f1.id, name: 'Living Multi', type: 'multiSwitch', status: 'off', childSwitches: [{id:'s1',label:'Ceiling',isOn:false},{id:'s2',label:'Fan',isOn:false}], updatedBy: 'backend_worker', lastUpdated: admin.firestore.FieldValue.serverTimestamp() },
    { id: 'iron1', roomId: r2.id, floorId: f1.id, name: 'Clothes Iron', type: 'scheduledAppliance', status: 'off', maxOnDurationMinutes: 15, updatedBy: 'backend_worker', lastUpdated: admin.firestore.FieldValue.serverTimestamp() },
    { id: 'bulb1', roomId: r3.id, floorId: f2.id, name: 'Bedroom Light', type: 'scheduledLight', status: 'off', scheduleStartTime: '19:00', scheduleEndTime: '23:00', updatedBy: 'backend_worker', lastUpdated: admin.firestore.FieldValue.serverTimestamp() },
    { id: 'cam1', roomId: r1.id, floorId: f1.id, name: 'Front Door Cam', type: 'camera', status: 'on', cameraImageUrls: ['https://placehold.co/400x300','https://placehold.co/400x300?text=2'], updatedBy: 'backend_worker', lastUpdated: admin.firestore.FieldValue.serverTimestamp() }
  ];

  for (const d of devices) {
    await db.collection('devices').doc(d.id).set(d);
  }

  console.log('Seeding complete');
}

seed().catch(console.error);
