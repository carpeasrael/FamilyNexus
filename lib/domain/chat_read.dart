import 'chat.dart';

/// Stufen der Statuszeile unter einer eigenen Nachricht (#526, E-106).
enum DeliveryStage { sending, sent, read }

/// Strukturierte Statuszeile einer eigenen Nachricht, ohne Text (die Oberfläche übersetzt sie).
class DeliveryLine {
  const DeliveryLine(this.stage, [this.readCount = 0]);

  final DeliveryStage stage;

  /// Anzahl der Leser; nur bei [DeliveryStage.read] größer als 0.
  final int readCount;

  @override
  bool operator ==(Object other) => other is DeliveryLine && other.stage == stage && other.readCount == readCount;

  @override
  int get hashCode => Object.hash(stage, readCount);

  @override
  String toString() => 'DeliveryLine($stage, $readCount)';
}

/// Statuszeile für [m], oder `null`: fremde Nachrichten, gescheiterte (eigene Darstellung), Hinweise ohne
/// Absender. [blocked] sind blockierte Nutzer; sie zählen nicht als Leser.
DeliveryLine? deliveryLine(ChatMessage m, {required String? myUserId, Set<String> blocked = const <String>{}}) {
  if (myUserId == null || m.senderId != myUserId || m.beforeJoin || m.undecryptable) return null;
  switch (m.status) {
    case MessageStatus.failed:
      return null;
    case MessageStatus.sending:
      return const DeliveryLine(DeliveryStage.sending);
    case MessageStatus.sent:
      final readers = readersOf(m, blocked);
      return readers.isEmpty ? const DeliveryLine(DeliveryStage.sent) : DeliveryLine(DeliveryStage.read, readers.length);
  }
}

/// Leser ohne eigene ID-unabhängige Sonderfälle: [ChatMessage.readBy] ohne blockierte Nutzer.
Set<String> readersOf(ChatMessage m, Set<String> blocked) => blocked.isEmpty ? m.readBy : m.readBy.difference(blocked);
