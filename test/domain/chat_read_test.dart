import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/chat_read.dart';
import 'package:flutter_test/flutter_test.dart';

/// #526, E-106: Statuszeile unter eigenen Nachrichten, strukturiert und ohne Text.
const String _me = '@ida:fake.test';
const String _ben = '@ben:fake.test';
const String _cleo = '@cleo:fake.test';

ChatMessage _msg({String sender = _me, MessageStatus status = MessageStatus.sent, Set<String> readBy = const <String>{}}) =>
    ChatMessage(id: r'$a', senderId: sender, senderName: 'x', time: DateTime.utc(2026), status: status, readBy: readBy);

void main() {
  test('sending → sent → read(1) → read(n)', () {
    expect(deliveryLine(_msg(status: MessageStatus.sending), myUserId: _me), const DeliveryLine(DeliveryStage.sending));
    expect(deliveryLine(_msg(), myUserId: _me), const DeliveryLine(DeliveryStage.sent));
    expect(deliveryLine(_msg(readBy: <String>{_ben}), myUserId: _me), const DeliveryLine(DeliveryStage.read, 1));
    expect(deliveryLine(_msg(readBy: <String>{_ben, _cleo}), myUserId: _me), const DeliveryLine(DeliveryStage.read, 2));
  });

  test('gescheiterte Nachricht: keine Statuszeile (eigene Darstellung)', () {
    expect(deliveryLine(_msg(status: MessageStatus.failed, readBy: <String>{_ben}), myUserId: _me), isNull);
  });

  test('fremde Nachricht und fehlende eigene ID: keine Statuszeile', () {
    expect(deliveryLine(_msg(sender: _ben, readBy: <String>{_cleo}), myUserId: _me), isNull);
    expect(deliveryLine(_msg(), myUserId: null), isNull);
  });

  test('Sammelhinweis und nicht lesbare Nachricht: keine Statuszeile', () {
    final hint = ChatMessage(id: 'before-join', senderId: _me, senderName: '', time: DateTime.utc(2026), beforeJoin: true);
    final undecryptable = ChatMessage(id: r'$u', senderId: _me, senderName: '', time: DateTime.utc(2026), undecryptable: true);
    expect(deliveryLine(hint, myUserId: _me), isNull);
    expect(deliveryLine(undecryptable, myUserId: _me), isNull);
  });

  test('blockierte Nutzer zählen nicht als Leser', () {
    final m = _msg(readBy: <String>{_ben, _cleo});
    expect(deliveryLine(m, myUserId: _me, blocked: <String>{_ben}), const DeliveryLine(DeliveryStage.read, 1));
    expect(deliveryLine(m, myUserId: _me, blocked: <String>{_ben, _cleo}), const DeliveryLine(DeliveryStage.sent));
    expect(readersOf(m, <String>{_ben}), <String>{_cleo});
  });

  test('copyWith übernimmt readBy und lässt es sonst unverändert', () {
    final m = _msg(readBy: <String>{_ben});
    expect(m.copyWith(status: MessageStatus.sent).readBy, <String>{_ben});
    expect(m.copyWith(readBy: <String>{_cleo}).readBy, <String>{_cleo});
    expect(ChatMessage(id: 'x', senderId: 'y', senderName: 'z', time: DateTime.utc(2026)).readBy, isEmpty);
  });
}
