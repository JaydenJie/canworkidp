import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'home_page.dart';
import 'battery_status_page.dart';
import 'warning_page.dart';
import 'history_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Colors.blue.withOpacity(0.1),
          labelTextStyle: MaterialStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      home: const MainNavigationPage(),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => MainNavigationPageState();
}

class MainNavigationPageState extends State<MainNavigationPage> {
  static MainNavigationPageState? of(BuildContext context) {
    return context.findAncestorStateOfType<MainNavigationPageState>();
  }

  int _selectedIndex = 0;
  BluetoothCharacteristic? _batteryCharacteristic;
  List<List<int>> _batteryReadings = [];
  BluetoothDevice? connectedDevice;

  List<Widget> get _pages => [
    const HomePage(),
    BatteryStatusPage(
      initialReadings: _batteryReadings,
      characteristic: _batteryCharacteristic,
    ),
    const WarningPage(),
    const HistoryPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void updateBatteryCharacteristic(BluetoothCharacteristic? characteristic) {
    setState(() {
      _batteryCharacteristic = characteristic;
    });
  }

  void addBatteryReading(List<int> reading) {
    setState(() {
      _batteryReadings.add(reading);
      if (_batteryReadings.length > 20) {
        _batteryReadings.removeAt(0);
      }
    });
  }

  void updateConnectedDevice(BluetoothDevice? device) {
    setState(() {
      connectedDevice = device;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.battery_full),
            label: 'Battery',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning),
            label: 'Warning',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}