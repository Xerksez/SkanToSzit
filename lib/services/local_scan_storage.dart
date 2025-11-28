import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/scan_record.dart';

class LocalScanStorage {
  /// Robimy klucz na podstawie stringa (np. 'yard', 'containers')
  static String _keyForMode(String modeKey) =>
      'scan_records_$modeKey';

  /// Zapisuje listę rekordów dla danego trybu (plac / kontenery) do pamięci.
  static Future<void> saveRecords(
    String modeKey,
    List<ScanRecord> records,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final list = records
        .map((r) => {
              'timestamp': r.timestamp.toIso8601String(),
              'vin': r.vin,
              'lot': r.lot,
              'place': r.place,
              'sent': r.sent,
            })
        .toList();

    await prefs.setString(_keyForMode(modeKey), jsonEncode(list));
  }

  /// Wczytuje rekordy z pamięci dla danego trybu.
  static Future<List<ScanRecord>> loadRecords(String modeKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyForMode(modeKey));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map<ScanRecord>((item) {
        final map = item as Map<String, dynamic>;
        return ScanRecord(
          timestamp:
              DateTime.tryParse(map['timestamp'] as String? ?? '') ??
                  DateTime.now(),
          vin: map['vin'] as String? ?? '',
          lot: map['lot'] as String? ?? '0',
          place: map['place'] as String? ?? '',
          sent: map['sent'] as bool? ?? false,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
