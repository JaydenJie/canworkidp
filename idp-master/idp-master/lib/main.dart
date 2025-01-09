import 'package:flutter/material.dart';
import 'bluetooth_searching_page.dart';

//hello egg
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BluetoothScannerPage(), // The first page of the app
    );
  }
}
