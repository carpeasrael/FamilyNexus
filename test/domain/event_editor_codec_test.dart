import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/event_codec.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/events.dart';

/// #431, E-112: Feld `editor` im Ereignisformat. Besitzerfassungen bleiben byte-gleich; fremde Absender sind nur mit
/// `editor == sender`, geteilt und nicht gelöscht gültig; beim Lesen aus der Ablage wird nie nach Rollen geprüft.
void main() {
  setUpAll(TimeZones.ensureInitialized);

  const mod = '@cara:fake.test';

  Map<String, Object?> wire(CalendarEvent e) => EventCodec.encodeShared(e);

  DecodeResult decodeAs(String sender, Map<String, Object?> c, {EventVisibility v = EventVisibility.shared}) =>
      EventCodec.decode(c, sender: sender, visibility: v);

  group('Kodierung', () {
    test('ohne editor: kein Schlüssel, byte-gleich zu heute', () {
      expect(wire(ev()).containsKey('editor'), isFalse);
      expect(EventCodec.canonical(ev()).contains('editor'), isFalse);
    });

    test('mit editor: Rundlauf; Besitzer als Absender gilt als Behauptung', () {
      final e = ev().copyWith(editorId: mod);
      final c = wire(e);
      expect(c['editor'], mod);
      final r = decodeAs(kOwner, c);
      expect(r.isOk, isTrue);
      expect(r.event, e);
      expect(r.sender, kOwner);
    });
  });

  group('fremder Absender', () {
    test('Moderatorfassung mit editor == Absender wird dekodiert', () {
      final c = wire(ev(version: 2).copyWith(editorId: mod));
      final r = decodeAs(mod, c);
      expect(r.isOk, isTrue);
      expect(r.event!.ownerId, kOwner);
      expect(r.event!.editorId, mod);
      expect(r.sender, mod);
    });

    test('ohne editor, mit fremdem editor oder gelöscht: owner-mismatch', () {
      expect(decodeAs(mod, wire(ev())).error, 'owner-mismatch');
      expect(decodeAs(mod, wire(ev().copyWith(editorId: kOther))).error, 'owner-mismatch');
      final gone = wire(ev(version: 2).copyWith(editorId: mod)) ..['deleted'] = true;
      expect(decodeAs(mod, gone).error, 'owner-mismatch');
    });

    test('privater Kontext: owner-mismatch', () {
      final c = wire(ev().copyWith(editorId: mod));
      expect(decodeAs(mod, c, v: EventVisibility.private).error, 'owner-mismatch');
    });
  });

  group('Feldprüfung', () {
    test('editor gleich Besitzer, ungültige ID oder falscher Typ werden verworfen', () {
      for (final bad in <Object?>[kOwner, 'ben', '', 7, null, '@x']) {
        final c = wire(ev())..['editor'] = bad;
        expect(decodeAs(kOwner, c).isOk, isFalse, reason: '$bad');
      }
    });

    test('validate: editor bei privatem Termin, gleich Besitzer oder ungültig', () {
      expect(ev().copyWith(editorId: mod).validate(), isEmpty);
      expect(ev(visibility: EventVisibility.private).copyWith(editorId: mod).validate(), contains('editor'));
      expect(ev().copyWith(editorId: kOwner).validate(), contains('editor'));
      expect(ev().copyWith(editorId: 'x').validate(), contains('editor'));
    });

    test('tombstone und clearEditor tragen keinen editor', () {
      final e = ev().copyWith(editorId: mod);
      expect(e.tombstone(DateTime.utc(2026, 3, 2)).editorId, isNull);
      expect(e.copyWith(clearEditor: true).editorId, isNull);
    });
  });

  group('Ablage (decodeStored)', () {
    test('liest editor ohne Rollenprüfung; Spalte owner muss zum Feld passen', () {
      final c = wire(ev(version: 3).copyWith(editorId: mod));
      final ok = EventCodec.decodeStored(c, owner: kOwner, visibility: EventVisibility.shared);
      expect(ok.event!.editorId, mod);
      final wrong = EventCodec.decodeStored(c, owner: mod, visibility: EventVisibility.shared);
      expect(wrong.error, 'owner-mismatch');
    });
  });
}
