import 'package:flutter/material.dart';
import 'package:smart_nest_app/models/device_model.dart';
import 'package:smart_nest_app/models/room_model.dart';
import 'package:smart_nest_app/services/smart_home_service.dart';
import 'package:smart_nest_app/services/cloud_sync_service.dart';
import 'package:smart_nest_app/widgets/device_action.dart';

class FloorDashboardScreen extends StatefulWidget {
  final Room room;

  const FloorDashboardScreen({super.key, required this.room});

  @override
  State<FloorDashboardScreen> createState() => _FloorDashboardScreenState();
}

class _FloorDashboardScreenState extends State<FloorDashboardScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final cloud = CloudSyncService();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name),
      ),
      body: StreamBuilder<List<SmartDevice>>(
        stream: cloud.devicesStream(),
        builder: (context, snapshot) {
          final devices = snapshot.data ?? SmartHomeService().getDevices();
          final roomDevices = devices.where((device) => device.roomId == widget.room.id).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.room.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  // Show number of devices in this room from the latest cloud data
                  Text('${roomDevices.length} devices connected'),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.thermostat_outlined),
                      const SizedBox(width: 8),
                      // Room model does not expose a `temperature` field; show placeholder
                      const Text('Temperature unavailable'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Floor grid',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: List.generate(4, (index) {
                        final isFilled = index < roomDevices.length;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: isFilled ? Colors.white : Colors.grey.shade200,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Text(
                              isFilled ? roomDevices[index].name : 'Empty slot',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isFilled ? Colors.black : Colors.grey.shade500,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          const Text(
            'Controlled devices',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...roomDevices.map((device) {
            if (device.isMultiSwitch) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(device.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          // device.status is an enum (DeviceStatus); convert to a display string
                          Builder(builder: (context) {
                          final statusLabel = device.status.name;
                          return Text(statusLabel, style: TextStyle(color: statusLabel == 'on' ? Colors.green : Colors.grey));
                          }),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Multi-switch widget
                      StatefulBuilder(builder: (context, setLocal) {
                        return Column(
                          children: [
                            // show switches
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(device.multiSwitchStates.length, (i) {
                                final state = device.multiSwitchStates[i];
                                return ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: state ? Colors.green : Colors.grey.shade200,
                                    foregroundColor: state ? Colors.white : Colors.black87,
                                  ),
                                  onPressed: () => runDeviceAction(
                                    context,
                                    // update cloud-backed state (handles persistence and streams)
                                    () => CloudSyncService()
                                        .updateMultiSwitchState(device.id, i, !state),
                                  ),
                                  child: Text(state ? 'On' : 'Off'),
                                );
                              }),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeviceDetailScreen(device: device)));
                                },
                                child: const Text('Details'),
                              ),
                            )
                          ],
                        );
                      })
                    ],
                  ),
                ),
              );
            } else {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(device.name),
                  subtitle: Text('${device.type.name} · ${device.status.name}'),
                  trailing: Switch(
                  value: device.isOn,
                  onChanged: (value) => runDeviceAction(
                    context,
                    () => CloudSyncService().updateDeviceState(device.id, isOn: value),
                  ),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DeviceDetailScreen(device: device),
                      ),
                    );
                  },
                ),
              );
            }
          }),
        ],
      );
        },
      ),
    );
  }
}

class DeviceDetailScreen extends StatelessWidget {
  final SmartDevice device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(device.name)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: device.isOn ? Colors.green.shade50 : Colors.grey.shade200,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                   device.status.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text('Power draw: ${device.powerUsage.toStringAsFixed(1)} kW'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.electrical_services_rounded),
              title: const Text('Device Type'),
              trailing: Text(device.type.name),
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Room'),
              trailing: Text(device.roomId),
            ),
            ListTile(
              leading: const Icon(Icons.power_settings_new_rounded),
              title: const Text('Manual Control'),
              trailing: Switch(value: device.isOn, onChanged: (_) {}),
            ),
          ],
        ),
      ),
    );
  }
}
