import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_support.dart';

Matcher _error(GatewayError e) => throwsA(isA<GatewayException>().having((x) => x.error, 'error', e));

Future<({SdkMatrixGateway g, String user, String password})> _fresh(String prefix) async {
  final a = await E2e.loggedIn(prefix);
  await E2e.until(() => a.gateway.initialSyncDone, what: 'Sync');
  return (g: a.gateway, user: a.user, password: a.password);
}

void main() {
  group('Schlüsselsicherung und Verifizierung gegen echten Synapse', skip: E2e.enabled ? false : E2e.skipReason, () {
    test('Ersteinrichtung: Wiederherstellungsschlüssel, Cross-Signing, Gerät verifiziert', () async {
      final a = await _fresh('sec');
      await E2e.until(() => a.g.securityState == SecurityState.needsSetup, what: 'needsSetup');
      // Die erste Einrichtung verlangt keine Passwortbestätigung (Synapse: erstmaliger Upload).
      final key = await a.g.setUpSecurity();
      expect(key.replaceAll(' ', '').length, greaterThan(40));
      await E2e.until(() => a.g.securityState == SecurityState.ready, what: 'ready');
      await a.g.refreshSecurity();
      expect(a.g.devices.where((d) => d.isCurrent).single.verified, isTrue);
      // zweites Einrichten wird abgelehnt (nichts überschreiben)
      await expectLater(a.g.setUpSecurity(), _error(GatewayError.alreadyExists));
    });

    test('zweites Gerät: Emoji-Verifizierung mit dem ersten', () async {
      final a = await _fresh('ver');
      await a.g.setUpSecurity();
      await E2e.until(() => a.g.securityState == SecurityState.ready);

      final d2 = await E2e.loginAs(a.user, a.password);
      await E2e.until(() => d2.securityState == SecurityState.needsRestore, what: 'Gerät 2 unverifiziert');
      await d2.refreshSecurity();
      final other = d2.devices.firstWhere((d) => !d.isCurrent);
      expect(other.verified, isFalse, reason: 'aus Sicht des neuen Geräts noch nicht vertrauenswürdig');

      await d2.startVerification(userId: d2.userId!, deviceId: other.deviceId);
      await E2e.until(() => a.g.verification?.phase == VerificationPhase.incomingRequest, what: 'Anfrage bei Gerät 1');
      expect(a.g.verification!.incoming, isTrue);
      await a.g.acceptVerification();
      await E2e.until(
        () => a.g.verification?.phase == VerificationPhase.comparing && d2.verification?.phase == VerificationPhase.comparing,
        what: 'Emoji-Vergleich',
      );
      expect(a.g.verification!.emojis, hasLength(7));
      expect(a.g.verification!.emojis.map((e) => e.emoji).toList(), d2.verification!.emojis.map((e) => e.emoji).toList(), reason: 'beide Seiten zeigen dieselben Emoji');

      await a.g.confirmEmojiMatch(true);
      await d2.confirmEmojiMatch(true);
      await E2e.until(() => a.g.verification?.phase == VerificationPhase.done && d2.verification?.phase == VerificationPhase.done, what: 'fertig');
      await E2e.until(() => d2.securityState == SecurityState.ready, what: 'Gerät 2 verifiziert');
    });

    test('Abbruch: abweichende Emoji → keine Verifizierung', () async {
      final a = await _fresh('abb');
      await a.g.setUpSecurity();
      final d2 = await E2e.loginAs(a.user, a.password);
      await d2.refreshSecurity();
      await d2.startVerification(userId: d2.userId!, deviceId: d2.devices.firstWhere((d) => !d.isCurrent).deviceId);
      await E2e.until(() => a.g.verification?.phase == VerificationPhase.incomingRequest);
      await a.g.acceptVerification();
      await E2e.until(() => d2.verification?.phase == VerificationPhase.comparing);
      await d2.confirmEmojiMatch(false);
      await E2e.until(() => d2.verification?.phase == VerificationPhase.cancelled && a.g.verification?.phase == VerificationPhase.cancelled, what: 'abgebrochen');
      expect(d2.securityState, SecurityState.needsRestore);
    });

    test('Wiederherstellung mit Schlüssel: falscher Schlüssel scheitert, richtiger verifiziert und entschlüsselt alte Nachrichten', () async {
      final a = await _fresh('rest');
      await a.g.createFamily('Altbestand');
      await E2e.until(() => a.g.family != null);
      final key = await a.g.setUpSecurity();
      await a.g.sendMessage('alte Nachricht');
      await E2e.until(() => a.g.messages.any((m) => m.body == 'alte Nachricht'));
      // Schlüsselsicherung braucht einen Moment (Sitzungsschlüssel werden hochgeladen).
      await Future<void>.delayed(const Duration(seconds: 6));

      final d3 = await E2e.loginAs(a.user, a.password);
      await E2e.until(() => d3.securityState == SecurityState.needsRestore);
      await expectLater(d3.restoreSecurity('EsTx falsch falsch falsch falsch falsch falsch falsch falsch falsch'), throwsA(isA<GatewayException>()));
      expect(d3.securityState, SecurityState.needsRestore);

      await d3.restoreSecurity(key);
      await E2e.until(() => d3.securityState == SecurityState.ready, what: 'Gerät 3 verifiziert');
      await E2e.until(() => d3.family != null, what: 'Familie auf Gerät 3');
      await E2e.until(() => d3.messages.any((m) => m.body == 'alte Nachricht'), what: 'alte Nachricht über Backup entschlüsselt');
    });

    test('Unverifiziertes Gerät erhält keine Raumschlüssel; nach Verifizierung neue Nachrichten lesbar', () async {
      final a = await _fresh('keys');
      await a.g.createFamily('Schlüssel');
      await E2e.until(() => a.g.family != null);
      await a.g.setUpSecurity();
      await E2e.until(() => a.g.securityState == SecurityState.ready);

      final d2 = await E2e.loginAs(a.user, a.password);
      // Mit „abgeglichen“ steht auch die Familie fest: ein bestehendes Mitglied darf nie „keine Familie“ sehen.
      expect(d2.initialSyncDone, isTrue);
      expect(d2.family, isNotNull, reason: 'Familie des Kontos auf dem neuen Gerät sofort bekannt');
      await a.g.sendMessage('vor Verifizierung');
      await E2e.until(() => d2.messages.any((m) => m.undecryptable), what: 'Gerät 2 sieht nur Chiffretext');
      expect(d2.messages.any((m) => m.body == 'vor Verifizierung'), isFalse, reason: 'unverifiziertes Gerät liest nichts');

      await d2.refreshSecurity();
      await d2.startVerification(userId: d2.userId!, deviceId: d2.devices.firstWhere((d) => !d.isCurrent).deviceId);
      await E2e.until(() => a.g.verification?.phase == VerificationPhase.incomingRequest);
      await a.g.acceptVerification();
      await E2e.until(() => a.g.verification?.phase == VerificationPhase.comparing && d2.verification?.phase == VerificationPhase.comparing);
      await a.g.confirmEmojiMatch(true);
      await d2.confirmEmojiMatch(true);
      await E2e.until(() => d2.securityState == SecurityState.ready, what: 'Gerät 2 verifiziert');

      await a.g.sendMessage('nach Verifizierung');
      await E2e.until(() => d2.messages.any((m) => m.body == 'nach Verifizierung'), what: 'Gerät 2 liest nach Verifizierung');
    });
  });
}
