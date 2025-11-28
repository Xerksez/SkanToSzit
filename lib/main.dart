import 'package:flutter/material.dart';
import 'config/scan_settings.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await ScanSettings.load();
  runApp(VinScannerApp(initialSettings: settings));
}

class VinScannerApp extends StatefulWidget {
  final ScanSettings initialSettings;

  const VinScannerApp({super.key, required this.initialSettings});

  @override
  State<VinScannerApp> createState() => _VinScannerAppState();
}

class _VinScannerAppState extends State<VinScannerApp> {
  late ScanSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  void _updateSettings(ScanSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
    _settings.save();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VIN Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: HomeScreen(
        settings: _settings,
        onSettingsChanged: _updateSettings,
      ),
    );
  }
}
