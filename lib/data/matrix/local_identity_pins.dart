import 'dart:convert';

import '../../core/app_log.dart';
import '../../core/json_read.dart';
import '../../domain/key_value_store.dart';

/// Lokale Kopie der Identitätsvermerke (#142, E-37): Cross-Signing-Hauptschlüssel der Mitglieder je Konto, in der
/// verschlüsselten Schlüssel-Wert-Ablage dieses Geräts. Sie hat Vorrang vor den Kontodaten, die der Homeserver ändern
/// oder löschen kann; ein anderer Schlüssel bei unverändertem lokalem Vermerk ist damit eine Identitätsänderung.
///
/// Regeln:
/// * [load] liest einmal je Gateway und vor `client.init`; die eigene Matrix-ID ist dann noch unbekannt, [bind] verwirft
///   einen Eintrag eines anderen Kontos.
/// * Lesefehler der Ablage: unzuverlässig, nichts wird übernommen, geschrieben oder ersetzt (Verhalten wie vor #142).
///   Beschädigter Inhalt gilt als leer; der nächste Schreibvorgang ersetzt ihn. Ohne Ablage ist die Klasse inaktiv.
/// * [adopt] ersetzt nie einen vorhandenen Vermerk, [accept] (ausdrückliches Akzeptieren) schon.
/// * [forget] löscht bedingungslos und versiegelt, bis [bind] wieder aufgerufen wird; ein verspäteter Abgleich legt den
///   Eintrag des alten Kontos nicht neu an.
class LocalIdentityPins {
  LocalIdentityPins(this._store);

  static const String storeKey = 'identityPins';

  final KeyValueStore? _store;
  final Map<String, String> _pins = <String, String>{};
  String? _storedOwner;
  String? _owner;
  bool _loaded = false;
  bool _reliable = false;
  bool _sealed = false;
  bool _dirty = false;
  bool _errorLogged = false;
  int _generation = 0;
  Future<void>? _running;

  /// Wirksam: Ablage vorhanden, zuverlässig gelesen, an ein Konto gebunden und nicht versiegelt.
  bool get active => _store != null && _loaded && _reliable && !_sealed && _owner != null;

  /// Die lokalen Vermerke; leer, solange kein Konto gebunden ist.
  Map<String, String> get pins => _owner == null || _sealed ? const <String, String>{} : Map<String, String>.unmodifiable(_pins);

  bool get isDirty => _dirty;

  /// Der geladene Stand unabhängig von der Bindung (vom Gateway nur für Tests freigegeben).
  Map<String, String> get loadedPins => Map<String, String>.of(_pins);

  /// Liest den Eintrag, einmal je Gateway.
  Future<void> load() async {
    final store = _store;
    if (store == null || _loaded) return;
    _loaded = true;
    final Map<String, String> all;
    try {
      all = await store.readAll();
    } catch (e) {
      AppLog.e('gateway', 'Lokale Identitätsvermerke nicht lesbar; nicht überschrieben', e);
      _reliable = false;
      return;
    }
    _reliable = true;
    final raw = all[storeKey];
    if (raw == null) return;
    final decoded = _decode(raw);
    if (decoded == null) {
      AppLog.w('gateway', 'Lokale Identitätsvermerke beschädigt; werden beim nächsten Speichern ersetzt');
      return;
    }
    _storedOwner = decoded.owner;
    _pins.addAll(decoded.pins);
  }

  static ({String owner, Map<String, String> pins})? _decode(String raw) {
    try {
      final m = json.decode(raw);
      if (m is! Map<String, Object?>) return null;
      final owner = m['user_id'];
      final pins = m['pins'];
      if (owner is! String || pins is! Map<String, Object?>) return null;
      return (
        owner: owner,
        pins: <String, String>{
          for (final e in pins.entries)
            e.key: ?JsonRead.string(e.value),
        },
      );
    } on FormatException {
      return null;
    }
  }

  /// Bindet die Kopie an das eigene Konto (nach dem Anmelden bekannt). Ein Eintrag eines anderen Kontos wird verworfen.
  void bind(String userId) {
    if (_store == null || !_loaded) return;
    _sealed = false;
    if (_owner == userId) return;
    // Besitzer des Bestands: das zuvor gebundene Konto, sonst der beim Laden gelesene Eintrag (#352).
    final previous = _owner ?? _storedOwner;
    if (previous != null && previous != userId) {
      _pins.clear();
      _dirty = _reliable;
    }
    _storedOwner = null;
    _owner = userId;
  }

  /// Übernimmt einen Vermerk, den es lokal noch nicht gibt. Gibt zurück, ob er neu ist.
  bool adopt(String uid, String pub) {
    if (!active || _pins.containsKey(uid)) return false;
    _pins[uid] = pub;
    _dirty = true;
    return true;
  }

  /// Der Nutzer hat [pub] ausdrücklich akzeptiert: ersetzt einen vorhandenen Vermerk.
  void accept(String uid, String pub) {
    if (!active || _pins[uid] == pub) return;
    _pins[uid] = pub;
    _dirty = true;
  }

  /// Schreibt bei Änderungen, nie parallel; der Schnappschuss entsteht erst beim Schreiben. Ein Fehler lässt die
  /// Markierung stehen, der nächste Abgleich versucht es erneut (Log nur einmal je Fehlerzustand).
  Future<void> flushIfDirty() {
    if (!active || !_dirty) return Future<void>.value();
    final running = _running;
    if (running != null) return running;
    return _running = _write().whenComplete(() => _running = null);
  }

  Future<void> _write() async {
    final store = _store!;
    final generation = _generation;
    while (active && _dirty && generation == _generation) {
      _dirty = false;
      final snapshot = json.encode(<String, Object?>{'user_id': _owner, 'pins': <String, String>{..._pins}});
      try {
        await store.write(storeKey, snapshot);
        _errorLogged = false;
      } catch (e) {
        _dirty = true;
        if (!_errorLogged) {
          _errorLogged = true;
          AppLog.w('gateway', 'Lokale Identitätsvermerke nicht gespeichert');
        }
        return;
      }
    }
  }

  /// Abmelden oder Konto gelöscht (vom Nutzer ausgelöst): Kopie und Eintrag löschen, bedingungslos. Nicht bei einem
  /// vom Server erzwungenen Sitzungsende: Sonst könnte der Homeserver den Schutz durch ein ungültiges Token zurücksetzen.
  Future<void> forget() async {
    _generation++;
    _sealed = true;
    _pins.clear();
    _owner = null;
    _storedOwner = null;
    _dirty = false;
    final store = _store;
    if (store == null) return;
    try {
      await _running;
    } catch (_) {
      // Fehler des laufenden Schreibens sind in [_write] schon protokolliert; gelöscht wird trotzdem.
    }
    try {
      await store.delete(storeKey);
      // Die Ablage ist jetzt leer und lesbar: Schutz ab der nächsten Anmeldung wieder wirksam.
      _reliable = true;
    } catch (e) {
      AppLog.e('gateway', 'Lokale Identitätsvermerke nicht gelöscht', e);
    }
  }
}
