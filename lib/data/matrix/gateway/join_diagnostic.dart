part of '../sdk_matrix_gateway.dart';

/// Stand der Ablehnungs-Abfrage für „Details“ im Familienschritt (#116), nur im Arbeitsspeicher. Enthält
/// ausschließlich feste Wörter, Zahlen und Zeiten: keine Raum-IDs, MXIDs oder Fehlertexte. Der Text ist
/// eine feste technische Ausgabe für Testberichte und wird deshalb nicht übersetzt.
class _JoinDiagnostic {
  String state = '-';
  String? membership;
  String? previous;
  bool? own;
  int? offsetSeconds;
  String trigger = '-';
  int polls = 0;
  final Map<String, int> timeouts = <String, int>{'auth': 0, 'headers': 0, 'body': 0};
  int maxGapSeconds = 0;
  DateTime? lastPoll;
  DateTime? detectedAt;

  void note(String newState) {
    state = newState;
    membership = previous = null;
    own = null;
    offsetSeconds = null;
  }

  void leaveOther({required String membership, required String previous, required bool own, required int offsetSeconds}) {
    this.membership = membership;
    this.previous = previous;
    this.own = own;
    this.offsetSeconds = offsetSeconds;
  }

  void polled(String by, DateTime now) {
    polls++;
    checked(by, now);
  }

  /// Durchlauf der Abfrage-Schleife, auch wenn er vor der Serveranfrage endet (`staleNote`): `Abfragen` zählt
  /// nur, was den Server erreicht.
  void checked(String by, DateTime now) {
    trigger = by;
    final last = lastPoll;
    if (last != null && now.difference(last).inSeconds > maxGapSeconds) maxGapSeconds = now.difference(last).inSeconds;
    lastPoll = now;
  }

  void timedOut(String phase) => timeouts[phase] = timeouts[phase]! + 1;

  static String _time(DateTime? t) => t == null ? '-' : '${t.toUtc().toIso8601String().substring(0, 19)}Z';

  String render({required bool timerActive, required DateTime now}) {
    final detected = detectedAt;
    return <String>[
      'Zustand: $state',
      if (membership != null) 'membership: $membership',
      if (previous != null) 'vorher: $previous',
      if (own != null) 'eigen: ${own! ? 'ja' : 'nein'}',
      if (offsetSeconds != null) 'Versatz: ${offsetSeconds}s',
      'Auslöser: $trigger',
      'Abfragen: $polls',
      'Zeitüberschreitungen: auth=${timeouts['auth']} headers=${timeouts['headers']} body=${timeouts['body']}',
      'Größter Abstand: ${maxGapSeconds}s',
      'Letzte Abfrage: ${_time(lastPoll)}',
      'Erkannt: ${detected == null ? '-' : '${_time(detected)} (${detected.millisecondsSinceEpoch})'}',
      'Timer aktiv: ${timerActive ? 'ja' : 'nein'}',
      'Angezeigt: ${_time(now)}',
    ].join('\n');
  }
}
