import 'package:flutter/material.dart';

class BatteryMonitorPage extends StatelessWidget {
  final List<List<int>> readings;

  const BatteryMonitorPage({super.key, required this.readings});

  // Color scheme definition
  static const Color primaryBlue = Color(0xFF2196F3);  // Material Blue
  static const Color lightBlue = Color(0xFFE3F2FD);    // Very light blue for backgrounds
  static const Color darkBlue = Color(0xFF1976D2);     // Darker blue for emphasis

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
    final batteryData = _processBatteryData(readings);

    return Scaffold(
      backgroundColor: lightBlue,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Battery Monitor',
          style: TextStyle(
            color: primaryBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Summary',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _buildMainStats(batteryData),
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
              _buildCellGrid(batteryData),
            ],
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
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 15,
      itemBuilder: (context, index) {
        return Container(
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
          ),
          padding: const EdgeInsets.all(12),
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
                '${data['cell${index + 1}']}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
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
}