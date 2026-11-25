import 'dart:io';

import 'package:family_nexus/data/matrix/contact_signal_scan.dart';
import 'package:family_nexus/domain/contacts.dart';
import 'package:flutter_test/flutter_test.dart';

/// #119, K2c (E-114, I3/I4): Ein Kontaktsignal entsteht nur im privaten Raum und nur vom eigenen Konto.
void main() {
  const me = '@ich:hs.example';
  bool accepts(String type, String sender, String? who, {required bool shared}) => ContactSignalScan.accepts(type, sender, who, shared: shared);

  test('Kontrollfall: privater Raum, eigener Absender, Typ des Kontaktdatensatzes', () {
    expect(accepts(ContactCodec.type, me, me, shared: false), isTrue);
  });

  test('der Familienraum erzeugt nie ein Kontaktsignal, auch nicht vom eigenen Konto', () {
    expect(accepts(ContactCodec.type, me, me, shared: true), isFalse);
    expect(accepts(ContactCodec.type, '@fremd:hs.example', me, shared: true), isFalse);
  });

  test('fremder, leerer oder unbekannter Absender, fehlende eigene Kennung, anderer Typ: nie', () {
    expect(accepts(ContactCodec.type, '@fremd:hs.example', me, shared: false), isFalse);
    expect(accepts(ContactCodec.type, '', me, shared: false), isFalse);
    expect(accepts(ContactCodec.type, me, null, shared: false), isFalse);
    expect(accepts(ContactCodec.type, '', '', shared: false), isFalse);
    expect(accepts(ContactCodec.type, me, '', shared: false), isFalse);
    expect(accepts('de.inneso.familynexus.event_private', me, me, shared: false), isFalse);
    expect(accepts('m.room.message', me, me, shared: false), isFalse);
    expect(accepts('${ContactCodec.type}x', me, me, shared: false), isFalse);
  });

  test('der Absender muss genau das eigene Konto sein: weder Präfix noch andere Schreibweise noch Anhang', () {
    expect(accepts(ContactCodec.type, '$me.evil.org', me, shared: false), isFalse, reason: 'Präfix-Täuschung');
    expect(accepts(ContactCodec.type, me.toUpperCase(), me, shared: false), isFalse);
    expect(accepts(ContactCodec.type, ' $me', me, shared: false), isFalse);
    expect(accepts(ContactCodec.type, '$me ', me, shared: false), isFalse);
    expect(accepts(ContactCodec.type, '@ich:hs.example2', me, shared: false), isFalse);
    expect(accepts(ContactCodec.type, '@ic:hs.example', me, shared: false), isFalse);
  });

  test('Quelltextwächter: die Entscheidung steht genau einmal im Gateway, der Typ steht in den Klartext-Typen', () {
    final t = File('lib/data/matrix/gateway/calendar_data.dart').readAsStringSync();
    expect('ContactSignalScan.accepts('.allMatches(t).length, 1);
    expect('ContactSignal('.allMatches(t).length, 1, reason: 'das Signal entsteht nur hinter der Entscheidung');
    final accept = t.indexOf('ContactSignalScan.accepts(');
    final signal = t.indexOf('ContactSignal(');
    expect(signal, greaterThan(accept));
    expect(t, contains('ContactCodec.type,\n    InviteTicket.type,'), reason: 'Klartext des Typs wird gewarnt (_appEventTypes)');
    // Der Aufruf hat genau diese Gestalt: Absender des Ereignisses, eigene Kennung des Clients, `shared` des Aufrufers; kein `|| true`.
    expect(t, contains('if (ContactSignalScan.accepts(e.type, e.senderId, _client?.userID, shared: shared)) {\n          _emit(ContactSignal(e.senderId, e.originServerTs, c));'));
    expect(t, isNot(contains('shared: false)')), reason: 'der Scan reicht `shared` unverändert durch');
    // publishContactRecord: nur privater Raum, nie Familienraum, mit Prüfung, ohne Raum-Parameter.
    final start = t.indexOf('Future<void> publishContactRecord(ContactRecord record) async {');
    expect(start, greaterThan(0));
    final end = t.indexOf('  @override', start);
    final body = t.substring(start, end);
    expect(body, contains('_ensurePrivateRoom()'));
    expect(body, contains('_privateRoom()'));
    expect(body, contains('await _verifyPrivateRoom(room);'));
    expect(body, contains('on StateError'));
    expect(body, contains('GatewayError.invalidInput'));
    expect(body, isNot(contains('_familyRoom')));
    expect(body, isNot(contains('_requireEncryptedRoom')));
    expect(body, isNot(contains('roomId')));
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      if (f.path.endsWith('calendar_data.dart') || f.path.endsWith('calendar_signal.dart') || f.path.endsWith('contact_sync.dart') || f.path.endsWith('calendar_sync.dart')) continue; // dort nur `case ContactSignal()`
      expect(f.readAsStringSync().contains('ContactSignal('), isFalse, reason: f.path);
    }
  });
}
