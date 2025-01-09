import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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

  @override
  void initState() {
    super.initState();
    _discoverServices();
  }

  Future<void> _discoverServices() async {
    try {
      _services = await widget.device.discoverServices();
      // Initialize controllers for each writable characteristic
      for (var service in _services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write ||
              characteristic.properties.writeWithoutResponse) {
            _writeControllers[characteristic.uuid.toString()] =
                TextEditingController();
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

  Future<void> _readCharacteristic(BluetoothCharacteristic characteristic) async {
    try {
      final value = await characteristic.read();
      _showMessage(
          'Read Value: ${String.fromCharCodes(value)}\nHex: ${value.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}'
      );
    } catch (e) {
      _showError('Error reading characteristic: $e');
    }
  }

  Future<void> _writeCharacteristic(
      BluetoothCharacteristic characteristic,
      String value
      ) async {
    try {
      // Convert hex string to bytes
      final List<int> bytes = value
          .split(' ')
          .where((element) => element.isNotEmpty)
          .map((e) => int.parse(e, radix: 16))
          .toList();

      await characteristic.write(bytes);
      _showMessage('Write successful');
    } catch (e) {
      _showError('Error writing characteristic: $e');
    }
  }

  Future<void> _toggleNotify(BluetoothCharacteristic characteristic) async {
    try {
      if (characteristic.isNotifying) {
        await characteristic.setNotifyValue(false);
        _showMessage('Notifications disabled');
      } else {
        await characteristic.setNotifyValue(true);
        characteristic.lastValueStream.listen((value) {
          _showMessage(
              'Notification: ${String.fromCharCodes(value)}\nHex: ${value.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}'
          );
        });
        _showMessage('Notifications enabled');
      }
      setState(() {}); // Update UI to reflect notification state
    } catch (e) {
      _showError('Error toggling notifications: $e');
    }
  }

  String _formatUUID(String uuid) {
    // Remove any dashes and spaces
    uuid = uuid.replaceAll('-', '').replaceAll(' ', '');

    // If the UUID is already short (16 bits), return it
    if (uuid.length <= 4) return uuid.toUpperCase();

    // For full UUIDs, return the short version if possible
    if (uuid.length >= 4) {
      return uuid.substring(0, 4).toUpperCase();
    }

    return uuid.toUpperCase();
  }

  Widget _buildCharacteristicTile(BluetoothCharacteristic characteristic) {
    final shortUuid = _formatUUID(characteristic.uuid.toString());

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
        // Read Button
        if (characteristic.properties.read)
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Read Value'),
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.read_more),
              label: const Text('Read'),
              onPressed: () => _readCharacteristic(characteristic),
            ),
          ),

        // Write Section
        if (characteristic.properties.write ||
            characteristic.properties.writeWithoutResponse)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Write Value (Hex format: 01 02 03)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _writeControllers[characteristic.uuid.toString()],
                  decoration: const InputDecoration(
                    hintText: 'Enter hex values (e.g., FF 00 FF)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Write'),
                  onPressed: () => _writeCharacteristic(
                    characteristic,
                    _writeControllers[characteristic.uuid.toString()]!.text,
                  ),
                ),
              ],
            ),
          ),

        // Notify Toggle
        if (characteristic.properties.notify ||
            characteristic.properties.indicate)
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            trailing: Switch(
              value: characteristic.isNotifying,
              onChanged: (bool value) => _toggleNotify(characteristic),
            ),
          ),
      ],
    );
  }

  String _getPropertiesString(CharacteristicProperties properties) {
    List<String> props = [];
    if (properties.broadcast) props.add('Broadcast');
    if (properties.read) props.add('Read');
    if (properties.writeWithoutResponse) props.add('Write Without Response');
    if (properties.write) props.add('Write');
    if (properties.notify) props.add('Notify');
    if (properties.indicate) props.add('Indicate');
    if (properties.authenticatedSignedWrites) props.add('Authenticated Writes');
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
    for (var controller in _writeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}