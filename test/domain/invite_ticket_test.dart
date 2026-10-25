import 'package:family_nexus/domain/invite_ticket.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 22).millisecondsSinceEpoch ~/ 1000;
  final nonce = 'a1' * 16;

  test('Vermerk wird geschrieben und wieder gelesen', () {
    final t = InviteTicket(nonce: nonce, expires: now + 3600);
    expect(t.encode(), <String, Object?>{'v': 1, 'n': nonce, 'exp': now + 3600});
    final back = InviteTicket.decode(t.encode(), nowSeconds: now)!;
    expect(back.nonce, nonce);
    expect(back.expires, now + 3600);
    expect(back.used, isFalse);
  });

  test('verbrauchter Vermerk trägt die Markierung', () {
    final t = InviteTicket(nonce: nonce, expires: now + 60, used: true);
    expect(t.encode()['used'], true);
    expect(InviteTicket.decode(t.encode(), nowSeconds: now)!.used, isTrue);
  });

  test('automatische Bestätigung ist nur gesetzt, wenn der Vermerk es sagt', () {
    final t = InviteTicket(nonce: nonce, expires: now + 60, auto: true);
    expect(t.encode()['auto'], true);
    expect(InviteTicket.decode(t.encode(), nowSeconds: now)!.auto, isTrue);
    expect(InviteTicket.decode(InviteTicket(nonce: nonce, expires: now + 60).encode(), nowSeconds: now)!.auto, isFalse);
    expect(InviteTicket.decode(<String, Object?>{...t.encode(), 'auto': 'ja'}, nowSeconds: now), isNull);
  });

  test('ungültige Inhalte werden verworfen', () {
    Map<String, Object?> ok() => <String, Object?>{'v': 1, 'n': nonce, 'exp': now + 3600};
    expect(InviteTicket.decode(ok(), nowSeconds: now), isNotNull);
    expect(InviteTicket.decode(<String, Object?>{...ok(), 'v': 2}, nowSeconds: now), isNull);
    expect(InviteTicket.decode(<String, Object?>{...ok(), 'n': 'kurz'}, nowSeconds: now), isNull);
    expect(InviteTicket.decode(<String, Object?>{...ok(), 'n': 'A' * 32}, nowSeconds: now), isNull, reason: 'nur Kleinbuchstaben-Hex');
    expect(InviteTicket.decode(<String, Object?>{...ok(), 'exp': '123'}, nowSeconds: now), isNull);
    expect(InviteTicket.decode(<String, Object?>{...ok(), 'exp': 0}, nowSeconds: now), isNull);
    expect(InviteTicket.decode(<String, Object?>{...ok(), 'exp': now + 30 * 86400}, nowSeconds: now), isNull, reason: 'zu weit in der Zukunft');
    expect(InviteTicket.decode(<String, Object?>{...ok(), 'used': 'ja'}, nowSeconds: now), isNull);
    expect(InviteTicket.decode(<String, Object?>{...ok(), 'extra': 1}, nowSeconds: now), isNull);
    expect(InviteTicket.decode(<String, Object?>{'v': 1, 'n': nonce}, nowSeconds: now), isNull);
  });
}
