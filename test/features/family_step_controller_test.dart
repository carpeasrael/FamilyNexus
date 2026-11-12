import 'dart:async';

import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/onboarding/family_step_controller.dart';
import 'package:family_nexus/features/settings/settings_controller.dart';
import 'package:family_nexus/l10n/gen/app_localizations_de.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/memory_stores.dart';

/// AP-6a: Zustand und Aktionen des Familienschritts, ohne Widget (Controller nach dem Muster `CalendarController`).
final AppLocalizationsDe _de = AppLocalizationsDe();
final DateTime _now = DateTime.utc(2026, 3, 20, 10);

class _Setup {
  _Setup(this.server, this.gateway, this.settings, this.pending);
  final FakeMatrixServer server;
  final FakeMatrixGateway gateway;
  final SettingsController settings;
  final ValueNotifier<InviteLink?> pending;
  int ready = 0;

  /// Wirft `onFamilyReady`, solange gesetzt (Speichern am Ende scheitert, #411).
  Object? readyError;
  Completer<void>? readyGate;
  late final FamilyStepController c;
}

Future<_Setup> _setup({FamilyStepMode mode = FamilyStepMode.choice}) async {
  final server = FakeMatrixServer()
    ..now = (() => _now)
    ..addAccount('anna', 'geheim123', displayName: 'Anna')
    ..addAccount('ben', 'geheim456', displayName: 'Ben');
  final gateway = server.newDevice();
  await gateway.login(server: ServerUrl.tryParse(server.host)!, username: 'anna', password: 'geheim123');
  await gateway.setUpSecurity();
  final s = _Setup(server, gateway, SettingsController(MemoryKeyValueStore()), ValueNotifier<InviteLink?>(null));
  s.c = FamilyStepController(
    gateway: gateway,
    settings: s.settings,
    pendingInvite: s.pending,
    onFamilyReady: () async {
      await s.readyGate?.future;
      final e = s.readyError;
      if (e != null) throw e;
      s.ready++;
    },
    mode: mode,
    clock: () => _now,
  );
  addTearDown(s.c.dispose);
  return s;
}

/// Ben gründet eine Familie; liefert deren Raum-ID.
Future<String> _benFamily(_Setup s) async {
  final ben = s.server.newDevice();
  await ben.login(server: ServerUrl.tryParse(s.server.host)!, username: 'ben', password: 'geheim456');
  await ben.setUpSecurity();
  await ben.createFamily('Familie Ben');
  return s.server.rooms.values.firstWhere((r) => r.name == 'Familie Ben').id;
}

void main() {
  group('Anfangszustand', () {
    test('Modus join startet auf „Beitreten“, die anderen auf „Gründen“', () async {
      expect((await _setup(mode: FamilyStepMode.join)).c.join, isTrue);
      expect((await _setup(mode: FamilyStepMode.create)).c.join, isFalse);
      expect((await _setup()).c.join, isFalse);
    });

    test('ohne Aktion: nicht beschäftigt, kein Fehler, nichts gegründet', () async {
      final s = await _setup();
      expect((s.c.busy, s.c.hasError, s.c.createdName, s.c.showChoice, s.c.waitingFor, s.c.creating), (false, false, null, false, null, false));
      expect(s.c.errorMessage(_de), isNull);
    });
  });

  group('Gründen', () {
    test('Erfolg: Familie angelegt, Name getrimmt gemerkt, Gateway und Steuerung wieder frei', () async {
      final s = await _setup(mode: FamilyStepMode.create);
      final seen = <bool>[];
      s.c.addListener(() => seen.add(s.c.busy));
      await s.c.create('  Familie Müller  ');
      expect(s.gateway.family?.name, 'Familie Müller');
      expect(s.c.createdName, 'Familie Müller');
      expect((s.c.busy, s.c.creating, s.c.hasError), (false, false, false));
      expect(seen.first, isTrue, reason: 'während der Gründung beschäftigt');
      expect(seen.last, isFalse);
    });

    test('Fehler: Text in der Sprache der Oberfläche, nichts gemerkt, nicht mehr beschäftigt', () async {
      final s = await _setup(mode: FamilyStepMode.create);
      await s.c.create('   ');
      expect(s.c.createdName, isNull);
      expect(s.c.busy, isFalse);
      expect(s.c.creating, isFalse);
      expect(s.c.errorMessage(_de), isNotNull);
      expect(s.c.errorMessage(_de), isNotEmpty);
    });

    test('ein neuer Versuch löscht den alten Fehler', () async {
      final s = await _setup(mode: FamilyStepMode.create);
      await s.c.create('');
      expect(s.c.hasError, isTrue);
      await s.c.create('Familie');
      expect(s.c.hasError, isFalse);
      expect(s.c.createdName, 'Familie');
    });
  });

  group('Einladungslink einfügen', () {
    test('kein Link: Fehler, Eingabe bleibt stehen, nichts gespeichert', () async {
      final s = await _setup(mode: FamilyStepMode.join);
      var cleared = false;
      await s.c.submitLink('das ist kein Link', clearInput: () => cleared = true);
      expect(cleared, isFalse);
      expect(s.c.errorMessage(_de), isNotNull);
      expect(s.pending.value, isNull);
      expect(s.settings.settings.pendingInvite, isNull);
    });

    test('gültiger Link: Eingabe geleert, Link gemerkt und als Karte freigegeben', () async {
      final s = await _setup(mode: FamilyStepMode.join);
      final raw = InviteLink.create(
        roomId: '!fam:fake.test',
        via: 'fake.test',
        inviter: '@ben:fake.test',
        now: _now,
        nonce: '0123456789abcdef0123456789abcdef',
      );
      var cleared = false;
      await s.c.submitLink(raw, clearInput: () => cleared = true);
      expect(cleared, isTrue);
      expect(s.c.hasError, isFalse);
      expect(s.pending.value?.roomId, '!fam:fake.test');
      expect(s.settings.settings.pendingInvite, isNotNull);
    });

    test('abgelaufener Link: Fehler, nichts gemerkt', () async {
      final s = await _setup(mode: FamilyStepMode.join);
      final raw = InviteLink.create(
        roomId: '!fam:fake.test',
        via: 'fake.test',
        inviter: '@ben:fake.test',
        now: _now.subtract(const Duration(days: 30)),
        nonce: '0123456789abcdef0123456789abcdef',
      );
      await s.c.submitLink(raw, clearInput: () => fail('nicht leeren'));
      expect(s.c.hasError, isTrue);
      expect(s.pending.value, isNull);
    });
  });

  group('Familien-Code', () {
    test('ungültiger Code: Fehlertext „Code ungültig“, kein Aufruf am Gateway', () async {
      final s = await _setup(mode: FamilyStepMode.join);
      await s.c.sendCode('kein code', clearInput: () => fail('nicht leeren'));
      expect(s.c.errorMessage(_de), _de.joinCodeInvalid);
      expect(s.gateway.joinRequestPending, isFalse);
    });

    test('gültiger Code: Anfrage gesendet, Eingabe geleert, Wartender zurückgesetzt', () async {
      final s = await _setup(mode: FamilyStepMode.join);
      final room = await _benFamily(s);
      var cleared = false;
      await s.c.sendCode(' $room ', clearInput: () => cleared = true);
      expect(s.gateway.joinRequestPending, isTrue);
      expect(cleared, isTrue);
      expect(s.c.waitingFor, isNull);
      expect(s.c.busy, isFalse);
    });

    test('unbekannter Raum: Fehler vom Gateway, Eingabe bleibt stehen', () async {
      final s = await _setup(mode: FamilyStepMode.join);
      await s.c.sendCode('!gibtsnicht:fake.test', clearInput: () => fail('nicht leeren'));
      expect(s.c.hasError, isTrue);
      expect(s.c.busy, isFalse);
    });
  });

  group('Beitrittsanfrage per Link', () {
    InviteLink linkFor(String roomId, {DateTime? now}) {
      final raw = InviteLink.create(
        roomId: roomId,
        via: 'fake.test',
        inviter: '@ben:fake.test',
        now: now ?? _now,
        nonce: '0123456789abcdef0123456789abcdef',
        inviterName: 'Ben',
      );
      return InviteLink.check(raw, now: now ?? _now).link!;
    }

    test('abgelaufen: Fehler „Link abgelaufen“, keine Anfrage', () async {
      final s = await _setup(mode: FamilyStepMode.join);
      final room = await _benFamily(s);
      await s.c.send(linkFor(room, now: _now.subtract(const Duration(days: 4))));
      expect(s.c.errorMessage(_de), _de.joinLinkExpired);
      expect(s.gateway.joinRequestPending, isFalse);
    });

    test('gültig: Anfrage gesendet, Name des Einladenden gemerkt, Karte verworfen', () async {
      final s = await _setup(mode: FamilyStepMode.join);
      final room = await _benFamily(s);
      final link = linkFor(room);
      s.pending.value = link;
      await s.c.send(link);
      expect(s.gateway.joinRequestPending, isTrue);
      expect(s.c.waitingFor, 'Ben');
      expect(s.pending.value, isNull);
      expect(s.settings.settings.pendingInvite, isNull);
    });
  });

  group('Einladungen', () {
    test('annehmen ruft das Gateway und danach onFamilyReady', () async {
      final s = await _setup();
      final room = await _benFamily(s);
      s.server.invites['@anna:fake.test'] = <String>[room];
      final inv = s.gateway.invitations.single;
      await s.c.accept(inv);
      expect(s.gateway.family?.name, 'Familie Ben');
      expect(s.ready, 1);
    });

    test('ablehnen entfernt die Einladung, onFamilyReady wird nicht gerufen', () async {
      final s = await _setup();
      final room = await _benFamily(s);
      s.server.invites['@anna:fake.test'] = <String>[room];
      await s.c.decline(s.gateway.invitations.single);
      expect(s.gateway.invitations, isEmpty);
      expect(s.ready, 0);
    });
  });

  group('Ansicht', () {
    test('selectJoin wechselt den Reiter und löscht den Fehler', () async {
      final s = await _setup();
      await s.c.create('');
      expect(s.c.hasError, isTrue);
      s.c.selectJoin(true);
      expect((s.c.join, s.c.hasError), (true, false));
    });

    test('switchMode: aus „Gründen“ wird „Beitreten“ und umgekehrt, die Auswahl wird gezeigt', () async {
      final a = await _setup(mode: FamilyStepMode.create);
      a.c.switchMode();
      expect((a.c.showChoice, a.c.join), (true, true));
      final b = await _setup(mode: FamilyStepMode.join);
      b.c.switchMode();
      expect((b.c.showChoice, b.c.join), (true, false));
    });

    test('chooseOther zeigt die Auswahl', () async {
      final s = await _setup();
      s.c.chooseOther();
      expect(s.c.showChoice, isTrue);
    });

    test('Link von außen (Deep Link oder QR): Beitreten, Auswahl, Fehler weg', () async {
      final s = await _setup(mode: FamilyStepMode.create);
      await s.c.create('');
      expect(s.c.hasError, isTrue);
      var notified = 0;
      s.c.addListener(() => notified++);
      s.pending.value = InviteLink.check(
        InviteLink.create(roomId: '!f:fake.test', via: 'fake.test', inviter: '@ben:fake.test', now: _now, nonce: '0123456789abcdef0123456789abcdef'),
        now: _now,
      ).link;
      expect((s.c.join, s.c.showChoice, s.c.hasError), (true, true, false));
      expect(notified, 1);
    });

    test('Link wird gelöscht (null): keine Änderung', () async {
      final s = await _setup();
      s.pending.value = null;
      expect((s.c.join, s.c.showChoice), (false, false));
    });
  });

  group('Einmalige Auslöser der Oberfläche', () {
    test('beginAutoAccept liefert je Raum nur beim ersten Aufruf true', () async {
      final s = await _setup();
      expect(s.c.beginAutoAccept('!a:x'), isTrue);
      expect(s.c.beginAutoAccept('!a:x'), isFalse);
      expect(s.c.beginAutoAccept('!b:x'), isTrue);
    });
  });

  group('Abschluss der Einrichtung (#411)', () {
    test('completeExisting ruft onFamilyReady und bleibt danach „abgeschlossen“', () async {
      final s = await _setup();
      await s.c.completeExisting();
      expect((s.ready, s.c.completing, s.c.completionFailed, s.c.hasError, s.c.busy), (1, true, false, false, false));
    });

    test('ein zweiter Aufruf nach Erfolg löst nichts mehr aus (nur einmal)', () async {
      final s = await _setup();
      await s.c.completeExisting();
      await s.c.completeExisting();
      expect(s.ready, 1);
    });

    test('zwei gleichzeitige Aufrufe lösen den Abschluss nur einmal aus', () async {
      final s = await _setup();
      s.readyGate = Completer<void>();
      final first = s.c.completeExisting();
      final second = s.c.completeExisting();
      expect(s.c.completing, isTrue, reason: 'schon vor dem ersten await gesetzt');
      s.readyGate!.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect(s.ready, 1);
    });

    test('Fehlschlag: Fehler bleibt stehen, der Abschluss ist wieder frei, nicht mehr beschäftigt', () async {
      final s = await _setup();
      s.readyError = const SetupSaveException();
      await s.c.completeExisting();
      expect((s.c.completionFailed, s.c.completing, s.c.busy, s.ready), (true, false, false, 0));
      expect(s.c.errorMessage(_de), _de.errUnknown);
    });

    test('Wiederholung nach Fehlschlag gelingt: Fehler weg, onFamilyReady einmal gelungen', () async {
      final s = await _setup();
      s.readyError = const SetupSaveException();
      await s.c.completeExisting();
      s.readyError = null;
      await s.c.completeExisting();
      expect((s.c.completionFailed, s.c.completing, s.c.hasError, s.ready), (false, true, false, 1));
    });

    test('beim neuen Versuch ist der Fehlerzustand schon zurückgesetzt (kein Aufblitzen der Fehleransicht)', () async {
      final s = await _setup();
      s.readyError = const SetupSaveException();
      await s.c.completeExisting();
      s.readyError = null;
      s.readyGate = Completer<void>();
      final retry = s.c.completeExisting();
      expect((s.c.completionFailed, s.c.completing, s.c.busy), (false, true, true));
      s.readyGate!.complete();
      await retry;
    });

    test('finish: Erfolg ruft onFamilyReady und liefert true', () async {
      final s = await _setup();
      expect(await s.c.finish(), isTrue);
      expect((s.ready, s.c.hasError), (1, false));
    });

    test('finish: Fehler wird gezeigt statt geworfen, liefert false, danach wieder bedienbar', () async {
      final s = await _setup();
      s.readyError = const SetupSaveException();
      expect(await s.c.finish(), isFalse);
      expect((s.c.errorMessage(_de), s.c.busy), (_de.errUnknown, false));
      s.readyError = null;
      expect(await s.c.finish(), isTrue);
      expect(s.c.hasError, isFalse);
    });

    test('dispose während des Abschlusses: keine Meldung mehr, kein Absturz', () async {
      final s = await _setup();
      final c = FamilyStepController(
        gateway: s.gateway,
        settings: s.settings,
        pendingInvite: ValueNotifier<InviteLink?>(null),
        onFamilyReady: () async {
          await s.readyGate?.future;
          throw const SetupSaveException();
        },
      );
      s.readyGate = Completer<void>();
      final running = c.completeExisting();
      c.dispose();
      s.readyGate!.complete();
      await running;
      expect(c.completionFailed, isFalse, reason: 'nach dispose wird nichts mehr gesetzt');
    });
  });

  group('Lebensdauer', () {
    test('nach dispose löst ein neuer Link nichts mehr aus', () async {
      final s = await _setup(mode: FamilyStepMode.create);
      final pending = ValueNotifier<InviteLink?>(null);
      final c = FamilyStepController(gateway: s.gateway, settings: s.settings, pendingInvite: pending, onFamilyReady: () async {});
      var notified = 0;
      c.addListener(() => notified++);
      pending.value = InviteLink.check(
        InviteLink.create(roomId: '!f:fake.test', via: 'fake.test', inviter: '@ben:fake.test', now: _now, nonce: '0123456789abcdef0123456789abcdef'),
        now: _now,
      ).link;
      expect(notified, 1);
      c.dispose();
      pending.value = null;
      pending.value = InviteLink.check(
        InviteLink.create(roomId: '!g:fake.test', via: 'fake.test', inviter: '@ben:fake.test', now: _now, nonce: '0123456789abcdef0123456789abcdef'),
        now: _now,
      ).link;
      expect(c.join, isTrue, reason: 'unverändert: kein Zugriff mehr nach dispose');
    });

    test('eine Aktion, die über dispose hinweg läuft, meldet nichts mehr (sonst würfe ChangeNotifier)', () async {
      final s = await _setup(mode: FamilyStepMode.create);
      final running = FamilyStepController(gateway: s.gateway, settings: s.settings, pendingInvite: ValueNotifier<InviteLink?>(null), onFamilyReady: () async {});
      final future = running.create('Familie');
      running.dispose();
      await future;
      expect(running.createdName, isNull, reason: 'nach dispose wird nichts mehr gesetzt');
    });
  });
}
