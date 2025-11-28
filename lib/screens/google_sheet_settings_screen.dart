import 'package:flutter/material.dart';

import '../services/google_sheets_service.dart';

class GoogleSheetSettingsScreen extends StatefulWidget {
  const GoogleSheetSettingsScreen({super.key});

  @override
  State<GoogleSheetSettingsScreen> createState() =>
      _GoogleSheetSettingsScreenState();
}

class _GoogleSheetSettingsScreenState
    extends State<GoogleSheetSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sheetUrlOrIdController = TextEditingController();
  final _sheetNameController = TextEditingController(text: 'Arkusz1');

  final GoogleSheetsService _sheetsService = GoogleSheetsService();

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final target = await _sheetsService.loadTarget();
    if (target != null && mounted) {
      setState(() {
        _sheetUrlOrIdController.text = target.spreadsheetId;
        _sheetNameController.text = target.sheetName;
      });
    }
  }

  String _extractSpreadsheetId(String input) {
    input = input.trim();
    // Jeśli użytkownik wkleił cały link
    final reg = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)');
    final m = reg.firstMatch(input);
    if (m != null) {
      return m.group(1)!;
    }
    // W przeciwnym razie traktujemy to jako czyste ID
    return input;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final rawId = _sheetUrlOrIdController.text.trim();
    final id = _extractSpreadsheetId(rawId);
    final name = _sheetNameController.text.trim();

    if (id.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Podaj ID/URL pliku i nazwę arkusza.'),
        ),
      );
      return;
    }

    final target = SheetsTarget(
      spreadsheetId: id,
      sheetName: name,
    );

    await _sheetsService.saveTarget(target);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zapisano konfigurację Google Sheet.')),
    );

    Navigator.of(context).pop(); // wróć np. na ekran główny
  }

  @override
  void dispose() {
    _sheetUrlOrIdController.dispose();
    _sheetNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Połączenie z Google Sheets'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Najpierw wybierz plik Google Sheets i zakładkę,\n'
                'do której mają trafiać skany.\n\n'
                'Upewnij się, że jesteś zalogowany w Google tym samym kontem,\n'
                'które ma dostęp do pliku.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sheetUrlOrIdController,
                decoration: const InputDecoration(
                  labelText: 'Link do Google Sheets lub ID pliku',
                  hintText:
                      'Wklej cały link (https://docs.google.com/...) albo samo ID',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Podaj link lub ID pliku.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sheetNameController,
                decoration: const InputDecoration(
                  labelText: 'Nazwa arkusza (zakładki, np. Arkusz1)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Podaj nazwę arkusza.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Zapisz i używaj tego arkusza'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
