import 'package:flutter/material.dart';
import '../config/scan_settings.dart';
import '../models/block_config.dart';
import 'block_settings_screen.dart';
import 'scan_screen.dart';

class ContainerModeScreen extends StatefulWidget {
  final ScanSettings settings;

  const ContainerModeScreen({super.key, required this.settings});

  @override
  State<ContainerModeScreen> createState() => _ContainerModeScreenState();
}

class _ContainerModeScreenState extends State<ContainerModeScreen> {
  BlockConfig? _config;

  void _openSettings() async {
    final config = await Navigator.of(context).push<BlockConfig>(
      MaterialPageRoute(
        builder: (_) => BlockSettingsScreen(mode: ScanMode.container),
      ),
    );
    if (config != null && mounted) {
      setState(() {
        _config = config;
      });
    }
  }

  void _startScan() {
    if (_config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Najpierw ustaw lot / układ (Ustawienia).')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          mode: ScanMode.container,
          blockConfig: _config!,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfgText = _config == null ? 'Nie ustawiono' : _config.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tryb: Kontenery'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Kontenery – skanowanie lotów (T4, T5, T6...),\n'
              'auta w lotach po 7 miejsc, czasem 6 aut.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Aktualne ustawienia lotu / bloku'),
              subtitle: Text(cfgText),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.tune),
              label: const Text('Ustawienia lotu / bloku'),
              onPressed: _openSettings,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Rozpocznij skanowanie'),
              onPressed: _startScan,
            ),
          ],
        ),
      ),
    );
  }
}
