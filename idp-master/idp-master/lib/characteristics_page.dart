import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'battery_status_page.dart';

class CharacteristicsPage extends StatefulWidget {
  final BluetoothDevice device;

  const CharacteristicsPage({super.key, required this.device});

  @override
  State<CharacteristicsPage> createState() => _CharacteristicsPageState();
}

class _CharacteristicsPageState extends State<CharacteristicsPage> {
  List<BluetoothService> _services = [];
  bool _isLoading = true;
  Map<String, TextEditingController> _writeControllers = {};
  Map<String, List<List<int>>> _characteristicHistory = {}; // Store historical data
  Map<String, StreamSubscription> _notifySubscriptions = {};

  @override
  void initState() {
    super.initState();
    _discoverServices();
  }

  Future<void> _discoverServices() async {
    try {
      _services = await widget.device.discoverServices();

      for (var service in _services) {
        for (var characteristic in service.characteristics) {
          _characteristicHistory[characteristic.uuid.toString()] = []; // Initialize empty history

          if (characteristic.properties.write ||
              characteristic.properties.writeWithoutResponse) {
            _writeControllers[characteristic.uuid.toString()] =
                TextEditingController();
          }

          if (characteristic.properties.notify ||
              characteristic.properties.indicate) {
            await characteristic.setNotifyValue(true);
            _notifySubscriptions[characteristic.uuid.toString()] =
                characteristic.lastValueStream.listen((value) {
                  _processReceivedData(characteristic.uuid.toString(), value);
                });
          }
        }
      }
    } catch (e) {
      print('Error discovering services: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _processReceivedData(String uuid, List<int> value) {
    setState(() {
      _characteristicHistory[uuid]?.add(value); // Add new data to history
    });
  }

  Future<void> _readCharacteristic(BluetoothCharacteristic characteristic) async {
    try {
      final value = await characteristic.read();
      _processReceivedData(characteristic.uuid.toString(), value);

      String hexData = value.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');
      String asciiData = String.fromCharCodes(value.where((byte) => byte >= 32 && byte <= 126));

      _showMessage('''
Received ${value.length} bytes:
HEX: $hexData
ASCII: $asciiData
''');
    } catch (e) {
      _showError('Error reading characteristic: $e');
    }
  }

  // In your _buildDataDisplay method in CharacteristicsPage
  Widget _buildDataDisplay(String uuid, List<List<int>> history) {
    if (history.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('History (${history.length} readings)',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    // Add this button
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => BatteryMonitorPage(readings: history),
                          ),
                        );
                      },
                      child: const Text('Battery Monitor'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.clear_all),
                      onPressed: () {
                        setState(() {
                          _characteristicHistory[uuid]?.clear();
                        });
                      },
                      tooltip: 'Clear History',
                    ),
                  ],
                ),
              ],
            ),
            // ... rest of your existing code ...
          ],
        ),
      ),
    );
  }

  Widget _buildCharacteristicTile(BluetoothCharacteristic characteristic) {
    final shortUuid = _formatUUID(characteristic.uuid.toString());
    final history = _characteristicHistory[characteristic.uuid.toString()] ?? [];

    return ExpansionTile(
      title: Text('Characteristic $shortUuid'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_getPropertiesString(characteristic.properties)),
          Text('UUID: ${characteristic.uuid}',
              style: const TextStyle(fontSize: 12, color: Colors.grey))
        ],
      ),
      children: [
        if (characteristic.properties.read)
          ListTile(
            leading: const Icon(Icons.file_download),
            title: Text('Read Value (${history.length} readings stored)'),
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.read_more),
              label: const Text('Read'),
              onPressed: () => _readCharacteristic(characteristic),
            ),
          ),

        if (history.isNotEmpty)
          _buildDataDisplay(characteristic.uuid.toString(), history),

        if (characteristic.properties.notify ||
            characteristic.properties.indicate)
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            subtitle: Text(characteristic.isNotifying ? 'Enabled' : 'Disabled'),
            trailing: Switch(
              value: characteristic.isNotifying,
              onChanged: (bool value) => _toggleNotify(characteristic),
            ),
          ),
      ],
    );
  }

  String _formatUUID(String uuid) {
    uuid = uuid.replaceAll('-', '').replaceAll(' ', '');
    if (uuid.length <= 4) return uuid.toUpperCase();
    if (uuid.length >= 4) {
      return uuid.substring(0, 4).toUpperCase();
    }
    return uuid.toUpperCase();
  }

  Future<void> _toggleNotify(BluetoothCharacteristic characteristic) async {
    try {
      bool newValue = !characteristic.isNotifying;
      await characteristic.setNotifyValue(newValue);

      if (newValue) {
        // Set up new notification listener
        _notifySubscriptions[characteristic.uuid.toString()] =
            characteristic.lastValueStream.listen((value) {
              _processReceivedData(characteristic.uuid.toString(), value);
            });
        _showMessage('Notifications enabled');
      } else {
        // Remove existing listener
        await _notifySubscriptions[characteristic.uuid.toString()]?.cancel();
        _notifySubscriptions.remove(characteristic.uuid.toString());
        _showMessage('Notifications disabled');
      }
      setState(() {});
    } catch (e) {
      _showError('Error toggling notifications: $e');
    }
  }

  String _getPropertiesString(CharacteristicProperties properties) {
    List<String> props = [];
    if (properties.broadcast) props.add('Broadcast');
    if (properties.read) props.add('Read');
    if (properties.writeWithoutResponse) props.add('Write Without Response');
    if (properties.write) props.add('Write');
    if (properties.notify) props.add('Notify');
    if (properties.indicate) props.add('Indicate');
    return props.join(', ');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.device.platformName.isNotEmpty
                ? widget.device.platformName
                : 'Unknown Device'),
            Text(
              widget.device.remoteId.toString(),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _services.isEmpty
          ? const Center(child: Text('No services found'))
          : ListView.builder(
        itemCount: _services.length,
        itemBuilder: (context, serviceIndex) {
          BluetoothService service = _services[serviceIndex];
          final shortUuid = _formatUUID(service.uuid.toString());

          return ExpansionTile(
            title: Text('Service $shortUuid'),
            subtitle: Text(
              'UUID: ${service.uuid}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            children: service.characteristics
                .map(_buildCharacteristicTile)
                .toList(),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    // Cancel all notification subscriptions
    for (var subscription in _notifySubscriptions.values) {
      subscription.cancel();
    }
    // Dispose of text controllers
    for (var controller in _writeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}