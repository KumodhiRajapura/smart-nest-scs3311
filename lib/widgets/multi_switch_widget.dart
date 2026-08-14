import 'package:flutter/material.dart';
import 'package:smart_nest_app/models/device_model.dart';

typedef OnSwitchToggled = void Function(int index, bool value);

class MultiSwitchWidget extends StatelessWidget {
  final SmartDevice device;
  final OnSwitchToggled onToggle;

  const MultiSwitchWidget({super.key, required this.device, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final int count = device.switches.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(count, (i) {
        final state = device.switches[i];
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => onToggle(i, !state),
                child: Container(
                  width: 62,
                  height: 36,
                  decoration: BoxDecoration(
                    color: state ? Colors.green.shade600 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      state ? 'On' : 'Off',
                      style: TextStyle(
                        color: state ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text('S${i + 1}', style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      }),
    );
  }
}
