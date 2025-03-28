import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BatteryProvider extends ChangeNotifier {
  BluetoothCharacteristic? _characteristic;
  List<List<int>> _readings = [];

  BluetoothCharacteristic? get characteristic => _characteristic;
  List<List<int>> get readings => _readings;

  void setCharacteristic(BluetoothCharacteristic? char) {
    _characteristic = char;
    notifyListeners();
  }

  void addReading(List<int> reading) {
    _readings.add(reading);
    if (_readings.length > 20) {
      _readings.removeAt(0);
    }
    notifyListeners();
  }
} 