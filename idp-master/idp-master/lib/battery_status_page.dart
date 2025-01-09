import 'package:flutter/material.dart';

class BatteryStatusPage extends StatelessWidget {
  final String deviceName;

  const BatteryStatusPage({Key? key, required this.deviceName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Battery Status - $deviceName"),
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          "Battery status details for $deviceName will be displayed here.",
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
