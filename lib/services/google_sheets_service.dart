import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scan_record.dart';
import 'google_auth_service.dart';

class SheetsSendResult {
  final bool success;
  final String message;

  SheetsSendResult(this.success, this.message);
}

class SheetsTarget {
  final String spreadsheetId;
  final String sheetName;

  SheetsTarget({
    required this.spreadsheetId,
    required this.sheetName,
  });
}

class GoogleSheetsService {
  final GoogleAuthService _authService = GoogleAuthService();

  static const _keySpreadsheetId = 'gs_spreadsheet_id';
  static const _keySheetName = 'gs_sheet_name';

  // ZAPIS konfiguracji (wybrany plik + zakładka)
  Future<void> saveTarget(SheetsTarget target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySpreadsheetId, target.spreadsheetId);
    await prefs.setString(_keySheetName, target.sheetName);
  }

  // ODCZYT konfiguracji
  Future<SheetsTarget?> loadTarget() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_keySpreadsheetId);
    final name = prefs.getString(_keySheetName);
    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      return null;
    }
    return SheetsTarget(spreadsheetId: id, sheetName: name);
  }

  /// Wysyłanie rekordów bezpośrednio do Google Sheets API (append do zakładki).
  Future<SheetsSendResult> sendRecords(List<ScanRecord> records) async {
    final target = await loadTarget();
    if (target == null) {
      return SheetsSendResult(
        false,
        'Nie skonfigurowano Google Sheet. Ustaw plik i zakładkę w ustawieniach.',
      );
    }

    if (records.isEmpty) {
      return SheetsSendResult(false, 'Brak danych do wysłania.');
    }

    // Upewniamy się, że jesteśmy zalogowani i mamy token
    final accessToken = await _authService.getAccessToken();
    if (accessToken == null) {
      return SheetsSendResult(
        false,
        'Nie udało się zalogować do Google. Spróbuj ponownie.',
      );
    }

    try {
      // Przygotuj values: [[timestamp, vin, lot, place], ...]
      final values = records.map((r) {
        return [
          r.timestamp.toIso8601String(),
          r.vin,
          r.lot,
          r.place,
        ];
      }).toList();

      final spreadsheetId = target.spreadsheetId;
      final range = Uri.encodeComponent('${target.sheetName}!A1');

      final uri = Uri.parse(
          'https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/$range:append'
          '?valueInputOption=RAW&insertDataOption=INSERT_ROWS');

      final body = jsonEncode({
        'values': values,
      });

      final resp = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (resp.statusCode != 200) {
        return SheetsSendResult(
          false,
          'Błąd HTTP ${resp.statusCode}: ${resp.body}',
        );
      }

      final decoded = jsonDecode(resp.body);

      // Próbujemy wyciągnąć, ile wierszy dodano
      final updates = decoded['updates'];
      final updatedRows = updates != null ? updates['updatedRows'] : null;
      final inserted = updatedRows ?? values.length;

      return SheetsSendResult(true, 'Wysłano $inserted wierszy.');
    } catch (e) {
      return SheetsSendResult(false, 'Wyjątek przy wysyłaniu: $e');
    }
  }
}
