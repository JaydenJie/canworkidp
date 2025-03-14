import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BatteryStatusPage extends StatefulWidget {
  final List<List<int>> initialReadings;
  final BluetoothCharacteristic? characteristic; // Add characteristic to subscribe to

  const BatteryStatusPage({
    super.key,
    required this.initialReadings,
    this.characteristic, // Optional if we want to pass it from previous page
  });

  @override
  State<BatteryStatusPage> createState() => _BatteryStatusPageState();
}

class _BatteryStatusPageState extends State<BatteryStatusPage> {
  // Color scheme definition
  static const Color primaryBlue = Color(0xFF2196F3);  // Material Blue
  static const Color lightBlue = Color(0xFFE3F2FD);    // Very light blue for backgrounds
  static const Color darkBlue = Color(0xFF1976D2);     // Darker blue for emphasis

  List<List<int>> _readings = [];
  Map<String, int> _batteryData = {};
  StreamSubscription? _notifySubscription;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Initialize with existing readings
    _readings = List.from(widget.initialReadings);

    // Process initial data
    _updateBatteryData();

    // Subscribe to real-time notifications if characteristic is provided
    _setupRealTimeUpdates();

    // Refresh UI periodically even if no new data (for animations)
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _notifySubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _setupRealTimeUpdates() {
    if (widget.characteristic != null) {
      // Enable notifications if not already enabled
      if (!widget.characteristic!.isNotifying) {
        widget.characteristic!.setNotifyValue(true);
      }

      // Subscribe to notifications using the correct property
      _notifySubscription = widget.characteristic!.lastValueStream.listen((value) {
        if (mounted) {
          setState(() {
            _readings.add(value);
            // Keep only the last 20 readings to prevent memory issues
            if (_readings.length > 20) {
              _readings.removeAt(0);
            }
            _updateBatteryData();
          });
        }
      });
    }
  }

  void _updateBatteryData() {
    _batteryData = _processBatteryData(_readings);
  }

  int _parseVoltage(int highByte, int lowByte) {
    String hexString = highByte.toRadixString(16).padLeft(2, '0') +
        lowByte.toRadixString(16).padLeft(2, '0');
    return int.parse(hexString, radix: 16);
  }

  Map<String, int> _processBatteryData(List<List<int>> history) {
    var batteryData = {
      'totalVoltage': 0,
      'current': 0,
      'temperature': 0,
      'soc': 0,
    };

    List<int> cells = List.filled(15, 0);

    for (var data in history.reversed) {
      if (data.length < 2) continue;

      if (data[0] == 0xaa && data[1] == 0x02) {
        for (int i = 0; i < 9; i++) {
          if (data.length >= (i * 2 + 4)) {
            cells[i] = _parseVoltage(data[i * 2 + 2], data[i * 2 + 3]);
          }
        }
      } else if (data[0] == 0xaa && data[1] == 0x03) {
        for (int i = 0; i < 6; i++) {
          if (data.length >= (i * 2 + 4)) {
            cells[i + 9] = _parseVoltage(data[i * 2 + 2], data[i * 2 + 3]);
          }
        }
        if (data.length >= 16) {
          batteryData['totalVoltage'] = _parseVoltage(data[14], data[15]);
        }
        if (data.length >= 18) {
          batteryData['soc'] = _parseVoltage(data[16], data[17]);
        }
        if (data.length >= 20) {
          batteryData['current'] = _parseVoltage(data[18], data[19]);
        }
      } else if (data[0] == 0xaa && data[1] == 0x04) {
        if (data.length >= 3) {
          batteryData['temperature'] = data[2];
        }
      }
    }

    for (int i = 0; i < cells.length; i++) {
      batteryData['cell${i + 1}'] = cells[i];
    }

    return batteryData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBlue,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Battery Status',
          style: TextStyle(
            color: primaryBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          // Add refresh button to manually read if needed
          if (widget.characteristic != null && widget.characteristic!.properties.read)
            IconButton(
              icon: const Icon(Icons.refresh, color: primaryBlue),
              onPressed: () async {
                try {
                  final value = await widget.characteristic!.read();
                  if (mounted) {
                    setState(() {
                      _readings.add(value);
                      _updateBatteryData();
                    });
                  }
                } catch (e) {
                  // Handle error (could show a snackbar)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error reading data: $e')),
                  );
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        bottom: true, // Ensure safe area at bottom
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          // Add very generous bottom padding to prevent overflow
          child: Padding(
            padding: const EdgeInsets.only(bottom: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: widget.characteristic?.isNotifying == true
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.characteristic?.isNotifying == true
                            ? 'Live Data'
                            : 'Static Data',
                        style: TextStyle(
                          color: widget.characteristic?.isNotifying == true
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Summary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _buildMainStats(_batteryData),
                const SizedBox(height: 24),
                const Text(
                  'Cell Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _buildCellGrid(_batteryData),
                const SizedBox(height: 24),
                // Show number of readings received
                Text(
                  'Data points: ${_readings.length}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainStats(Map<String, int> data) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryBlue, darkBlue],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              _buildMainStatItem(
                'Total Voltage',
                '${data['totalVoltage']}',
                'mV',
                Icons.bolt,
              ),
              const SizedBox(width: 24),
              _buildMainStatItem(
                'Current',
                '${data['current']}',
                'mA',
                Icons.electric_meter,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildMainStatItem(
                'Temperature',
                '${data['temperature']}',
                '°C',
                Icons.thermostat,
              ),
              const SizedBox(width: 24),
              _buildMainStatItem(
                'SOC',
                '${data['soc']}',
                '%',
                Icons.battery_full,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainStatItem(String label, String value, String unit, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$value $unit',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCellGrid(Map<String, int> data) {
    // Calculate a more appropriate aspect ratio based on the device size
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 32 - 24) / 3; // Width minus padding and spacing

    // Use a smaller aspect ratio to provide more height for each cell
    // Lower values give more height to each item
    final aspectRatio = itemWidth / 100;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16, // Increased spacing between rows
      ),
      itemCount: 15,
      itemBuilder: (context, index) {
        final cellValue = data['cell${index + 1}'] ?? 0;
        // Add animation for value changes
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
            // Add a subtle border that changes color based on cell value
            border: Border.all(
              color: _getCellColor(cellValue),
              width: 2,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Cell ${index + 1}',
                style: const TextStyle(
                  color: primaryBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$cellValue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getCellTextColor(cellValue),
                ),
              ),
              const Text(
                'mV',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper function to determine cell color based on voltage
  Color _getCellColor(int value) {
    if (value <= 0) return Colors.grey.withOpacity(0.3);
    if (value < 3000) return Colors.red.withOpacity(0.5); // Low voltage
    if (value > 4200) return Colors.orange.withOpacity(0.5); // High voltage
    return Colors.green.withOpacity(0.3); // Normal voltage
  }

  // Helper function for text color
  Color _getCellTextColor(int value) {
    if (value <= 0) return Colors.grey;
    if (value < 3000) return Colors.red; // Low voltage
    if (value > 4200) return Colors.orange; // High voltage
    return Colors.black; // Normal voltage
  }
}