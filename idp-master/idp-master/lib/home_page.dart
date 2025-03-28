import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth_searching_page.dart';
import 'main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  BluetoothCharacteristic? _batteryCharacteristic;
  StreamSubscription? _notifySubscription;

  // Define blue theme colors
  static const primaryBlue = Color(0xFF2196F3);
  static const lightBlue = Color(0xFFE3F2FD);
  static const darkBlue = Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    _setupBatteryUpdates();
  }

  void _setupBatteryUpdates() {
    if (_batteryCharacteristic != null) {
      if (!_batteryCharacteristic!.isNotifying) {
        _batteryCharacteristic!.setNotifyValue(true);
      }

      _notifySubscription = _batteryCharacteristic!.lastValueStream.listen((value) {
        final navigationState = MainNavigationPageState.of(context);
        if (navigationState != null) {
          navigationState.addBatteryReading(value);
          if (mounted) setState(() {});
        }
      });
    }
  }

  Future<void> _findBatteryCharacteristic(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString().toLowerCase() == 'ffe1') {
            setState(() {
              _batteryCharacteristic = characteristic;
            });
            
            // Use the public class name
            final navigationState = MainNavigationPageState.of(context);
            if (navigationState != null) {
              navigationState.updateBatteryCharacteristic(characteristic);
            }
            
            break;
          }
        }
      }
    } catch (e) {
      print('Error finding battery characteristic: $e');
    }
  }

  Future<void> _addNewDevice() async {
    final result = await Navigator.push<BluetoothDevice>(
      context,
      MaterialPageRoute(
        builder: (context) => const BluetoothScannerPage(),
      ),
    );

    if (result != null) {
      final navigationState = MainNavigationPageState.of(context);
      if (navigationState != null) {
        navigationState.updateConnectedDevice(result);
      }
      _findBatteryCharacteristic(result);
    }
  }

  Widget _buildBatteryInfoCard({
    required String title,
    required String value,
    required IconData icon,
    Color? backgroundColor,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primaryBlue, size: 20),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureCard({required String title, required String value}) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.thermostat, color: primaryBlue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigationState = MainNavigationPageState.of(context);
    final connectedDevice = navigationState?.connectedDevice;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (connectedDevice == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryBlue, width: 2),
                      ),
                      child: Icon(Icons.close, size: 40, color: primaryBlue),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No device connected yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _addNewDevice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text('Connect the device'),
                    ),
                  ],
                ),
              ),
            if (connectedDevice != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Battery Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            'More',
                            style: TextStyle(color: primaryBlue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.2,
                      children: [
                        _buildBatteryInfoCard(
                          title: 'Total Volt(V)',
                          value: _batteryCharacteristic != null ? '48.2' : '/',
                          icon: Icons.bolt,
                        ),
                        _buildBatteryInfoCard(
                          title: 'SOC(%)',
                          value: _batteryCharacteristic != null ? '85' : '/',
                          icon: Icons.battery_charging_full,
                        ),
                        _buildBatteryInfoCard(
                          title: 'Volt.Diff(mV)',
                          value: _batteryCharacteristic != null ? '32' : '/',
                          icon: Icons.compare_arrows,
                        ),
                        _buildBatteryInfoCard(
                          title: 'Current(A)',
                          value: _batteryCharacteristic != null ? '2.4' : '/',
                          icon: Icons.electric_meter,
                        ),
                        _buildBatteryInfoCard(
                          title: 'SOH(%)',
                          value: _batteryCharacteristic != null ? '95' : '/',
                          icon: Icons.health_and_safety,
                          backgroundColor: Colors.red[100],
                        ),
                        _buildBatteryInfoCard(
                          title: 'Cycles(time)',
                          value: _batteryCharacteristic != null ? '124' : '/',
                          icon: Icons.refresh,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Temp',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Max Charging Current/A',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTemperatureCard(
                            title: 'Temp1',
                            value: _batteryCharacteristic != null ? '35°C' : '/',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTemperatureCard(
                            title: 'Temp2',
                            value: _batteryCharacteristic != null ? '38°C' : '/',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notifySubscription?.cancel();
    super.dispose();
  }
} 