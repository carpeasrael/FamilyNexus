import 'package:family_nexus/data/matrix/identity_pins.dart';
import 'package:flutter_test/flutter_test.dart';

/// #133: Nach „Identitätsänderung akzeptieren“ dürfen die Geräte nicht erneut gesperrt werden, solange die
/// Kontodaten noch den alten Pin zeigen; Sperren entfernt nur das ausdrückliche Akzeptieren (E-37).
void main() {
  const ben = '@ben:fake.test';
  const cara = '@cara:fake.test';
  const k1 = 'KEY1';
  const k2 = 'KEY2';
  const k3 = 'KEY3';

  group('decide', () {
    test('kein Pin und nichts gesperrt ⇒ firstSeen; passender Pin ⇒ ok', () {
      expect(decide(pinned: null, pub: k1, anyBlocked: false), IdentityDecision.firstSeen);
      expect(decide(pinned: k1, pub: k1, anyBlocked: false), IdentityDecision.ok);
    });

    test('anderer Schlüssel ⇒ changed (auch ohne gesperrte Geräte)', () {
      expect(decide(pinned: k1, pub: k2, anyBlocked: false), IdentityDecision.changed);
      expect(decide(pinned: k1, pub: k2, anyBlocked: true), IdentityDecision.changed);
    });

    test('Geräte noch gesperrt ⇒ changed, auch bei passendem oder fehlendem Pin (Akzeptieren bleibt möglich)', () {
      expect(decide(pinned: k1, pub: k1, anyBlocked: true), IdentityDecision.changed);
      expect(decide(pinned: null, pub: k1, anyBlocked: true), IdentityDecision.changed);
    });
  });

  group('anyBlocked', () {
    test('nur gesperrte Geräte mit gültiger Selbstsignatur zählen', () {
      expect(anyBlocked(const <({bool blocked, bool selfSigned})>[]), isFalse);
      expect(anyBlocked(const [(blocked: false, selfSigned: true)]), isFalse);
      expect(anyBlocked(const [(blocked: true, selfSigned: true)]), isTrue);
      expect(anyBlocked(const [(blocked: false, selfSigned: true), (blocked: true, selfSigned: true)]), isTrue);
    });

    test('ein Gerät mit ungültiger Selbstsignatur (SDK meldet es als gesperrt) löst keinen Dauer-Fehlalarm aus', () {
      expect(anyBlocked(const [(blocked: true, selfSigned: false)]), isFalse);
    });
  });

  test('canAccept: geändert in dieser Sitzung oder Geräte noch gesperrt (z. B. nach Neustart)', () {
    expect(canAccept(identityChanged: true, anyBlocked: false), isTrue);
    expect(canAccept(identityChanged: false, anyBlocked: true), isTrue, reason: 'nach Neustart ist die Markierung weg, die Sperre nicht');
    expect(canAccept(identityChanged: false, anyBlocked: false), isFalse);
  });

  group('IdentityPinBook', () {
    late IdentityPinBook book;
    setUp(() => book = IdentityPinBook());

    test('Rennfall: nach dem Akzeptieren gilt der neue Schlüssel, obwohl die Kontodaten noch den alten Pin zeigen', () {
      final account = <String, String>{ben: k1};
      book.accept(ben, k2, base: k1);
      book.synced(account); // der Sync hat noch nichts Neues gebracht
      expect(book.pinned(ben, account), k2);
      expect(decide(pinned: book.pinned(ben, account), pub: k2, anyBlocked: false), IdentityDecision.ok);
    });

    test('ohne Akzeptieren bleibt der Kontodaten-Pin maßgeblich', () {
      expect(book.pinned(ben, <String, String>{ben: k1}), k1);
      expect(decide(pinned: book.pinned(ben, <String, String>{ben: k1}), pub: k2, anyBlocked: false), IdentityDecision.changed);
    });

    test('der akzeptierte Pin entfällt, sobald die Kontodaten ihn zeigen', () {
      book.accept(ben, k2, base: k1);
      book.synced(<String, String>{ben: k2});
      expect(book.pinned(ben, <String, String>{ben: k2}), k2);
      // später ändern die Kontodaten den Pin: der alte akzeptierte Eintrag darf nicht mehr vorgehen
      expect(book.pinned(ben, <String, String>{ben: k3}), k3);
    });

    test('ein veralteter akzeptierter Pin wird verworfen, wenn die Kontodaten auf einen anderen Wert wechseln', () {
      book.accept(ben, k2, base: k1);
      book.synced(<String, String>{ben: k3}); // ein anderes eigenes Gerät hat anders entschieden
      expect(book.pinned(ben, <String, String>{ben: k3}), k3);
      expect(decide(pinned: book.pinned(ben, <String, String>{ben: k3}), pub: k2, anyBlocked: false), IdentityDecision.changed);
    });

    test('fehlte der Kontodaten-Pin beim Akzeptieren (base == null), genügt das Erscheinen eines Pins', () {
      book.accept(ben, k2, base: null);
      book.synced(<String, String>{});
      expect(book.pinned(ben, <String, String>{}), k2, reason: 'noch kein Pin: akzeptierter gilt weiter');
      book.synced(<String, String>{ben: k3});
      expect(book.pinned(ben, <String, String>{ben: k3}), k3);
    });

    test('kein verlorenes Update: beide Schreibpfade nehmen akzeptierte und ungespeicherte Pins mit', () {
      final account = <String, String>{ben: k1, cara: k1};
      book.accept(ben, k2, base: k1);
      book.accept(cara, k3, base: k1); // zwei Mitglieder nacheinander, noch vor dem Sync
      expect(book.merged(account), <String, String>{ben: k2, cara: k3});
      book.remember('@dora:fake.test', 'D1');
      final merged = book.merged(account);
      expect(merged['@dora:fake.test'], 'D1');
      expect(merged[ben], k2, reason: 'akzeptierter Pin geht den Kontodaten vor');
      book.persisted(merged);
      expect(book.hasPending, isFalse);
    });

    test('ein ungespeicherter erster Pin überschreibt keinen Kontodaten-Pin', () {
      book.remember(ben, k2);
      expect(book.merged(<String, String>{ben: k1})[ben], k1);
      expect(book.pinned(ben, <String, String>{ben: k1}), k1);
      expect(book.pinned(ben, <String, String>{}), k2);
    });

    test('Mitglieder sind unabhängig voneinander', () {
      book.accept(ben, k2, base: k1);
      expect(book.pinned(cara, <String, String>{cara: k1}), k1);
    });

    test('Abmelden leert akzeptierte und ungespeicherte Pins', () {
      book.accept(ben, k2, base: k1);
      book.remember(cara, k3);
      book.clear();
      expect(book.hasPending, isFalse);
      expect(book.pinned(ben, <String, String>{ben: k1}), k1);
      expect(book.pinned(cara, <String, String>{}), isNull);
    });
  });
}
