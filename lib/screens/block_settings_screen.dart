import 'package:flutter/material.dart';

import '../config/scan_settings.dart';  // ScanMode, LotDirection, RowDirection
import '../models/block_config.dart';

class BlockSettingsScreen extends StatefulWidget {
  final ScanMode mode;

  const BlockSettingsScreen({super.key, required this.mode});

  @override
  State<BlockSettingsScreen> createState() => _BlockSettingsScreenState();
}

class _BlockSettingsScreenState extends State<BlockSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _startPlaceController =
      TextEditingController(text: 'AA001');

  // Dla kontenerów: np. "T4"
  final TextEditingController _startLotLabelController =
      TextEditingController(text: 'T4');

  // Długość rzędu – dla placu; dla kontenerów zawsze 7.
  int _rowLength = 7;

  // dostępne preset-y długości rzędu na placu
  final List<int> presetRowLengths = [7, 3, 2];

  // Czy użytkownik (na placu) wybrał "inna" i wpisuje własną wartość?
  bool _useCustomRowLength = false;
  final TextEditingController _customRowLengthController =
      TextEditingController();

  LotDirection _lotDirection = LotDirection.up;

  @override
  void dispose() {
    _startPlaceController.dispose();
    _startLotLabelController.dispose();
    _customRowLengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isYard = widget.mode == ScanMode.yard;

    // Dla kontenerów zawsze 7 – na wszelki wypadek trzymamy to tutaj.
    if (!isYard) {
      _rowLength = 7;
      _useCustomRowLength = false;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isYard ? 'Ustawienia bloku (Plac)' : 'Ustawienia lotu (Kontenery)',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                isYard
                    ? 'Konfiguracja bloku na placu'
                    : 'Konfiguracja lotu / bloku przy kontenerach',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Startowa pozycja (AA008 itp.)
              TextFormField(
                controller: _startPlaceController,
                decoration: InputDecoration(
                  labelText: isYard
                      ? 'Startowa pozycja (np. AA008)'
                      : 'Pozycja w rzędzie w locie (np. AA008)',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Podaj startową pozycję (np. AA008)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Dodatkowe rzeczy dla kontenerów: lot + kierunek lotów
              if (!isYard) ...[
                TextFormField(
                  controller: _startLotLabelController,
                  decoration: const InputDecoration(
                    labelText: 'Startowy lot (np. T4)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Kierunek lotów:'),
                    const SizedBox(width: 12),
                    DropdownButton<LotDirection>(
                      value: _lotDirection,
                      items: const [
                        DropdownMenuItem(
                          value: LotDirection.up,
                          child: Text('W górę (T4 → T5 → T6)'),
                        ),
                        DropdownMenuItem(
                          value: LotDirection.down,
                          child: Text('W dół (T6 → T5 → T4)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _lotDirection = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Długość rzędu (liczba miejsc w locie) jest zawsze 7.\n'
                  'Jeśli w locie stoi tylko 6 aut, po zeskanowaniu 6\n'
                  'użyj przycisku „Następny rząd”.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
              ],

              // Długość rzędu wybieramy TYLKO dla placu (7 / 3 / 2 / Inne)
              if (isYard) ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text('Długość rzędu (auta w rzędzie):'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _useCustomRowLength ? -1 : _rowLength,
                        items: [
                          ...presetRowLengths.map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(v.toString()),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: -1, // oznacza "Inne"
                            child: Text('Inne'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            if (val == -1) {
                              _useCustomRowLength = true;
                              // nie zmieniamy _rowLength, dopóki user nie wpisze
                            } else {
                              _useCustomRowLength = false;
                              _rowLength = val;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_useCustomRowLength) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _customRowLengthController,
                    decoration: const InputDecoration(
                      labelText: 'Własna długość rzędu (np. 5, 10...)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (!_useCustomRowLength) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Podaj długość rzędu';
                      }
                      final parsed = int.tryParse(value.trim());
                      if (parsed == null || parsed <= 0) {
                        return 'Długość rzędu musi być dodatnią liczbą całkowitą';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      final parsed = int.tryParse(value.trim());
                      if (parsed != null && parsed > 0) {
                        _rowLength = parsed;
                      }
                    },
                  ),
                ],
              ],

              const SizedBox(height: 24),

              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Zapisz ustawienia'),
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    // Jeśli plac + "inna", upewnij się że mamy prawidłowe _rowLength
                    if (isYard && _useCustomRowLength) {
                      final parsed = int.tryParse(
                          _customRowLengthController.text.trim());
                      if (parsed == null || parsed <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Podaj poprawną długość rzędu (liczba > 0).'),
                          ),
                        );
                        return;
                      }
                      _rowLength = parsed;
                    }

                    final config = BlockConfig(
                      startPlace: _startPlaceController.text.trim(),
                      rowLength: _rowLength,
                      rowDirection: RowDirection.forward,
                      startLotLabel: isYard
                          ? null
                          : _startLotLabelController.text.trim().isEmpty
                              ? null
                              : _startLotLabelController.text.trim(),
                      lotDirection: isYard ? null : _lotDirection,
                    );
                    Navigator.of(context).pop(config);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
