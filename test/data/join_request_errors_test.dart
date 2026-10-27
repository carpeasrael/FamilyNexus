import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

/// Beitrittsanfrage über den Familien-Code: Fehlerzuordnung (#25) und Erkennen der Ablehnung (#30).
void main() {
  group('#25: Antwort des Servers auf die Anfrage (knock)', () {
    GatewayError err(int status, [String body = '']) => SdkMatrixGateway.knockError(status, body).error;

    test('Fehlercode statt pauschal „Unbekannter Fehler.“', () {
      expect(err(403, '{"errcode":"M_FORBIDDEN","error":"You are not allowed to knock"}'), GatewayError.notAllowed);
      expect(err(404, '{"errcode":"M_NOT_FOUND"}'), GatewayError.notFound);
      expect(err(429, '{"errcode":"M_LIMIT_EXCEEDED"}'), GatewayError.rateLimited);
      expect(err(400, '{"errcode":"M_UNSUPPORTED_ROOM_VERSION"}'), GatewayError.serverUnsupported);
      expect(err(404, '{"errcode":"M_UNRECOGNIZED"}'), GatewayError.serverUnsupported, reason: 'Server kennt knock nicht');
      expect(err(400, '{"errcode":"M_INVALID_PARAM"}'), GatewayError.invalidInput);
    });

    test('Server der Familie nicht erreichbar (5xx) → Verbindungsfehler', () {
      expect(err(502, '{"errcode":"M_UNKNOWN","error":"Failed to make_knock via any server"}'), GatewayError.serverUnreachable);
      expect(err(504, '<html>Gateway Timeout</html>'), GatewayError.serverUnreachable);
    });

    test('unlesbare oder unbekannte Antwort bleibt „unbekannt“', () {
      expect(err(400, 'kein JSON'), GatewayError.unknown);
      expect(err(418), GatewayError.unknown);
    });
  });

  group('#30: Ablehnung der Anfrage', () {
    const me = '@ida:test.example';
    const requestedAt = 1000000000000;
    Map<Object?, Object?> leave({String sender = '@mod:test.example', int ts = requestedAt + 1000, String? prev = 'knock'}) =>
        <Object?, Object?>{
          'type': 'm.room.member',
          'state_key': me,
          'sender': sender,
          'origin_server_ts': ts,
          'content': <String, Object?>{'membership': 'leave'},
          if (prev != null) 'unsigned': <String, Object?>{'prev_content': <String, Object?>{'membership': prev}},
        };
    bool rejected(Map<Object?, Object?> e) => SdkMatrixGateway.isKnockRejection(e, me: me, requestedAt: requestedAt);

    test('Moderator entfernt die Anfrage: erkannt', () => expect(rejected(leave()), isTrue));

    test('Geräteuhr geht vor: Ablehnung trotzdem erkannt (Vorzustand „knock“)', () {
      expect(rejected(leave(ts: requestedAt - const Duration(minutes: 3).inMilliseconds)), isTrue);
    });

    test('alte Ablehnung (weit vor der Anfrage) oder eigener Rückzug: nicht als Ablehnung gewertet', () {
      expect(rejected(leave(ts: requestedAt - const Duration(hours: 2).inMilliseconds)), isFalse);
      expect(rejected(leave(sender: me)), isFalse);
      expect(rejected(leave(prev: null, ts: requestedAt - 1000)), isFalse, reason: 'ohne Vorzustand gilt der strenge Vergleich');
    });
  });
}
