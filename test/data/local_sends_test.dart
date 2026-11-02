import 'dart:async';

import 'package:family_nexus/data/matrix/local_sends.dart';
import 'package:flutter_test/flutter_test.dart';

/// #138: Wiederholt wird der ursprüngliche Aufruf, gebunden an Thread und Raum.
void main() {
  const family = 'family';
  const room = '!a:x';
  late LocalSends s;

  setUp(() => s = LocalSends());

  Future<String?> run(
    String txid, {
    Future<String?> Function()? send,
    String tail = 'Hallo',
    int bytes = 0,
    String threadId = family,
    String roomId = room,
  }) =>
      s.run(txid: txid, threadId: threadId, roomId: roomId, tail: tail, bytes: bytes, send: send ?? () async => null);

  group('run', () {
    test('Erfolg: Sendung erledigt, Kennung und Text gemerkt', () async {
      expect(await run('t', send: () async => r'$e'), r'$e');
      expect(s.isOpen('t'), isFalse);
      expect(s.canRetry('t', family, room), isFalse);
      expect(s.sentMatches(r'$e', 'Hallo'), isTrue);
    });

    test('null: Sendung bleibt offen und wiederholbar', () async {
      expect(await run('t'), isNull);
      expect(s.isOpen('t'), isTrue);
      expect(s.isRunning('t'), isFalse);
      expect(s.canRetry('t', family, room), isTrue);
      expect(s.sentMatches('t', 'Hallo'), isFalse);
    });

    test('Ausnahme: Sendung bleibt offen, Ausnahme kommt durch', () async {
      await expectLater(run('t', send: () async => throw StateError('x')), throwsStateError);
      expect(s.isOpen('t'), isTrue);
      expect(s.isRunning('t'), isFalse);
      expect(s.canRetry('t', family, room), isTrue);
    });

    test('Ausnahme ohne await im Aufruf: bleibt ebenfalls offen', () async {
      await expectLater(run('t', send: () => throw StateError('x')), throwsStateError);
      expect(s.isOpen('t'), isTrue);
      expect(s.isRunning('t'), isFalse);
    });

    test('während des Laufs: offen, laufend, nicht wiederholbar', () async {
      final c = Completer<String?>();
      final f = run('t', send: () => c.future);
      expect(s.isOpen('t'), isTrue);
      expect(s.isRunning('t'), isTrue);
      expect(s.canRetry('t', family, room), isFalse);
      c.complete(r'$e');
      await f;
      expect(s.isRunning('t'), isFalse);
    });

    test('isRunning und isOpen vertragen eine fehlende Kennung', () {
      expect(s.isRunning(null), isFalse);
      expect(s.isOpen(null), isFalse);
    });
  });

  group('retry', () {
    test('ruft den ursprünglichen Aufruf und erledigt die Sendung bei Erfolg', () async {
      var calls = 0;
      await run('t', send: () async => ++calls == 2 ? r'$e' : null);
      expect(await s.retry('t', family, room), r'$e');
      expect(calls, 2);
      expect(s.isOpen('t'), isFalse);
      expect(s.sentMatches(r'$e', 'Hallo'), isTrue);
    });

    test('läuft wie run: während des Versuchs nicht wiederholbar, danach wieder', () async {
      final answers = <Completer<String?>>[Completer<String?>()..complete(null), Completer<String?>()];
      var i = 0;
      await run('t', send: () => answers[i++].future);
      final f = s.retry('t', family, room);
      expect(s.isRunning('t'), isTrue);
      expect(s.canRetry('t', family, room), isFalse);
      answers[1].complete(null);
      await f;
      expect(s.canRetry('t', family, room), isTrue);
    });

    test('Ausnahme beim Wiederholen: bleibt offen, läuft nicht mehr', () async {
      var calls = 0;
      await run('t', send: () async {
        if (++calls == 2) throw StateError('x');
        return null;
      });
      await expectLater(s.retry('t', family, room), throwsStateError);
      expect(s.canRetry('t', family, room), isTrue);
    });

    test('anderer Thread oder anderer Raum: kein Versuch', () async {
      var calls = 0;
      await run('t', send: () async {
        calls++;
        return null;
      });
      expect(s.canRetry('t', '!dm:x', room), isFalse);
      expect(s.canRetry('t', family, '!b:x'), isFalse);
      expect(await s.retry('t', '!dm:x', room), isNull);
      expect(await s.retry('t', family, '!b:x'), isNull);
      expect(calls, 1);
    });

    test('unbekannte Kennung: kein Versuch', () async {
      expect(await s.retry('x', family, room), isNull);
    });
  });

  group('takeAutoRetry', () {
    test('zählt bis zur Grenze, unbekannte Kennung nie', () async {
      s = LocalSends(maxRetries: 2);
      await run('t');
      expect(s.takeAutoRetry('t'), isTrue);
      expect(s.takeAutoRetry('t'), isTrue);
      expect(s.takeAutoRetry('t'), isFalse);
      expect(s.takeAutoRetry('x'), isFalse);
    });

    test('kein Zeitleisten-Ereignis setzt ihn zurück: Abfragen ändern nichts', () async {
      s = LocalSends(maxRetries: 1);
      await run('t');
      expect(s.takeAutoRetry('t'), isTrue);
      s.sentMatches('t', 'Hallo');
      s.canRetry('t', family, room);
      expect(s.takeAutoRetry('t'), isFalse);
    });

    test('ein gescheiterter Versuch setzt ihn nicht zurück', () async {
      s = LocalSends(maxRetries: 1);
      await run('t');
      expect(s.takeAutoRetry('t'), isTrue);
      await s.retry('t', family, room);
      expect(s.takeAutoRetry('t'), isFalse);
    });

    test('nach dem Erfolg ist die Sendung weg, der Zähler auch', () async {
      var calls = 0;
      await run('t', send: () async => ++calls == 2 ? r'$e' : null);
      expect(s.takeAutoRetry('t'), isTrue);
      await s.retry('t', family, room);
      expect(s.takeAutoRetry('t'), isFalse);
    });
  });

  group('sentMatches', () {
    test('Antwort mit Zitat: body endet mit dem Text', () async {
      await run('t', send: () async => r'$e', tail: 'Ich');
      expect(s.sentMatches(r'$e', '> <@ben:x> Wer holt ab?\n\nIch'), isTrue);
    });

    test('fremder Text oder fremde Kennung: kein Treffer', () async {
      await run('t', send: () async => r'$e', tail: 'Ich');
      expect(s.sentMatches(r'$e', 'Ich nicht'), isFalse);
      expect(s.sentMatches(r'$x', 'Ich'), isFalse);
      expect(s.sentMatches('t', 'Ich'), isFalse, reason: 'die Transaktions-ID ist keine Server-Kennung');
    });

    test('höchstens maxSentIds Kennungen, die älteste fällt heraus', () async {
      s = LocalSends(maxSentIds: 2);
      for (var i = 0; i < 3; i++) {
        await run('t$i', send: () async => '\$e$i');
      }
      expect(s.sentMatches(r'$e0', 'Hallo'), isFalse);
      expect(s.sentMatches(r'$e1', 'Hallo'), isTrue);
      expect(s.sentMatches(r'$e2', 'Hallo'), isTrue);
    });
  });

  group('Grenzen', () {
    test('Anzahl: der älteste nicht laufende fällt heraus', () async {
      s = LocalSends(maxOpen: 2);
      await run('a');
      await run('b');
      await run('c');
      expect(s.isOpen('a'), isFalse);
      expect(s.isOpen('b'), isTrue);
      expect(s.isOpen('c'), isTrue);
      expect(s.canRetry('a', family, room), isFalse);
    });

    test('Bytes: die ältesten fallen heraus, bis die Grenze hält', () async {
      s = LocalSends(maxOpenBytes: 100);
      await run('a', bytes: 40);
      await run('b', bytes: 40);
      await run('c', bytes: 90);
      expect(s.isOpen('a'), isFalse);
      expect(s.isOpen('b'), isFalse);
      expect(s.isOpen('c'), isTrue);
    });

    test('Standardwerte: 50 Sendungen, 100 MiB, 2000 Kennungen', () {
      expect(s.maxOpen, 50);
      expect(s.maxOpenBytes, 100 * 1024 * 1024);
      expect(s.maxSentIds, 2000);
    });

    test('erledigte Sendungen geben ihre Bytes frei', () async {
      s = LocalSends(maxOpenBytes: 100);
      await run('a', bytes: 90);
      await run('b', bytes: 90, send: () async => r'$e');
      expect(s.isOpen('a'), isFalse, reason: 'b lief, a fiel heraus');
      await run('c', bytes: 90);
      await run('d', bytes: 5);
      expect(s.isOpen('c'), isTrue, reason: 'die Bytes von b zählen nicht mehr');
      expect(s.isOpen('d'), isTrue);
    });

    test('laufende Sendungen fallen nicht heraus, auch nicht über der Grenze', () async {
      s = LocalSends(maxOpen: 1, maxOpenBytes: 10);
      final gates = <Completer<String?>>[Completer<String?>(), Completer<String?>()];
      final a = run('a', send: () => gates[0].future, bytes: 8);
      final b = run('b', send: () => gates[1].future, bytes: 8);
      expect(s.isRunning('a'), isTrue);
      expect(s.isRunning('b'), isTrue);

      // Nach dem Ende gelten die Grenzen wieder; die ältere fällt heraus.
      gates[0].complete(null);
      await a;
      expect(s.isOpen('a'), isFalse);
      expect(s.isRunning('b'), isTrue);
      gates[1].complete(r'$b');
      await b;
      expect(s.sentMatches(r'$b', 'Hallo'), isTrue);
    });

    test('eine wiederholte Sendung fällt während des Versuchs nicht heraus', () async {
      s = LocalSends(maxOpen: 1);
      final gate = Completer<String?>();
      var calls = 0;
      await run('a', send: () => ++calls == 1 ? Future<String?>.value() : gate.future);
      final retry = s.retry('a', family, room);
      final b = run('b');
      expect(s.isOpen('a'), isTrue, reason: 'läuft gerade');
      await b;
      gate.complete(r'$a');
      await retry;
      expect(s.sentMatches(r'$a', 'Hallo'), isTrue);
    });
  });

  group('clear', () {
    test('entfernt Sendungen, Kennungen und den Byte-Stand', () async {
      s = LocalSends(maxOpenBytes: 100);
      await run('a', bytes: 90);
      await run('b', send: () async => r'$e');
      s.clear();
      expect(s.openCount, 0);
      expect(s.sentMatches(r'$e', 'Hallo'), isFalse);
      await run('c', bytes: 90);
      expect(s.isOpen('c'), isTrue, reason: 'der Byte-Stand beginnt neu');
    });

    test('während eines laufenden run: kein Absturz, nichts wird nachgetragen', () async {
      final c = Completer<String?>();
      final f = run('t', send: () => c.future, bytes: 10);
      s.clear();
      c.complete(r'$e');
      expect(await f, r'$e');
      expect(s.isOpen('t'), isFalse);
      expect(s.sentMatches(r'$e', 'Hallo'), isFalse, reason: 'die Sendung gehört nicht mehr zu dieser Sitzung');
      expect(s.isRunning('t'), isFalse);
    });

    test('während eines laufenden run, der scheitert: kein Absturz', () async {
      final c = Completer<String?>();
      final f = run('t', send: () => c.future);
      s.clear();
      c.completeError(StateError('x'));
      await expectLater(f, throwsStateError);
      expect(s.openCount, 0);
    });

    test('alte Sendung derselben Kennung trifft keine neue', () async {
      final c = Completer<String?>();
      final f = run('t', send: () => c.future);
      s.clear();
      await run('t');
      c.complete(r'$e');
      await f;
      expect(s.isOpen('t'), isTrue, reason: 'die neue Sendung bleibt offen');
      expect(s.sentMatches(r'$e', 'Hallo'), isFalse);
    });
  });
}
