import 'package:smart_nest_app/models/device_model.dart';
import 'package:smart_nest_app/models/room_model.dart';

class SmartHomeService {
  const SmartHomeService();

  // Return some lightweight Room fixtures for local/demo fallback.
  List<Room> getRooms() {
    return const [
      Room(id: 'room-living', floorId: 'floor-1', name: 'Living Room', gridRow: 0, gridCol: 0),
      Room(id: 'room-bedroom', floorId: 'floor-1', name: 'Bedroom', gridRow: 0, gridCol: 1),
      Room(id: 'room-kitchen', floorId: 'floor-1', name: 'Kitchen', gridRow: 1, gridCol: 0),
    ];
  }

  // Return some sample SmartDevice fixtures matching the canonical SmartDevice model.
  List<SmartDevice> getDevices() {
    return [
      SmartDevice(
        id: 'dev-1',
        name: 'Main Light',
        roomId: 'room-living',
        type: DeviceType.scheduledLight,
        status: DeviceStatus.on,
        childSwitches: const [],
        scheduleStartTime: '18:00',
        scheduleEndTime: '23:00',
        powerUsage: 5.0,
      ),
      SmartDevice(
        id: 'dev-2',
        name: 'Air Conditioner',
        roomId: 'room-living',
        type: DeviceType.outlet,
        status: DeviceStatus.on,
        powerUsage: 180.0,
      ),
      SmartDevice(
        id: 'dev-3',
        name: 'Security Camera',
        roomId: 'room-bedroom',
        type: DeviceType.camera,
        status: DeviceStatus.on,
        cameraImageUrls: ['https://via.placeholder.com/320x180?text=Cam1'],
        powerUsage: 12.0,
      ),
      SmartDevice(
        id: 'dev-4',
        name: 'Dishwasher',
        roomId: 'room-kitchen',
        type: DeviceType.outlet,
        status: DeviceStatus.off,
        powerUsage: 0.0,
      ),
      SmartDevice(
        id: 'dev-5',
        name: '3-Gang Switch',
        roomId: 'room-living',
        type: DeviceType.multiSwitch,
        status: DeviceStatus.off,
        childSwitches: const [
          SwitchChild(id: 's0', label: 'Switch 1', isOn: true),
          SwitchChild(id: 's1', label: 'Switch 2', isOn: false),
          SwitchChild(id: 's2', label: 'Switch 3', isOn: false),
        ],
        powerUsage: 0.0,
        scheduleStartTime: '18:00',
        scheduleEndTime: '23:00',
        maxOnDurationMinutes: 240,
      ),
      SmartDevice(
        id: 'dev-6',
        name: 'Iron Station',
        roomId: 'room-bedroom',
        type: DeviceType.scheduledAppliance,
        status: DeviceStatus.off,
        maxOnDurationMinutes: 30,
        powerUsage: 0.0,
      ),
    ];
  }

  int getActiveDeviceCount() {
    return getDevices().where((device) => device.isOn).length;
  }

  double getTotalPowerUsage() {
    return getDevices().where((device) => device.isOn).fold(0.0, (total, device) => total + device.powerUsage);
  }
}
