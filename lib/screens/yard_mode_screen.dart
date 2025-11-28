import 'package:flutter/material.dart';
import '../config/scan_settings.dart';
import '../models/block_config.dart';
import 'block_settings_screen.dart';
import 'scan_screen.dart';

class YardModeScreen extends StatefulWidget {
  final ScanSettings settings;

  const YardModeScreen({super.key, required this.settings});

  @override
  State<YardModeScreen> createState() => _YardModeScreenState();
}

class _YardModeScreenState extends State<YardModeScreen> {
  BlockConfig? _config;

  void _openSettings() async {
    final config = await Navigator.of(context).push<BlockConfig>(
      MaterialPageRoute(
        builder: (_) => BlockSettingsScreen(mode: ScanMode.yard),
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
        const SnackBar(content: Text('Najpierw ustaw blok (Ustawienia).')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          mode: ScanMode.yard,
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
        title: const Text('Tryb: Plac'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Plac – skanowanie bloków (np. AA001–AA007, AB001–AB007 itd.)',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Aktualne ustawienia bloku'),
              subtitle: Text(cfgText),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.tune),
              label: const Text('Ustawienia bloku'),
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
