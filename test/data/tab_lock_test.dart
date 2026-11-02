import 'dart:async';

import 'package:family_nexus/data/platform/tab_lock.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bildet Web Locks nach (`ifAvailable: true`, nicht wiedereintrittsfähig): Die erste Anfrage bekommt die
/// Sperre und hält sie, jede weitere liefert `false`, auch aus demselben Tab.
class _FakeWebLocks {
  bool heldElsewhere = false;
  bool held = false;
  int requests = 0;
  Object? error;

  Future<bool> request() async {
    requests++;
    if (error != null) throw error!;
    if (held || heldElsewhere) return false;
    held = true;
    return true;
  }
}

void main() {
  test('#137: Fehlerbild ohne Guard: die zweite Anfrage im selben Tab scheitert', () async {
    final locks = _FakeWebLocks();
    expect(await locks.request(), isTrue);
    expect(await locks.request(), isFalse);
  });

  test('#137: nach erneuter Passwortabfrage (zweiter Aufruf) gilt die Sperre weiter als gehalten', () async {
    final locks = _FakeWebLocks();
    final guard = TabLockGuard(locks.request);
    expect(await guard.acquire(), isTrue);
    expect(await guard.acquire(), isTrue);
    expect(locks.requests, 1, reason: 'keine zweite Anfrage gegen die eigene Sperre');
  });

  test('anderer Tab hält die Sperre: false, „Erneut versuchen“ fragt nach dem Schließen wieder an', () async {
    final locks = _FakeWebLocks()..heldElsewhere = true;
    final guard = TabLockGuard(locks.request);
    expect(await guard.acquire(), isFalse);
    expect(await guard.acquire(), isFalse);
    locks.heldElsewhere = false;
    expect(await guard.acquire(), isTrue);
    expect(locks.requests, 3);
  });

  test('gleichzeitige Aufrufe teilen sich eine Anfrage', () async {
    final gate = Completer<bool>();
    var requests = 0;
    final guard = TabLockGuard(() {
      requests++;
      return gate.future;
    });
    final a = guard.acquire();
    final b = guard.acquire();
    gate.complete(true);
    expect(await a, isTrue);
    expect(await b, isTrue);
    expect(requests, 1);
  });

  test('scheitert die Anfrage mit einem Fehler, fragt der nächste Aufruf neu an', () async {
    final locks = _FakeWebLocks()..error = StateError('kaputt');
    final guard = TabLockGuard(locks.request);
    await expectLater(guard.acquire(), throwsStateError);
    locks.error = null;
    expect(await guard.acquire(), isTrue);
    expect(locks.requests, 2);
  });
}
