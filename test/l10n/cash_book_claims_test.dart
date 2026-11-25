import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/data/db/sql_data_inventory.dart';
import 'package:family_nexus/domain/cash_book.dart';
import 'package:flutter_test/flutter_test.dart';

/// #311, E-113 (Teil 4b): Pflichtinhalt der Datenschutztexte zum Kassenbuch (App und Store) und Wächter für die Store-Texte,
/// solange die Funktion gesperrt ist. Belege der Aussagen im Code: Löschen erzeugt ein neues Ereignis
/// (`CashBookCodec`-Tombstone, nur die Bon-Datei wird in `book_receipts.dart` geschwärzt), `history_visibility: shared`
/// (`book_room_spec.dart`), EXIF/ICC leert `ReceiptPhotoProcessing` (`receipt_photo_processing_test.dart`), der Ersteller
/// verlässt beim Familienwechsel automatisch (`cash_book_sync_test.dart`, Gruppe „Familienwechsel“), `canLeave`
/// (`cash_book_controller_test.dart`), Entfernen durch den Abgleich (`book_gateway_test.dart`), lokales Wischen
/// (`logout_wipe_test.dart`).
Map<String, dynamic> _arb(String lang) => json.decode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

String _flat(String s) => s.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  final de = _arb('de');
  final en = _arb('en');

  final needles = <String, Map<String, List<String>>>{
    'de': <String, List<String>>{
      'privacy2Body': <String>['Kassenbücher (Datum, Geschäft, Betrag, Währung, Notiz und optional ein Foto des Bons'],
      'privacy3Body': <String>['Mitglieder, Zeitpunkte und Größen der Ereignisse eines Kassenbuchs', 'nicht dessen Inhalt'],
      'privacy12Body': <String>[
        'Kassenbücher',
        'alle Mitglieder eines Buchs sehen alle Einträge und Bons',
        'sieht auch den bisherigen Verlauf, auch frühere Fassungen',
        'Kameradaten und Ortsangaben (EXIF) entfernt',
        'Karten- oder Personendaten',
        'Frühere Fassungen bleiben verschlüsselt im Verlauf',
        'nach bestem Bemühen geschwärzt',
        'behält, was er schon erhalten hat',
        'wer sie schon erhalten hat, behält sie',
        'kann ein Buch nicht von Hand verlassen',
        'verlässt sein Gerät das Buch automatisch',
        'bis der Abgleich auf dem Gerät des Erstellers',
        'nicht mehr Moderator',
      ],
      'reportOnlineNote': <String>['auch in Kassenbüchern'],
      'accountDeleteBody': <String>['Kassenbüchern angelegt hast, bleiben verschlüsselt im Buch bei den Mitgliedern, auch frühere Fassungen', '(frühere Fassungen bleiben dennoch im Verlauf)'],
      'cashInviteConfirmBody': <String>['bisherigen Verlauf'],
      'logoutBody': <String>['Kassenbücher', 'Kontakte', 'Geburts- und Gedenktage', 'Avatar-Fotos', 'beim Beenden der Sitzung'],
    },
    'en': <String, List<String>>{
      'privacy2Body': <String>['cash books (date, store, amount, currency, note and optionally a photo of the receipt'],
      'privacy3Body': <String>['members, times and sizes of the events of a cash book', 'not its content'],
      'privacy12Body': <String>[
        'Cash books',
        'all members of a book see all entries and receipts',
        'also sees the earlier history, including earlier versions',
        'camera data and location data (EXIF) are removed',
        'card or personal data',
        'earlier versions remain encrypted in the history',
        'best-effort basis',
        'keeps what they have already received',
        'whoever already received it keeps it',
        'cannot leave a book by hand',
        'their device leaves the book automatically',
        'until the reconciliation on the creator’s device',
        'no longer a moderator',
      ],
      'reportOnlineNote': <String>['also in cash books'],
      'accountDeleteBody': <String>['cash books remain encrypted in the book with the members, including earlier versions', '(earlier versions still remain in the history)'],
      'cashInviteConfirmBody': <String>['earlier history'],
      'logoutBody': <String>['cash books', 'contacts', 'birthdays and memorial days', 'avatar photos', 'when the session ends'],
    },
  };

  for (final lang in <String>['de', 'en']) {
    final a = lang == 'de' ? de : en;
    test('$lang: App-Texte nennen die Pflichtaussagen zum Kassenbuch', () {
      needles[lang]!.forEach((key, list) {
        for (final n in list) {
          expect(_flat(a[key] as String), contains(n), reason: '$key: $n');
        }
      });
    });
  }

  test('accountDeleteBody bleibt frei von „Matrix-ID“ (wording_test), die Wortlisten des Stores gelten auch hier', () {
    for (final t in <String>[de['accountDeleteBody'] as String, en['accountDeleteBody'] as String]) {
      expect(t, isNot(contains('Matrix-ID')));
      expect(t, isNot(contains('Matrix ID')));
    }
  });

  group('Store-Datenschutzerklärung', () {
    final texts = <String, String>{
      'de': _flat(File('store/privacy/privacy-policy.de.md').readAsStringSync()),
      'en': _flat(File('store/privacy/privacy-policy.en.md').readAsStringSync()),
    };
    final store = <String, List<String>>{
      'de': <String>[
        '| Kassenbücher (Datum, Geschäft, Betrag, Währung, Notiz, optional ein verkleinertes Foto des Bons ohne Kameradaten und Ortsangaben)',
        'Alle Mitglieder eines Buchs sehen alle Einträge und Bons, auch den bisherigen Verlauf',
        '- **Kassenbuch:** Jedes Buch ist ein eigener verschlüsselter Raum.',
        'auch für später Eingeladene (bisheriger Verlauf, auch frühere Fassungen von Einträgen)',
        'im Klartext, dass der Raum ein Kassenbuch der Familie ist, nicht den Inhalt',
        'Aufgaben, Geburts- und Gedenktage, Avatar-Fotos und Kassenbücher dieses Kontos vom Gerät',
        'frühere Fassungen bleiben im Verlauf, nur die eigene Bon-Datei wird nach bestem Bemühen geschwärzt',
        'Der Ersteller kann ein Buch nicht von Hand verlassen; wechselt er die Familie, verlässt sein Gerät das Buch automatisch',
        'bis der Abgleich auf dem Gerät des Erstellers (online, selbst in der Familie) ihn entfernt',
        'auch, wenn er nicht mehr Moderator ist',
        'sowie Geburts- und Gedenktage sind',
      ],
      'en': <String>[
        '| Cash books (date, store, amount, currency, note, optionally a reduced-size photo of the receipt without camera data and location data)',
        'All members of a book see all entries and receipts, including the earlier history',
        '- **Cash book:** Each book is a separate encrypted room.',
        'including those invited later (earlier history, including earlier versions of entries)',
        'in plain text, that the room is a cash book of the family, but not the content',
        'tasks, birthdays and memorial days, avatar photos and cash books of this account from the device',
        'earlier versions remain in the history, and only your own receipt file is redacted on a best-effort basis',
        'The creator cannot leave a book by hand; if they switch families, their device leaves the book automatically',
        'until the reconciliation on the creator\'s device (online, itself in the family) removes them',
        'this also applies if they are no longer a moderator',
      ],
    };
    for (final lang in <String>['de', 'en']) {
      test('$lang: nennt Kassenbuch, Verlauf, Löschen, Ersteller und Austritt; Datum geändert', () {
        for (final n in store[lang]!) {
          expect(texts[lang]!, contains(_flat(n)), reason: n);
        }
        expect(texts[lang]!, contains(lang == 'de' ? '**Stand: 24. November 2026**' : '**Last updated: 24 November 2026**'));
      });
    }
    test('Wortlisten (store_wording_test): „Einkaufszettel“ statt „Einkaufsliste“, „Datenübersicht“ statt „Datenprotokoll“', () {
      expect(texts['de'], isNot(contains('Einkaufsliste')));
      expect(texts['de'], isNot(contains('Datenprotokoll')));
      expect(texts['en'], isNot(contains('data log')));
    });
  });

  test('docs/STORE.md: Kassenbuch-Zeile, Finanzen als Zahlungs- und Kontodaten, Metadaten, Sperrhinweis', () {
    final t = File('docs/STORE.md').readAsStringSync();
    expect(t, contains('| Kassenbuch (Datum, Geschäft, Betrag, Währung, Notiz;'));
    expect(t, contains('| Standort, Kontakte, Fotos (automatisch), Gesundheit, Zahlungs- und Kontodaten | nein |'));
    expect(t, contains('bei Kassenbüchern Mitglieder, Zeitpunkte und Größen der Ereignisse'));
    expect(t, contains('Funktion freigeschaltet'));
  });

  test('solange das Kassenbuch gesperrt ist, nennen weder Beschreibung noch Release-Notes noch Store-Metadaten die Funktion', () {
    if (CashBookFlags.enabled) return; // der Freigabe-PR ändert diese Texte bewusst
    final files = Directory('store/metadata').listSync(recursive: true).whereType<File>().toList(); // jede Dateiart, nicht nur .txt
    expect(files, isNotEmpty);
    for (final f in files) {
      final t = f.readAsStringSync();
      expect(t.contains('Kassenbuch') || t.toLowerCase().contains('cash book'), isFalse, reason: f.path);
    }
  });

  test('logoutBody: jede lokal gespeicherte Datenart der Datenbank ist benannt oder ausdrücklich ausgenommen', () {
    // Tabelle → Stichwort in logoutBody (de und en); Tabellen ohne Stichwort sind Zubehör oder Einstellungen.
    const named = <String, (String, String)>{
      'events': ('Termine', 'Events'),
      'shopping_items': ('Einkaufszettel', 'shopping list'),
      'task_lists': ('Aufgaben', 'tasks'),
      'anniversaries': ('Geburts- und Gedenktage', 'birthdays and memorial days'),
      'avatar_photos': ('Avatar-Fotos', 'avatar photos'),
      'cash_books': ('Kassenbücher', 'cash books'),
      'cash_entries': ('Kassenbücher', 'cash books'),
      'contact_records': ('Kontakte', 'contacts'),
    };
    const accessory = <String>{
      'settings', // lokale Einstellungen bleiben (Sprache, Darstellung)
      'event_history', // Verlauf der Termine
      'rsvps', // Zusagen zu Terminen
      'event_reminders', // Erinnerungen zu Terminen
      'person_colors', // Farben der Personen
      'task_log', // Protokoll der Aufgaben
      'event_themes', // Themen der Termine
      'avatar_resets', // Rücksetzungen der Avatar-Fotos
    };
    for (final t in SqlDataInventory.tables) {
      expect(named.containsKey(t) || accessory.contains(t), isTrue, reason: 'neue Tabelle „$t“: in logoutBody nennen oder als Zubehör begründen');
    }
    for (final e in named.entries) {
      expect(de['logoutBody'], contains(e.value.$1), reason: e.key);
      expect(en['logoutBody'], contains(e.value.$2), reason: e.key);
    }
  });
}
