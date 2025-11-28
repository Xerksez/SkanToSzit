import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';

import '../config/scan_settings.dart';
import '../models/block_config.dart';
import '../models/scan_record.dart';
import '../services/google_sheets_service.dart';
import '../services/local_scan_storage.dart';

class ScanScreen extends StatefulWidget {
  final ScanMode mode;
  final BlockConfig blockConfig;
  final ScanSettings settings;

  const ScanScreen({
    super.key,
    required this.mode,
    required this.blockConfig,
    required this.settings,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // który rząd (0,1,2...)
  int _rowIndex = 0;

  // indeks pozycji w rzędzie (0..rowLen-1)
  int _posIndex = 0;

  // kierunek skanowania w TYM rzędzie:
  // true  -> 1→N (np. 001→007)
  // false -> N→1 (np. 007→001)
  bool _ascending = true;

  bool _cameraActive = false;

  final List<ScanRecord> _records = [];

  late MobileScannerController _scannerController;
  bool _torchOn = false;

  // anty-double-scan
  DateTime? _lastScanTime;

  // zielone mignięcie
  bool _flashGreen = false;

  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  bool _sending = false;
  String? _lastSendStatus;

  // dane startowej pozycji z konfiguracji
  String? _basePrefix;
  int? _basePrefixIndex;
  int? _baseNumber;
  int _numberWidth = 3;

  @override
  void initState() {
    super.initState();

    // BLOKADA auto-obracania na tym ekranie – pion
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    _torchOn = widget.settings.torchInitiallyOn;
    _scannerController = MobileScannerController(
      torchEnabled: _torchOn,
      facing: CameraFacing.back,
    );

    _initBasePlace();
    _loadRecords(); // wczytaj poprzednie skany z pamięci
  }

  @override
  void dispose() {
    // Przywracamy normalne orientacje w całej aplikacji
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _scannerController.dispose();
    super.dispose();
  }

 Future<void> _loadRecords() async {
  // używamy nazwy enuma, np. 'yard' / 'containers'
  final loaded = await LocalScanStorage.loadRecords(widget.mode.name);
  if (!mounted) return;
  setState(() {
    _records
      ..clear()
      ..addAll(loaded);
  });
}

Future<void> _saveRecords() async {
  await LocalScanStorage.saveRecords(widget.mode.name, _records);
}

  void _initBasePlace() {
    final sp = widget.blockConfig.startPlace.trim().toUpperCase();
    final regex = RegExp(r'^([A-Z]+)(\d+)$');
    final m = regex.firstMatch(sp);
    if (m == null) {
      _basePrefix = 'AA';
      _basePrefixIndex = _lettersToIndex('AA');
      _baseNumber = 1;
      _numberWidth = 2;
      return;
    }
    _basePrefix = m.group(1)!;
    _basePrefixIndex = _lettersToIndex(_basePrefix!);
    final numPart = m.group(2)!;
    _numberWidth = numPart.length;
    _baseNumber = int.tryParse(numPart) ?? 1;
  }

  // AA, AB, ..., AZ, BA, BB, ...
  int _lettersToIndex(String letters) {
    int idx = 0;
    for (final code in letters.codeUnits) {
      if (code < 65 || code > 90) continue;
      idx = idx * 26 + (code - 64); // A=1
    }
    return idx;
  }

  String _indexToLetters(int index) {
    if (index <= 0) return 'A';
    int n = index;
    final chars = <String>[];
    while (n > 0) {
      final rem = (n - 1) % 26;
      chars.add(String.fromCharCode(65 + rem));
      n = (n - 1) ~/ 26;
    }
    return chars.reversed.join();
  }

  String get _currentPlaceLabel {
    if (_basePrefixIndex == null || _baseNumber == null) return '???';

    final rowPrefixIndex = _basePrefixIndex! + _rowIndex;
    final prefix = _indexToLetters(rowPrefixIndex);

    final rowLen = widget.blockConfig.rowLength;
    int offset;
    if (_ascending) {
      // rząd w górę: 001,002,...,007
      offset = _posIndex;
    } else {
      // rząd w dół: 007,006,...,001
      offset = rowLen - 1 - _posIndex;
    }
    if (offset < 0) offset = 0;
    if (offset >= rowLen) offset = rowLen - 1;

    final num = _baseNumber! + offset;
    return '$prefix${num.toString().padLeft(_numberWidth, '0')}';
  }

  String get _currentLotLabel {
    if (widget.mode == ScanMode.yard) return '0';
    final start = widget.blockConfig.startLotLabel;
    if (start == null || start.trim().isEmpty) return '0';
    final s = start.trim().toUpperCase();
    final regex = RegExp(r'^([A-Z]+)(\d+)$');
    final m = regex.firstMatch(s);
    if (m == null) return s;

    final prefix = m.group(1)!;
    final numPart = m.group(2)!;
    final base = int.tryParse(numPart) ?? 0;

    int current;
    if (widget.blockConfig.lotDirection == LotDirection.down) {
      current = base - _rowIndex;
    } else {
      current = base + _rowIndex;
    }
    return '$prefix$current';
  }

  void _handleBarcodeCapture(BarcodeCapture capture) {
    if (!_cameraActive) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null) {
        _handleScan(raw);
        break;
      }
    }
  }

  void _handleScan(String rawValue) {
    final now = DateTime.now();

    // długa przerwa: 2 sekundy
    if (_lastScanTime != null &&
        now.difference(_lastScanTime!) < const Duration(milliseconds: 2000)) {
      return;
    }
    _lastScanTime = now;

    final vin = rawValue.trim().toUpperCase();
    final vinRegExp = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$'); // VIN bez I,O,Q

    if (!vinRegExp.hasMatch(vin)) {
      if (widget.settings.soundEnabled) {
        SystemSound.play(SystemSoundType.alert);
      }
      if (widget.settings.hapticEnabled) {
        Vibration.hasVibrator().then((ok) {
          if (ok ?? false) {
            Vibration.vibrate(duration: 120, amplitude: 255);
          } else {
            HapticFeedback.heavyImpact();
          }
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Błędny VIN – sprawdź skan.')),
        );
      }
      return;
    }

    final place = _currentPlaceLabel;
    final lot = _currentLotLabel;

    if (widget.settings.soundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
    if (widget.settings.hapticEnabled) {
      Vibration.hasVibrator().then((ok) {
        if (ok ?? false) {
          Vibration.vibrate(duration: 70, amplitude: 180);
        } else {
          HapticFeedback.mediumImpact();
        }
      });
    }

    final rec = ScanRecord(
      timestamp: now,
      vin: vin,
      lot: lot,
      place: place,
      sent: false,
    );

    setState(() {
      _records.add(rec);
      _advancePositionSnake();
      _flashGreen = true;
    });

    _saveRecords(); // zapisz do pamięci

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() => _flashGreen = false);
      }
    });
  }

  /// Wężyk:
  /// rząd 0 (ascending=true): 1→2→…→N
  /// rząd 1 (ascending=false): N→…→2→1
  /// rząd 2: 1→N
  void _advancePositionSnake() {
    final rowLen = widget.blockConfig.rowLength;
    _posIndex++;
    if (_posIndex >= rowLen) {
      _posIndex = 0;
      _rowIndex++;
      _ascending = !_ascending;
    }
  }

  /// Ręczny "Następny rząd" – taki sam jak automatyczne przejście na koniec rzędu.
  void _nextRowManually() {
    if (widget.settings.hapticEnabled) {
      Vibration.hasVibrator().then((ok) {
        if (ok ?? false) {
          Vibration.vibrate(duration: 40, amplitude: 120);
        }
      });
    }
    setState(() {
      _posIndex = 0;
      _rowIndex++;
      _ascending = !_ascending;
    });
    _saveRecords();
  }

  void _toggleTorch() {
    setState(() => _torchOn = !_torchOn);
    _scannerController.toggleTorch();
  }

  Future<void> _sendToGoogleSheet() async {
    // wysyłamy TYLKO rekordy bez sent=true
    final toSend = _records.where((r) => !r.sent).toList();
    if (toSend.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brak nowych danych do wysłania.')),
        );
      }
      return;
    }

    setState(() {
      _sending = true;
      _lastSendStatus = null;
    });

    final result = await _sheetsService.sendRecords(toSend);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        for (final r in toSend) {
          r.sent = true;
        }
      });
      _saveRecords();
    }

    setState(() {
      _sending = false;
      _lastSendStatus = result.message;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  void _editRecordVin(ScanRecord rec) {
    if (rec.sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ten rekord jest już wysłany.')),
      );
      return;
    }

    final controller = TextEditingController(text: rec.vin);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edytuj VIN (${rec.place})'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nowy VIN (17 znaków)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () {
              final newVin = controller.text.trim().toUpperCase();
              final vinRegExp = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');
              if (!vinRegExp.hasMatch(newVin)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nowy VIN jest niepoprawny.'),
                  ),
                );
                return;
              }

              setState(() {
                final idx = _records.indexOf(rec);
                if (idx != -1) {
                  _records[idx] = ScanRecord(
                    timestamp: _records[idx].timestamp,
                    vin: newVin,
                    lot: _records[idx].lot,
                    place: _records[idx].place,
                    sent: _records[idx].sent,
                  );
                }
              });

              _saveRecords();
              Navigator.of(ctx).pop();
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  void _deleteRecord(ScanRecord rec) {
    if (rec.sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie można usunąć wysłanego rekordu.')),
      );
      return;
    }
    setState(() {
      _records.remove(rec);
    });
    _saveRecords();
  }

  void _toggleCamera() {
    setState(() {
      _cameraActive = !_cameraActive;
    });
  }

  void _editCurrentPosition() {
    final controller = TextEditingController(text: _currentPlaceLabel);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zmień aktualną pozycję'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Np. AA001, AB007',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim().toUpperCase();
              final regex = RegExp(r'^([A-Z]+)(\d+)$');
              final m = regex.firstMatch(text);
              if (m == null ||
                  _basePrefixIndex == null ||
                  _baseNumber == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Niepoprawny format pozycji.')),
                );
                return;
              }
              final prefix = m.group(1)!;
              final numPart = m.group(2)!;
              final newPrefixIndex = _lettersToIndex(prefix);
              final newNum = int.tryParse(numPart) ?? _baseNumber!;

              final newRowIndex = newPrefixIndex - _basePrefixIndex!;
              if (newRowIndex < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pozycja jest przed startową.'),
                  ),
                );
                return;
              }

              final rowLen = widget.blockConfig.rowLength;
              var offset = newNum - _baseNumber!;
              if (offset < 0) offset = 0;
              if (offset >= rowLen) offset = rowLen - 1;

              setState(() {
                _rowIndex = newRowIndex;
                _posIndex = offset;
                // kierunku (_ascending) nie tykamy
              });

              _saveRecords();
              Navigator.of(ctx).pop();
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  /// Zmiana kierunku – TYLKO strzałka i sposób liczenia KOLEJNYCH pozycji.
  /// Aktualna pozycja (np. AH003) ma zostać taka sama.
  void _toggleDirection() {
    final rowLen = widget.blockConfig.rowLength;
    if (rowLen <= 0) {
      setState(() {
        _ascending = !_ascending;
      });
      return;
    }

    // obliczamy offset (0..rowLen-1) niezależnie od obecnego kierunku
    int offset;
    if (_ascending) {
      offset = _posIndex;
    } else {
      offset = rowLen - 1 - _posIndex;
    }
    if (offset < 0) offset = 0;
    if (offset >= rowLen) offset = rowLen - 1;

    setState(() {
      _ascending = !_ascending;
      // tak ustawiamy _posIndex, żeby _currentPlaceLabel się nie zmienił
      if (_ascending) {
        _posIndex = offset;
      } else {
        _posIndex = rowLen - 1 - offset;
      }
    });
    _saveRecords();
  }

  @override
  Widget build(BuildContext context) {
    final isYard = widget.mode == ScanMode.yard;
    final recordsReversed = _records.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isYard ? 'Skanowanie – plac' : 'Skanowanie – kontenery'),
      ),
      body: Column(
        children: [
          // Pasek z aktualną pozycją + strzałką kierunku
          Container(
            width: double.infinity,
            color: Colors.blueGrey.shade50,
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aktualna pozycja:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        InkWell(
                          onTap: _editCurrentPosition,
                          child: Text(
                            _currentPlaceLabel,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: Icon(
                            _ascending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 18,
                          ),
                          onPressed: _toggleDirection,
                        ),
                      ],
                    ),
                    if (!isYard) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Lot: $_currentLotLabel',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _toggleCamera,
                  child: Text(_cameraActive ? 'Ukryj kamerę' : 'Skanuj'),
                ),
              ],
            ),
          ),

          // Rząd przycisków: Następny rząd, latarka, Wyślij
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _nextRowManually,
                  child: const Text('Następny rząd'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _toggleTorch,
                  icon: Icon(
                    _torchOn ? Icons.flashlight_on : Icons.flashlight_off,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _sending ? null : _sendToGoogleSheet,
                  child: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Wyślij'),
                ),
              ],
            ),
          ),

          if (_lastSendStatus != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                _lastSendStatus!,
                style: const TextStyle(fontSize: 11),
              ),
            ),

          // Kamera – normalnie, bez obrotu, celownik pionowy
          if (_cameraActive)
            Expanded(
              flex: 4,
              child: Container(
                margin: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueGrey),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: _handleBarcodeCapture,
                      ),
                      // lekkie przyciemnienie
                      IgnorePointer(
                        child: Container(
                          color: Colors.black.withOpacity(0.10),
                        ),
                      ),
                      // CELOWNIK PIONOWY (wysoki, wąski prostokąt = naklejka VIN bokiem)
                      IgnorePointer(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 0.4,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                color: Colors.black.withOpacity(0.10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_flashGreen)
                        IgnorePointer(
                          child: Container(
                            color: Colors.green.withOpacity(0.4),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Lista skanów (z ptaszkiem przy wysłanych)
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade100,
              ),
              child: recordsReversed.isEmpty
                  ? const Center(
                      child: Text(
                        'Brak zeskanowanych pozycji.',
                        style: TextStyle(fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: recordsReversed.length,
                      itemBuilder: (context, index) {
                        final rec = recordsReversed[index];
                        return ListTile(
                          dense: true,
                          leading: rec.sent
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                )
                              : const Icon(
                                  Icons.radio_button_unchecked,
                                  size: 20,
                                ),
                          title: Text('Miejsce: ${rec.place}'),
                          subtitle: Text(
                            widget.mode == ScanMode.yard
                                ? 'VIN: ${rec.vin}\n${rec.formattedTimestamp}'
                                : 'VIN: ${rec.vin}\n${rec.formattedTimestamp} | Lot: ${rec.lot}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () => _editRecordVin(rec),
                          trailing: rec.sent
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteRecord(rec),
                                ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
