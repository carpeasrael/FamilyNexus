import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/domain/verification_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/release_markers.dart';

/// #119, K3b-2b (B8): wer verifiziert werden darf (reine Funktion) und der Wächter für die Freigabemarken.
void main() {
  const me = '@me:hs';
  const carla = '@carla:hs';
  const room = '!ct:hs';

  bool allowed({
    String userId = carla,
    String? roomId,
    bool familyJoined = false,
    ContactState? state = ContactState.accepted,
    bool blocked = false,
    String? contactRoom = room,
    bool busy = false,
  }) =>
      VerificationPolicy.allowed(
        userId: userId,
        roomId: roomId,
        me: me,
        familyJoined: familyJoined,
        contactState: state,
        blocked: blocked,
        contactRoomId: contactRoom,
        busy: busy,
      );

  group('VerificationPolicy.allowed', () {
    test('eigenes Konto und beigetretenes Familienmitglied: erlaubt, auch ohne Kontakt-Angaben', () {
      expect(allowed(userId: me, state: null, contactRoom: null), isTrue);
      expect(allowed(familyJoined: true, state: null, contactRoom: null), isTrue);
    });

    test('Kontakt accepted: erlaubt im To-Device-Weg und im gewählten Raum', () {
      expect(allowed(), isTrue);
      expect(allowed(roomId: room), isTrue);
    });

    test('Kontakt outgoing mit beigetretenem Gegenüber (gewählter Raum vorhanden): erlaubt', () {
      expect(allowed(state: ContactState.outgoing, roomId: room), isTrue);
    });

    test('verweigert: Fremde, blockierte Kontakte, Zustand blocked', () {
      expect(allowed(state: null), isFalse, reason: 'ohne Datensatz');
      expect(allowed(blocked: true), isFalse);
      expect(allowed(state: ContactState.blocked), isFalse);
    });

    test('verweigert: kein Kontakt-Gespräch mit beigetretenem Gegenüber (wartend, Neustart, Lazy Loading)', () {
      expect(allowed(contactRoom: null), isFalse);
      expect(allowed(state: ContactState.outgoing, contactRoom: null), isFalse, reason: 'outgoing ohne Thread oder wartend');
    });

    test('verweigert: falscher Raum (Gruppe, verlassener, anderer), auch bei sonst erlaubtem Kontakt', () {
      expect(allowed(roomId: '!gruppe:hs'), isFalse);
      expect(allowed(roomId: '!anderer:hs'), isFalse);
    });

    test('verweigert: beschäftigt (nur eingehend), auch für eigenes Konto und Mitglieder', () {
      expect(allowed(busy: true), isFalse);
      expect(allowed(userId: me, busy: true), isFalse);
      expect(allowed(familyJoined: true, busy: true), isFalse);
    });

    test('nicht beigetretenes Familienmitglied ohne Kontakt-Datensatz: verweigert', () {
      expect(allowed(state: null, contactRoom: null), isFalse);
    });
  });

  group('VerificationPolicy.contactAllowed (Akzeptieren, ohne Raumbindung)', () {
    test('Zustände outgoing und accepted mit beigetretenem Gegenüber', () {
      for (final s in <ContactState>[ContactState.outgoing, ContactState.accepted]) {
        expect(VerificationPolicy.contactAllowed(contactState: s, blocked: false, contactRoomId: room), isTrue, reason: '$s');
      }
    });

    test('verweigert ohne Datensatz, blockiert, blocked-Datensatz, ohne Raum', () {
      expect(VerificationPolicy.contactAllowed(contactState: null, blocked: false, contactRoomId: room), isFalse);
      expect(VerificationPolicy.contactAllowed(contactState: ContactState.accepted, blocked: true, contactRoomId: room), isFalse);
      expect(VerificationPolicy.contactAllowed(contactState: ContactState.blocked, blocked: false, contactRoomId: room), isFalse);
      expect(VerificationPolicy.contactAllowed(contactState: ContactState.accepted, blocked: false, contactRoomId: null), isFalse);
    });

    test('mit checkRoom wird der Raum geprüft, ohne nicht', () {
      expect(VerificationPolicy.contactAllowed(contactState: ContactState.accepted, blocked: false, contactRoomId: room, roomId: '!x:hs'), isTrue);
      expect(VerificationPolicy.contactAllowed(contactState: ContactState.accepted, blocked: false, contactRoomId: room, roomId: '!x:hs', checkRoom: true), isFalse);
    });
  });

  group('missingReleaseMarkers (Wächter der Freigabe)', () {
    const all = 'Text\nMARKE: K3b-2 abgeschlossen\nMARKE: K3c Pin-Sackgasse gelöst\nMARKE: K3c abgeschlossen\nEnde\n';

    test('alle drei Marken als eigene Zeile: nichts fehlt', () {
      expect(missingReleaseMarkers(all), isEmpty);
    });

    test('ohne Marken fehlen alle drei', () {
      expect(missingReleaseMarkers('nichts'), releaseMarkers);
      expect(missingReleaseMarkers(''), releaseMarkers);
    });

    test('jede einzelne fehlende Marke wird gemeldet', () {
      for (final m in releaseMarkers) {
        final doc = all.replaceAll('MARKE: $m\n', '');
        expect(missingReleaseMarkers(doc), <String>[m], reason: m);
      }
    });

    test('die typografische Erwähnung im Fließtext zählt nicht', () {
      const prose = 'Die Marken „K3b-2 abgeschlossen“ und „K3c abgeschlossen“ müssen stehen. MARKE: K3c abgeschlossen im Satz.\n'
          'Auch "K3c Pin-Sackgasse gelöst" im Text.';
      expect(missingReleaseMarkers(prose), releaseMarkers);
    });

    test('Marke mit Vorsatz, Zusatz oder Einrückung zählt nicht; Zeilenende CRLF und Leerraum am Ende schon', () {
      expect(missingReleaseMarkers('- MARKE: K3b-2 abgeschlossen\n'), contains('K3b-2 abgeschlossen'));
      expect(missingReleaseMarkers('MARKE: K3b-2 abgeschlossen (vorläufig)\n'), contains('K3b-2 abgeschlossen'));
      expect(missingReleaseMarkers('  MARKE: K3b-2 abgeschlossen\n'), contains('K3b-2 abgeschlossen'));
      expect(missingReleaseMarkers('MARKE: K3b-2 abgeschlossen\r\nMARKE: K3c abgeschlossen  \nMARKE: K3c Pin-Sackgasse gelöst'), isEmpty);
    });
  });
}
