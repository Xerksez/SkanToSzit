/// Tryb skanowania – plac lub kontenery.
enum ScanMode { yard, container }

/// Kierunek w rzędzie – na razie zawsze forward, ale zostawiamy na przyszłość.
enum RowDirection { forward, backward }

/// Kierunek numeracji lotów (np. T4, T5, T6 w górę albo w dół).
enum LotDirection { up, down }

/// Konfiguracja bloku / lotu.
class BlockConfig {
  /// Np. "AA008" / "AA001"
  final String startPlace;

  /// Ile pozycji w jednym rzędzie (np. 7)
  final int rowLength;

  /// Kierunek skanowania w obrębie rzędu (na razie zawsze forward).
  final RowDirection rowDirection;

  /// Dla kontenerów: np. "T4".
  final String? startLotLabel;

  /// Kierunek numeracji lotów (T4→T5 / T6→T5 itd.).
  final LotDirection? lotDirection;

  const BlockConfig({
    required this.startPlace,
    required this.rowLength,
    required this.rowDirection,
    this.startLotLabel,
    this.lotDirection,
  });

  @override
  String toString() =>
      'startPlace=$startPlace, rowLength=$rowLength, '
      'lot=$startLotLabel, lotDir=$lotDirection';
}
