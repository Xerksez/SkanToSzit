/// Pojedynczy rekord skanu – format pod Excela:
/// data i godzina, VIN, lot (0 jeśli brak), miejsce.
class ScanRecord {
  final DateTime timestamp;
  final String vin;
  final String lot;
  final String place;

  /// Czy rekord został już poprawnie wysłany do Google Sheets.
  bool sent;

  ScanRecord({
    required this.timestamp,
    required this.vin,
    required this.lot,
    required this.place,
    this.sent = false,
  });

  String get formattedTimestamp {
    final y = timestamp.year.toString().padLeft(4, '0');
    final m = timestamp.month.toString().padLeft(2, '0');
    final d = timestamp.day.toString().padLeft(2, '0');
    final h = timestamp.hour.toString().padLeft(2, '0');
    final min = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }

  @override
  String toString() {
    return '$formattedTimestamp | VIN $vin | lot $lot | miejsce $place | sent=$sent';
  }
}
