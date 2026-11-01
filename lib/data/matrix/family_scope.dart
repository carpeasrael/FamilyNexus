/// Merkt sich, zu welchem Familienraum die Zustände des Gateways gehören (#140).
///
/// [generation] zählt jeden Wechsel und jedes [clear], fällt nie zurück: Abläufe über ein `await` hinweg verwerfen
/// ihr Ergebnis, wenn sich die Generation geändert hat, auch nach einem Wechsel A → B → A.
class FamilyScope {
  String? _roomId;
  int _generation = 0;

  /// Raum, dem die Zustände gerade gehören; `null` = keine Familie.
  String? get roomId => _roomId;

  int get generation => _generation;

  /// Übernimmt [roomId]. `true`, wenn sich der Raum geändert hat: Die Zustände des bisherigen gelten nicht mehr.
  bool enter(String? roomId) {
    if (roomId == _roomId) return false;
    _roomId = roomId;
    _generation++;
    return true;
  }

  /// Abmelden: kein Raum mehr, die Generation zählt weiter.
  void clear() {
    _roomId = null;
    _generation++;
  }
}
