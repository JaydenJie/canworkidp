import 'package:flutter/material.dart';

class BatteryMonitorPage extends StatelessWidget {
  final List<List<int>> readings;

  const BatteryMonitorPage({super.key, required this.readings});

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
      appBar: AppBar(
        title: const Text('Battery Monitor'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Summary Cards with adjusted height
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total voltage(mV)',
                      batteryData['totalVoltage'].toString(),
                      'Current (mA)',
                      batteryData['current'].toString(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Temperature (°C)',
                      batteryData['temperature'].toString(),
                      'SOC(%)',
                      batteryData['soc'].toString(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Adjusted Cell Grid
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3.0, // Increased from 2.5 to make cells wider
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: 15,
                itemBuilder: (context, index) {
                  return _buildCellCard(
                    'Cell_${index + 1}',
                    batteryData['cell${index + 1}'].toString(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title1, String value1, String title2, String value2) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title1: $value1',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$title2: $value2',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCellCard(String title, String value) {
    return Card(
      elevation: 2,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '$title(mV): $value',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}