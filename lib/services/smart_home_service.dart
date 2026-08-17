import 'package:smart_nest_app/models/device_model.dart';
import 'package:smart_nest_app/models/floor_model.dart';
import 'package:smart_nest_app/models/room_model.dart';

/// Local fixtures used only when Firebase has not been configured yet
/// (see [AppConfig.enableLocalDemoFallback]). Shaped as a small two-floor
/// house so every screen -- the floor grid, scheduling, safety cutoffs, the
/// camera feed and the reports chart -- has something real to render before
/// `flutterfire configure` has been run.
class SmartHomeService {
  const SmartHomeService();

  List<FloorModel> getFloors() {
    return const [
      FloorModel(
        id: 'floor-1',
        name: 'Ground Floor',
        order: 0,
        floorPlanImageAsset:
            'https://images.pexels.com/photos/271667/pexels-photo-271667.jpeg?auto=compress&cs=tinysrgb&w=1200',
      ),
      FloorModel(
        id: 'floor-2',
        name: 'Upper Floor',
        order: 1,
        floorPlanImageAsset:
            'https://images.pexels.com/photos/4458196/pexels-photo-4458196.jpeg?auto=compress&cs=tinysrgb&w=1200',
      ),
    ];
  }

  List<Room> getRooms() {
    return const [
      Room(
        id: 'room-living',
        floorId: 'floor-1',
        name: 'Living Room',
        gridRow: 0,
        gridCol: 0,
        description: 'Main lounge and entertainment area',
      ),
      Room(
        id: 'room-kitchen',
        floorId: 'floor-1',
        name: 'Kitchen',
        gridRow: 0,
        gridCol: 1,
        description: 'Cooking and dining space',
      ),
      Room(
        id: 'room-garage',
        floorId: 'floor-1',
        name: 'Garage',
        gridRow: 1,
        gridCol: 0,
        description: 'Vehicle and storage',
      ),
      Room(
        id: 'room-porch',
        floorId: 'floor-1',
        name: 'Front Porch',
        gridRow: 1,
        gridCol: 1,
        description: 'Entrance and outdoor camera',
      ),
      Room(
        id: 'room-bedroom',
        floorId: 'floor-2',
        name: 'Main Bedroom',
        gridRow: 0,
        gridCol: 0,
        description: 'Primary bedroom',
      ),
      Room(
        id: 'room-utility',
        floorId: 'floor-2',
        name: 'Utility Room',
        gridRow: 0,
        gridCol: 1,
        description: 'Laundry and ironing station',
      ),
    ];
  }

  List<SmartDevice> getDevices() {
    final now = DateTime.now();
    return [
      SmartDevice(
        id: 'dev-1',
        name: 'Main Light',
        roomId: 'room-living',
        type: DeviceType.scheduledLight,
        status: DeviceStatus.on,
        scheduleStartTime: '18:00',
        scheduleEndTime: '23:00',
        powerUsage: 0.1,
      ),
      SmartDevice(
        id: 'dev-2',
        name: 'Air Conditioner',
        roomId: 'room-living',
        type: DeviceType.outlet,
        status: DeviceStatus.on,
        powerUsage: 1.8,
      ),
      SmartDevice(
        id: 'dev-3',
        name: 'Front Door Camera',
        roomId: 'room-porch',
        type: DeviceType.camera,
        status: DeviceStatus.on,
        cameraImageUrls: const ['assets/images/cameras/front_porch.jpg'],
        powerUsage: 0.02,
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
        name: 'Kitchen Gang Box',
        roomId: 'room-kitchen',
        type: DeviceType.multiSwitch,
        status: DeviceStatus.on,
        childSwitches: const [
          SwitchChild(id: 's0', label: 'Ceiling Light', isOn: true),
          SwitchChild(id: 's1', label: 'Exhaust Fan', isOn: false),
          SwitchChild(id: 's2', label: 'Counter Lights', isOn: true),
        ],
        powerUsage: 0.15,
      ),
      SmartDevice(
        id: 'dev-6',
        name: 'Clothes Iron',
        roomId: 'room-utility',
        type: DeviceType.scheduledAppliance,
        status: DeviceStatus.on,
        maxOnDurationMinutes: 30,
        turnedOnAt: now.subtract(const Duration(minutes: 12)),
        powerUsage: 1.1,
      ),
      SmartDevice(
        id: 'dev-7',
        name: 'Bedroom Lamp',
        roomId: 'room-bedroom',
        type: DeviceType.outlet,
        status: DeviceStatus.off,
        powerUsage: 0.0,
      ),
      SmartDevice(
        id: 'dev-8',
        name: 'Garage Camera',
        roomId: 'room-garage',
        type: DeviceType.camera,
        status: DeviceStatus.disconnected,
        cameraImageUrls: const [
          'https://images.pexels.com/photos/9139588/pexels-photo-9139588.jpeg?auto=compress&cs=tinysrgb&w=1200'
        ],
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
