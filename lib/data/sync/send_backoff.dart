/// Wartezeit zwischen Sendeversuchen nach Fehlern (#132): verdoppelt sich von [base] bis [max] und gilt
/// für Anstöße, die der Versuch selbst erzeugt (Fehlerereignisse des SDK lösen über den Gateway immer
/// wieder einen neuen Anstoß aus). Ausdrückliche Anstöße (lokale Änderung, Beitritt) und der periodische
/// Timer sind davon nicht betroffen.
class SendBackoff {
  SendBackoff({
    DateTime Function()? clock,
    this.base = const Duration(seconds: 5),
    this.max = const Duration(seconds: 60),
  }) : _clock = clock ?? DateTime.now;

  final Duration base;
  final Duration max;
  final DateTime Function() _clock;

  int _failures = 0;
  DateTime? _retryAfter;
  Object? _signature;

  /// Anzahl der Fehler seit dem letzten Erfolg.
  int get failures => _failures;

  /// Ob Anstöße aus dem Gateway gerade ignoriert werden.
  bool get blocked {
    final t = _retryAfter;
    return t != null && _clock().isBefore(t);
  }

  /// Ein Durchlauf ist gescheitert (höchstens einmal je Durchlauf aufrufen).
  void failure() {
    _failures++;
    final factor = 1 << (_failures - 1).clamp(0, 20);
    final wait = base * factor;
    _retryAfter = _clock().add(wait > max ? max : wait);
  }

  /// Alles Ausstehende wurde gesendet.
  void success() => reset();

  void reset() {
    _failures = 0;
    _retryAfter = null;
  }

  /// `true`, wenn sich [signature] seit dem letzten Aufruf geändert hat (Anmeldung, Wiederverbindung,
  /// Konto- oder Familienwechsel). Dann sofort wieder senden: das Fenster wird zurückgesetzt.
  bool changed(Object? signature) {
    final c = _signature != signature;
    _signature = signature;
    if (c) reset();
    return c;
  }
}
