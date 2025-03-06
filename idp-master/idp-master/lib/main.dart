import 'package:flutter/material.dart';
import 'bluetooth_searching_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BluetoothScannerPage(), // Homepage
    );
  }
}
