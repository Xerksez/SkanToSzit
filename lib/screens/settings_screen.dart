import 'package:flutter/material.dart';
import '../config/scan_settings.dart';

class SettingsScreen extends StatefulWidget {
  final ScanSettings initialSettings;
  final ValueChanged<ScanSettings> onSaved;

  const SettingsScreen({
    super.key,
    required this.initialSettings,
    required this.onSaved,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _continuousScan;
  late bool _soundEnabled;
  late bool _hapticEnabled;
  late bool _torchInitiallyOn;

  @override
  void initState() {
    super.initState();
    _continuousScan = widget.initialSettings.continuousScan;
    _soundEnabled = widget.initialSettings.soundEnabled;
    _hapticEnabled = widget.initialSettings.hapticEnabled;
    _torchInitiallyOn = widget.initialSettings.torchInitiallyOn;
  }

  void _save() {
    final newSettings = widget.initialSettings.copyWith(
      continuousScan: _continuousScan,
      soundEnabled: _soundEnabled,
      hapticEnabled: _hapticEnabled,
      torchInitiallyOn: _torchInitiallyOn,
    );
    widget.onSaved(newSettings);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia aplikacji'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Tryb ciągłego skanowania'),
            subtitle: const Text(
                'Włączone: skanuje cały czas.\nWyłączone: skan tylko po kliknięciu przycisku.'),
            value: _continuousScan,
            onChanged: (value) {
              setState(() {
                _continuousScan = value;
              });
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Dźwięk po udanym/błędnym skanie'),
            value: _soundEnabled,
            onChanged: (value) {
              setState(() {
                _soundEnabled = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Wibracja / Haptic feedback'),
            value: _hapticEnabled,
            onChanged: (value) {
              setState(() {
                _hapticEnabled = value;
              });
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Latarka domyślnie włączona'),
            subtitle: const Text('Przy starcie skanowania latarka ma być ON.'),
            value: _torchInitiallyOn,
            onChanged: (value) {
              setState(() {
                _torchInitiallyOn = value;
              });
            },
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Zapisz ustawienia'),
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}
