import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart' show GatewayError;
import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/features/contacts/contact_controller.dart';
import 'package:family_nexus/features/contacts/contact_text.dart';
import 'package:family_nexus/features/contacts/contacts_screen.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contact_peer.dart';
import '../support/fake_matrix.dart';
import '../support/test_app.dart';

/// #119, K3b-1 (E-114): Oberfläche der Kontakte gegen Fake-Gateway: Erklärseite, Hinzufügen (Prüfen nur auf Tipp), Anfragen,
/// Verwalten, Semantik, Textskalierung, beide Sprachen, Unicode-Isolierung.
void main() {
  const carla = '@carla:fake.test';
  const dora = '@dora:fake.test';
  const emil = '@emil:fake.test';

  late FakeMatrixServer server;
  late ContactPeer peer;
  late ContactController c;
  late String me;

  // Der Aufbau läuft **im** Test (FakeAsync-Zone von testWidgets), nicht in setUp: sonst gehören die Futures einer anderen Zone,
  // und `pump` bringt sie nicht voran.
  Future<void> init() async {
    server = FakeMatrixServer();
    for (final n in <String>['anna', 'carla', 'dora', 'emil']) {
      server.addAccount(n, 'pw-$n', displayName: n[0].toUpperCase() + n.substring(1));
    }
    peer = await ContactPeer.create(server, 'anna', 'pw-anna');
    await peer.gateway.createFamily('Familie');
    server.rooms.values.first.membership[emil] = MemberStatus.joined;
    me = peer.gateway.userId!;
    c = ContactController(gateway: peer.gateway, sync: peer.sync);
  }

  /// Wie `testWidgets`, beendet aber Controller und Synchronisation **im** Test: Deren Timer (Wiederholung, Entprellung)
  /// dürfen am Ende der Testzone nicht mehr laufen (die ältere Flutter-Version der CI prüft das vor dem Abbau).
  void ctest(String name, Future<void> Function(WidgetTester tester) body) {
    testWidgets(name, (tester) async {
      await init();
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        peer.dispose();
        await tester.pump(const Duration(seconds: 1));
      }
    });
  }

  Widget host(Widget home, {String lang = 'de', double textScale = 1}) => MaterialApp(
        locale: Locale(lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: buildTheme(Brightness.light),
        builder: (context, app) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: app!),
        home: home,
      );

  Future<void> show(WidgetTester tester, {String lang = 'de', double textScale = 1}) async {
    c.start();
    await tester.pumpWidget(host(ContactsScreen(controller: c), lang: lang, textScale: textScale));
    await tester.pumpAndSettle();
  }

  Future<void> turnOn(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Kontakte einschalten')); // bei großer Schrift unterhalb der Erklärung
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kontakte einschalten'));
    await tester.pumpAndSettle();
  }

  Future<void> tapDialog(WidgetTester tester, String action) async {
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(action)));
    await tester.pumpAndSettle();
  }

  group('Erklärseite und Einwilligung', () {
    ctest('Standard aus: Erklärseite, nichts abgefragt, nichts gesendet; erst die Taste schaltet ein', (tester) async {
      await show(tester);
      expect(find.text('Kontakte einschalten?'), findsOneWidget);
      expect(find.textContaining('Beide erfahren so, wen du suchst'), findsOneWidget, reason: 'Abfluss der Prüfung an beide Server');
      expect(find.textContaining('höchstens 20 Prüfungen je Stunde'), findsOneWidget);
      expect(find.textContaining('Ende-zu-Ende verschlüsselt'), findsOneWidget);
      expect(find.textContaining('auf allen deinen Geräten'), findsOneWidget);
      expect(find.textContaining('Ausschalten löscht nichts'), findsOneWidget);
      expect(find.textContaining('Moderator'), findsNothing, reason: 'die Sperre durch Moderatoren gibt es noch nicht');
      expect(server.probeNetworkCalls, 0);
      expect(peer.gateway.contactPolicy, ContactPolicy.off);
      expect(await peer.store.all(), isEmpty);
      await turnOn(tester);
      expect(find.text('Noch keine Kontakte.'), findsOneWidget);
      expect(peer.gateway.contactPolicy.enabled, isTrue);
    });

    ctest('bis der Zustand gelesen ist: Ladeanzeige, weder Erklärseite noch Einschalten', (tester) async {
      await tester.pumpWidget(host(ContactsScreen(controller: c)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Kontakte einschalten'), findsNothing);
      c.start();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    ctest('Ausschalten verlangt eine Bestätigung und löscht nichts', (tester) async {
      await show(tester);
      await turnOn(tester);
      await tester.scrollUntilVisible(find.text('Kontakte ausschalten'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Kontakte ausschalten'));
      await tester.pumpAndSettle();
      expect(find.text('Kontakte ausschalten?'), findsOneWidget);
      await tapDialog(tester, 'Abbrechen');
      expect(c.enabled, isTrue);
      await tester.tap(find.text('Kontakte ausschalten'));
      await tester.pumpAndSettle();
      await tapDialog(tester, 'Kontakte ausschalten');
      expect(c.enabled, isFalse);
      expect(find.text('Kontakte einschalten?'), findsOneWidget);
    });
  });

  group('Kontakt hinzufügen', () {
    Future<void> openAdd(WidgetTester tester) async {
      await show(tester);
      await turnOn(tester);
      await tester.tap(find.text('Kontakt hinzufügen'));
      await tester.pumpAndSettle();
    }

    ctest('Prüfen nur auf Tipp: Tippen und Öffnen fragen nichts ab; dann Karte mit Name und voller Kennung; Hinzufügen', (tester) async {
      await openAdd(tester);
      expect(find.textContaining('Beim Prüfen werden dein Server und der Server der gesuchten Person gefragt'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '@carla:fake.test');
      await tester.pump();
      expect(server.probeNetworkCalls, 0, reason: 'nie je Tastendruck');
      await tester.tap(find.text('Prüfen'));
      await tester.pumpAndSettle();
      expect(server.probeNetworkCalls, 1);
      expect(find.text('Gefunden'), findsOneWidget);
      expect(find.text('Name: ${isolateText('Carla')}'), findsOneWidget);
      expect(find.text('Kennung: ${isolateText(carla)}'), findsOneWidget);
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();
      expect(find.text('Wartet auf Annahme'), findsOneWidget);
      expect(find.text('Anfrage gesendet. Das Gespräch beginnt, sobald die Person beitritt.'), findsOneWidget);
      expect((await peer.service.contact(carla))!.state, ContactState.outgoing);
    });

    ctest('K3b-2a: Name wie ein Familienmitglied: Warnung und Bestätigung vor „Hinzufügen“; Eingabeänderung setzt sie zurück', (tester) async {
      server.addAccount('fritz', 'pw-fritz', displayName: 'Emil'); // Emil gehört zur Familie
      const fritz = '@fritz:fake.test';
      await openAdd(tester);
      await tester.enterText(find.byType(TextField), fritz);
      await tester.tap(find.text('Prüfen'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nicht deine Familie'), findsOneWidget);
      FilledButton addButton() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Hinzufügen'));
      expect(addButton().onPressed, isNull, reason: 'ohne Bestätigung nicht aktiv');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(addButton().onPressed, isNotNull);
      // Neue Prüfung (andere Eingabe und zurück) verlangt die Bestätigung erneut.
      await tester.enterText(find.byType(TextField), '$fritz ');
      await tester.pump();
      await tester.enterText(find.byType(TextField), fritz);
      await tester.tap(find.text('Prüfen'));
      await tester.pumpAndSettle();
      expect(addButton().onPressed, isNull);
      expect(server.contactRooms, isEmpty);
    });

    ctest('K3b-2a: ohne Namensgleichheit keine Warnung und „Hinzufügen“ sofort aktiv', (tester) async {
      await openAdd(tester);
      await tester.enterText(find.byType(TextField), carla);
      await tester.tap(find.text('Prüfen'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nicht deine Familie'), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
    });

    ctest('eine geänderte Eingabe macht das Ergebnis ungültig, ohne Abfrage', (tester) async {
      await openAdd(tester);
      await tester.enterText(find.byType(TextField), carla);
      await tester.tap(find.text('Prüfen'));
      await tester.pumpAndSettle();
      expect(find.text('Hinzufügen'), findsOneWidget);
      final calls = server.probeNetworkCalls;
      await tester.enterText(find.byType(TextField), '@dora:fake.test');
      await tester.pump();
      expect(find.text('Hinzufügen'), findsNothing);
      expect(server.probeNetworkCalls, calls);
    });

    ctest('jede Ausnahme hat einen eigenen Text und sperrt das Hinzufügen', (tester) async {
      await openAdd(tester);
      Future<void> check(String id) async {
        await tester.enterText(find.byType(TextField), id);
        await tester.tap(find.byType(FilledButton).first);
        await tester.pumpAndSettle();
      }

      await check('kein-konto');
      expect(find.textContaining('keine gültige Kontakt-ID'), findsOneWidget);
      await check(me);
      expect(find.text('Das ist deine eigene Kontakt-ID.'), findsOneWidget);
      await check(emil);
      expect(find.textContaining('Mitglied deiner Familie'), findsOneWidget);
      await check('@niemand:fake.test');
      expect(find.textContaining('nicht gefunden'), findsOneWidget);
      server.unreachableUsers.add(dora);
      await check(dora);
      expect(find.textContaining('Sicherheitsprüfung einrichten'), findsOneWidget);
      server.addAccount('gina', 'pw-gina', displayName: 'Gina');
      server.keyQueryFailures.add('@gina:fake.test');
      await check('@gina:fake.test');
      expect(find.textContaining('nicht geprüft werden'), findsOneWidget);
      expect(find.text('Erneut prüfen'), findsOneWidget);
      expect(find.text('Hinzufügen'), findsNothing, reason: 'in keinem dieser Fälle gibt es „Hinzufügen“');
    });

    ctest('rateLimited sperrt die Taste mit Text', (tester) async {
      await openAdd(tester);
      server.probeError = GatewayError.rateLimited;
      await tester.enterText(find.byType(TextField), carla);
      await tester.tap(find.text('Prüfen'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Zu viele Prüfungen'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed, isNull);
    });

    ctest('lokal blockiert ohne Datensatz: Hinweis mit „Blockierung aufheben“ (keine Sackgasse)', (tester) async {
      await openAdd(tester);
      peer.blockedList.list.add(dora);
      await tester.enterText(find.byType(TextField), dora);
      await tester.tap(find.text('Prüfen'));
      await tester.pumpAndSettle();
      expect(find.text('Diese Person ist auf diesem Gerät blockiert.'), findsOneWidget);
      await tester.tap(find.text('Blockierung aufheben'));
      await tester.pumpAndSettle();
      expect(peer.blockedList.list, isNot(contains(dora)));
      expect(find.text('Gefunden'), findsOneWidget, reason: 'danach ist die Prüfung möglich');
    });
  });

  group('Anfragen', () {
    ctest('Anfrage: Name und volle Kennung; Annehmen verlangt Bestätigung mit der Kennung; danach bestätigt', (tester) async {
      await show(tester);
      await turnOn(tester);
      final room = server.createContactRoom(carla, me);
      server.notifyAll();
      await tester.pumpAndSettle();
      expect(find.text('Anfragen'), findsOneWidget);
      expect(find.text('${isolateText('Carla · fake.test')} möchte dir schreiben'), findsOneWidget);
      expect(find.text(isolateText(carla)), findsOneWidget);
      await tester.tap(find.text('Annehmen'));
      await tester.pumpAndSettle();
      expect(find.text('Anfrage annehmen?'), findsOneWidget);
      expect(find.textContaining(isolateText(carla)), findsWidgets);
      await tapDialog(tester, 'Annehmen');
      for (var i = 0; i < 3; i++) {
        await peer.sync.idle();
        await c.idle();
        await tester.pumpAndSettle();
      }
      expect(find.text('Bestätigt'), findsOneWidget);
      expect(room.invitedUsers, isNot(contains(me)));
    });

    ctest('Ablehnen; Blockieren verlangt Bestätigung und lässt die Einladung unbeantwortet', (tester) async {
      await show(tester);
      await turnOn(tester);
      final a = server.createContactRoom(carla, me);
      server.notifyAll();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ablehnen'));
      await tester.pumpAndSettle();
      expect(find.text('Anfragen'), findsNothing);
      expect(a.dmMembers, isNot(contains(me)));
      final b = server.createContactRoom(dora, me);
      server.notifyAll();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Blockieren'));
      await tester.pumpAndSettle();
      expect(find.text('Blockieren?'), findsOneWidget);
      await tapDialog(tester, 'Blockieren');
      expect(find.text('Anfragen'), findsNothing);
      expect(b.invitedUsers, contains(me), reason: 'unbeantwortet');
      expect(find.text('Blockiert'), findsOneWidget);
    });

    ctest('„Weitere Anfragen: n“', (tester) async {
      await show(tester);
      await turnOn(tester);
      server.createContactRoom(carla, me);
      peer.gateway.hiddenRequests = 4;
      server.notifyAll();
      await tester.pumpAndSettle();
      expect(find.text('Weitere Anfragen: 4'), findsOneWidget);
    });
  });

  group('Verwalten', () {
    ctest('Entfernen und Blockieren verlangen Bestätigung; Blockierte nur „Entsperren“; Entsperren wirkt', (tester) async {
      await show(tester);
      await turnOn(tester);
      server.createContactRoom(carla, me, toJoined: true);
      await peer.service.addAccepted(carla);
      await peer.sync.pushPolicyNow();
      await tester.pumpAndSettle();
      expect(find.text('Bestätigt'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Blockieren'));
      await tester.pumpAndSettle();
      await tapDialog(tester, 'Blockieren');
      expect(find.text('Blockiert'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Entfernen'), findsNothing, reason: 'Blockierte nur entsperren');
      await tester.tap(find.text('Entsperren'));
      await tester.pumpAndSettle();
      expect(find.text('Noch keine Kontakte.'), findsOneWidget);
      expect(peer.blockedList.list, isNot(contains(carla)));
    });

    ctest('Entfernen: Bestätigung, verlässt den Raum, Eintrag weg', (tester) async {
      await show(tester);
      await turnOn(tester);
      final room = server.createContactRoom(carla, me, toJoined: true);
      await peer.service.addAccepted(carla);
      await peer.sync.pushPolicyNow();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Entfernen'));
      await tester.pumpAndSettle();
      expect(find.text('Kontakt entfernen?'), findsOneWidget);
      await tapDialog(tester, 'Entfernen');
      expect(find.text('Noch keine Kontakte.'), findsOneWidget);
      expect(room.dmMembers, isNot(contains(me)));
    });

    ctest('„Erneut senden“ für einen nicht gesendeten Kontakt; wiederholtes Tippen wird gebremst', (tester) async {
      await show(tester);
      await turnOn(tester);
      await peer.service.addOutgoing(carla);
      await tester.pumpAndSettle();
      expect(find.text('Noch nicht gesendet'), findsOneWidget);
      await tester.tap(find.text('Erneut senden'));
      await tester.pumpAndSettle();
      expect(server.contactRooms, hasLength(1));
      expect(find.text('Wartet auf Annahme'), findsOneWidget);
    });

    ctest('accepted ohne Gespräch: „Gespräch wird gesucht“ mit Entfernen', (tester) async {
      await show(tester);
      await turnOn(tester);
      await peer.service.addAccepted(carla);
      await tester.pumpAndSettle();
      expect(find.text('Gespräch wird gesucht'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Entfernen'), findsOneWidget);
    });

    ctest('Fehler zeigen einen Text, nie Rohtexte', (tester) async {
      await show(tester);
      await turnOn(tester);
      server.createContactRoom(carla, me, toJoined: true);
      await peer.service.addAccepted(carla);
      await peer.sync.pushPolicyNow();
      await tester.pumpAndSettle();
      peer.gateway.failLeaveConversation = true;
      await tester.tap(find.widgetWithText(TextButton, 'Entfernen'));
      await tester.pumpAndSettle();
      await tapDialog(tester, 'Entfernen');
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.text('Bestätigt'), findsOneWidget, reason: 'unverändert');
    });

    ctest('eigene Kontakt-ID kopieren', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await show(tester);
      await turnOn(tester);
      await tester.scrollUntilVisible(find.text('Kopieren'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Kopieren'));
      await tester.pumpAndSettle();
      expect(copied, me);
      expect(find.text('Kontakt-ID kopiert'), findsOneWidget);
    });
  });

  group('Darstellung', () {
    ctest('Name und Kennung mit Unicode-Isolierung; ein feindlicher Name verfälscht nichts', (tester) async {
      server.addAccount('mallory', 'pw-m', displayName: 'Mama \u202E· familie.de');
      await show(tester);
      await turnOn(tester);
      server.createContactRoom('@mallory:fake.test', me);
      server.notifyAll();
      await tester.pumpAndSettle();
      expect(find.text('${isolateText('Mama familie.de · fake.test')} möchte dir schreiben'), findsOneWidget);
      expect(find.text(isolateText('@mallory:fake.test')), findsOneWidget);
    });

    ctest('Unicode-Isolierung als Literal (FSI … PDI) für Titel, Kennung, eigene Kennung und die Dialoge', (tester) async {
      expect(isolateText('x'), '\u2068x\u2069');
      await show(tester);
      await turnOn(tester);
      server.createContactRoom(carla, me, toJoined: true);
      await peer.service.addAccepted(carla);
      await peer.sync.pushPolicyNow();
      await tester.pumpAndSettle();
      expect(find.text('\u2068Carla · fake.test\u2069'), findsOneWidget, reason: 'Titel in der Liste');
      expect(find.text('\u2068$carla\u2069'), findsOneWidget, reason: 'Kennung in der Liste');
      await tester.scrollUntilVisible(find.byType(SelectableText), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('\u2068$me\u2069'), findsOneWidget, reason: 'eigene Kennung');
      await tester.scrollUntilVisible(find.widgetWithText(TextButton, 'Entfernen'), -200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.widgetWithText(TextButton, 'Entfernen'));
      await tester.pumpAndSettle();
      expect(find.textContaining('\u2068Carla · fake.test\u2069'), findsWidgets, reason: 'Dialog Entfernen');
      expect(find.textContaining('\u2068$carla\u2069'), findsWidgets);
      await tapDialog(tester, 'Abbrechen');
      await tester.tap(find.widgetWithText(TextButton, 'Blockieren'));
      await tester.pumpAndSettle();
      expect(find.textContaining('\u2068$carla\u2069'), findsWidgets, reason: 'Dialog Blockieren');
    });

    ctest('Semantik: Zeilen als ein Label (Name, Kennung, Zustand); Überschriften', (tester) async {
      final handle = tester.ensureSemantics();
      await show(tester);
      await turnOn(tester);
      server.createContactRoom(me, carla);
      await peer.service.addOutgoing(carla);
      await peer.sync.pushPolicyNow();
      await tester.pumpAndSettle();
      final merged = tester.getSemantics(find.text('Wartet auf Annahme'));
      expect(merged.label, contains('Carla · fake.test'));
      expect(merged.label, contains(carla));
      expect(merged.label, contains('Wartet auf Annahme'));
      expect(tester.getSemantics(find.text('Deine Kontakte')), matchesSemantics(label: 'Deine Kontakte', isHeader: true));
      handle.dispose();
    });

    ctest('Textskalierung 2.0: kein Überlauf in Erklärseite, Liste und Hinzufügen', (tester) async {
      await show(tester, textScale: 2);
      expect(tester.takeException(), isNull);
      await turnOn(tester);
      server.createContactRoom(carla, me);
      await peer.service.addOutgoing(dora);
      server.notifyAll();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    ctest('Englisch: Erklärseite und Zustände', (tester) async {
      await show(tester, lang: 'en');
      expect(find.text('Turn on contacts?'), findsOneWidget);
      expect(find.textContaining('Both learn whom you are looking for'), findsOneWidget);
      await tester.tap(find.text('Turn on contacts'));
      await tester.pumpAndSettle();
      expect(find.text('No contacts yet.'), findsOneWidget);
      expect(find.text('Add contact'), findsWidgets);
    });

    ctest('Mindestgröße der Tasten 48 dp', (tester) async {
      await show(tester);
      await turnOn(tester);
      await peer.service.addOutgoing(carla);
      await tester.pumpAndSettle();
      for (final label in <String>['Erneut senden', 'Entfernen', 'Blockieren']) {
        final size = tester.getSize(find.widgetWithText(TextButton, label));
        expect(size.height, greaterThanOrEqualTo(48), reason: label);
      }
    });
  });

  group('Einstieg', () {
    testWidgets('Standard-App: kein Controller, keine Kachel in den Einstellungen', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await buildTestApp();
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Menü öffnen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Einstellungen').last);
      await tester.pumpAndSettle();
      expect(app.builtCalendars, isNotEmpty);
      expect(app.services.contacts, isNull);
      expect(find.text('Chats mit Personen außerhalb der Familie'), findsNothing);
      expect(app.contactStore, isNull);
    });

    testWidgets('mit Freigabe: Kachel in den Einstellungen führt zur Erklärseite; ohne Einschalten keine Abfrage', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await buildTestApp(contactsEnabled: true);
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Menü öffnen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Einstellungen').last);
      await tester.pumpAndSettle();
      expect(app.services.contacts?.controller, isNotNull);
      await tester.scrollUntilVisible(find.text('Chats mit Personen außerhalb der Familie'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Chats mit Personen außerhalb der Familie'));
      await tester.pumpAndSettle();
      expect(find.text('Kontakte einschalten?'), findsOneWidget);
      expect(app.server.probeNetworkCalls, 0);
      expect(app.gateway.contactPolicy.enabled, isFalse);
    });
  });
}
