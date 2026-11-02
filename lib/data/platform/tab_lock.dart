import 'web/web_tab_lock_stub.dart' if (dart.library.js_interop) 'web/web_tab_lock.dart' as impl;

/// Merkt sich, dass dieser Tab die Sperre schon hält (#137). Web Locks sind nicht wiedereintrittsfähig: Eine
/// zweite Anfrage gegen die eigene, noch gehaltene Sperre liefert „nicht verfügbar“. Nach „Alle lokalen Daten
/// löschen“, „Zurücksetzen“ oder „Konto löschen“ fordert die neue Passwortabfrage die Sperre aber erneut an und
/// meldete dann fälschlich „schon geöffnet“. Gemerkt wird nur ein Erfolg; scheitert die Anfrage (anderer Tab,
/// Fehler), fragt der nächste Aufruf wieder an. Gleichzeitige Aufrufe teilen sich eine laufende Anfrage.
class TabLockGuard {
  TabLockGuard(this._request);

  final Future<bool> Function() _request;
  bool _held = false;
  Future<bool>? _pending;

  Future<bool> acquire() {
    if (_held) return Future<bool>.value(true);
    return _pending ??= _request().then((ok) {
      _held = ok;
      _pending = null;
      return ok;
    }, onError: (Object e, StackTrace s) {
      _pending = null;
      return Future<bool>.error(e, s);
    });
  }
}

final TabLockGuard _guard = TabLockGuard(impl.acquireWebTabLock);

/// Siehe `acquireWebTabLock`: nur im Browser wirksam. Wiederholte Aufrufe im selben Tab laufen über
/// [TabLockGuard].
Future<bool> acquireTabLock() => _guard.acquire();

/// Siehe `isWebEmbedded`: nur im Browser wirksam.
bool isEmbedded() => impl.isWebEmbedded();
