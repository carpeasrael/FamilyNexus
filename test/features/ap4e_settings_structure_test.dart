import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/semantics_snapshot.dart';
import '../support/test_app.dart';

/// AP-4e: Die Zerlegung von `SettingsScreen.build` ändert nicht, was ein Screenreader liest und bedienen kann.
/// Der Schnappschuss wurde vor dem Umbau am unveränderten Code aufgenommen.
void main() {
  testWidgets('Einstellungen: alle Abschnitte in der Standardausstattung', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await buildTestApp();
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menü öffnen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Einstellungen'));
    await tester.pumpAndSettle();
    final snap = semanticsSnapshot(tester, find.byType(SettingsScreen));
    expect(snap, _expectedSettings);
    handle.dispose();
  });
}

const List<String> _expectedSettings = <String>[
  'L=Darstellung | Akzentfarbe | Neonfarbe für Schaltflächen, Auswahl und Hervorhebungen. Gilt im hellen und im dunklen Design.',
  'L=Sprache',
  'L=Sprache | Deutsch button tap',
  'L=Design',
  'L=Design | Dunkel button tap',
  'L=Türkis button selected',
  'L=Magenta button',
  'L=Violett button',
  'L=Himmelblau button',
  'L=Limette button',
  'L=Orange button',
  'L=Rosé button',
  'L=Grün button',
  'L=Effekte reduzieren | Weniger Unschärfe und Leuchten, deckendere Flächen. tap',
  'tap',
  'L=Konto',
  'L=Server | fake.test',
  'L=Benutzername | @anna:fake.test',
  'L=Passwort ändern button tap',
  'L=Abmelden button tap',
  'L=Konto löschen | Matrix-Konto beim Anbieter dauerhaft löschen button tap',
  'L=Notfall-Schlüssel und Geräte | Geräte deines Kontos',
  'L=Dieses Gerät ist verifiziert.',
  'L=Neuen Notfall-Schlüssel erstellen | Falls du ihn verloren hast. In der App gilt danach nur der neue. button tap',
  'L=Gerät DEV1 (Dieses Gerät) | Verifiziert',
  'L=Erinnerungen | Erinnerungen sind lokale Benachrichtigungen dieses Geräts. Sie zeigen nie Titel oder Ort. | Standard-Erinnerung',
  'L=Zur Startzeit button tap',
  'L=5 Minuten vorher button tap',
  'L=10 Minuten vorher button selected tap',
  'L=15 Minuten vorher button tap',
  'L=30 Minuten vorher button tap',
  'L=1 Stunde vorher button tap',
  'L=2 Stunden vorher button tap',
  'L=1 Tag vorher button tap',
  'L=2 Tage vorher button tap',
  'L=Datenschutz | Blockierte Mitglieder | Nachrichten blockierter Mitglieder werden ausgeblendet. button tap',
  'L=App-Sperre | Sperrt die App nach Inaktivität. Die Bestätigung erfolgt mit der Sperre deines Geräts; die App speichert keine eigene PIN. Die Sperre ist ein Sichtschutz: Sie verdeckt die App, die Daten selbst schützt die Verschlüsselung und die Sperre deines Geräts. tap',
  'tap',
  'L=Online-Status teilen | Zeigt der Familie, wann du die App nutzt. Die Meldung geht nur Ende-zu-Ende-verschlüsselt an Geräte von Familienmitgliedern. Ausgeschaltet giltst du für andere als offline. tap',
  'tap',
  'L=Über die App | Speicherorte',
  'L=Datenschutzerklärung button tap',
  'L=Datenbank-Ordner V=/home/test/.local/share/de.inneso.familynexus/databases textfield',
  'L=App-Daten: Termine, Listen, Einstellungen (verschlüsselt) V=/home/test/.local/share/de.inneso.familynexus/databases/familynexus_app.db textfield',
  'L=Chat- und Abgleichsdaten: Matrix (verschlüsselt) V=/home/test/.local/share/de.inneso.familynexus/databases/familynexus_matrix.db textfield',
  'L=Datenbankschlüssel V=Schlüsselbund des Systems (Secret Service) textfield',
  'L=Online beim Matrix-Anbieter V=https://fake.test textfield',
  'L=Protokoll: alle lokal gespeicherten Daten zeigen button tap',
  'L=Protokoll: alle online gespeicherten Daten zeigen button tap',
  'L=Alle lokalen Daten löschen | Meldet dich ab und löscht Datenbank, Schlüssel und Erinnerungen auf diesem Gerät. button tap',
  'L=Einführung erneut ansehen button tap',
  'L=App teilen | Kopiert den Link zum Store-Eintrag, damit du ihn weitergeben kannst. Es werden keine Familiendaten geteilt. button tap',
  'L=App bewerten | Öffnet den Eintrag im Play Store. button tap',
  'L=Version 1.2.3 (28)',
  'L=Keine Telemetrie, keine Werbung, keine Analyse.',
  'L=Lizenz: AGPL-3.0-or-later',
  'L=Zurück T=Zurück button tap',
  'L=Einstellungen',
];
