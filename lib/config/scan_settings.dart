import 'package:shared_preferences/shared_preferences.dart';

class ScanSettings {
  final bool continuousScan; // true = cały czas, false = tylko po kliknięciu
  final bool soundEnabled;
  final bool hapticEnabled;
  final bool torchInitiallyOn;

  const ScanSettings({
    this.continuousScan = true,
    this.soundEnabled = true,
    this.hapticEnabled = true,
    this.torchInitiallyOn = false,
  });

  ScanSettings copyWith({
    bool? continuousScan,
    bool? soundEnabled,
    bool? hapticEnabled,
    bool? torchInitiallyOn,
  }) {
    return ScanSettings(
      continuousScan: continuousScan ?? this.continuousScan,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      torchInitiallyOn: torchInitiallyOn ?? this.torchInitiallyOn,
    );
  }

  static const _keyContinuous = 'settings_continuous_scan';
  static const _keySound = 'settings_sound_enabled';
  static const _keyHaptic = 'settings_haptic_enabled';
  static const _keyTorch = 'settings_torch_initially_on';

  static Future<ScanSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ScanSettings(
      continuousScan: prefs.getBool(_keyContinuous) ?? true,
      soundEnabled: prefs.getBool(_keySound) ?? true,
      hapticEnabled: prefs.getBool(_keyHaptic) ?? true,
      torchInitiallyOn: prefs.getBool(_keyTorch) ?? false,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyContinuous, continuousScan);
    await prefs.setBool(_keySound, soundEnabled);
    await prefs.setBool(_keyHaptic, hapticEnabled);
    await prefs.setBool(_keyTorch, torchInitiallyOn);
  }
}
