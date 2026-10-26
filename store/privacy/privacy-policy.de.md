# Datenschutzerklärung FamilyNexus

Diese Erklärung entspricht dem Text in der App (Einstellungen → Datenschutzerklärung). **Vor der Veröffentlichung ergänzen:** Verantwortlicher mit Anschrift und Kontakt (Impressum), Stand-Datum. Die Seite muss öffentlich unter einer festen URL erreichbar sein (Store-Pflicht).

**Verantwortlicher / Controller:** `<NAME UND ANSCHRIFT DES HERAUSGEBERS>` · `<KONTAKT-E-MAIL>`

## Wer verarbeitet deine Daten?

FamilyNexus ist freie Software (AGPL-3.0). Die App sendet keine Daten an die Entwickler und enthält keine Telemetrie, Werbung oder Analyse. Verantwortlich für die Verarbeitung auf dem Server ist der Betreiber des von dir gewählten Matrix-Servers; er wird bei der Einrichtung angezeigt.

## Welche Daten gibt es?

Chatnachrichten, Dateien, geteilte und private Termine, Zusagen, Einkaufszettel, Familienmitglieder und deine Einstellungen. Termine und Nachrichten liegen verschlüsselt (SQLCipher) auf deinem Gerät. Der Schlüssel dafür liegt im Android-Schlüsselspeicher und nie in einer Datei.

## Was sieht der Server?

Nachrichten, Dateien und geteilte Termine werden Ende-zu-Ende-verschlüsselt (Matrix, Olm/Megolm). Der Server sieht nur verschlüsselte Ereignisse. Metadaten wie Konto-ID, Zeitpunkte, Raumgröße und Geräte bleiben für den Betreiber sichtbar. Wer das vermeiden möchte, nutzt einen eigenen Server.

## Private Termine

Private Termine werden nie an die Familie gesendet. Zwischen deinen eigenen Geräten werden sie über einen privaten, verschlüsselten Raum abgeglichen, dem nur dein Konto angehört.

## Erinnerungen und Benachrichtigungen

Erinnerungen sind lokale Benachrichtigungen. Sie zeigen nie Titel, Ort oder Notiz, nur „Termin in …“. Es gibt keinen Push-Dienst eines Dritten.

## Berechtigungen

Internet (Verbindung zum Server), Benachrichtigungen und genaue Alarme (Erinnerungen), Neustart-Meldung (Erinnerungen neu planen) und Geräteanmeldung (App-Sperre). Es werden keine Kontakte, kein Standort, keine Kamera und kein Mikrofon benötigt.

## Sicherung und Löschung

Android-Backups sind ausgeschaltet. Speicherst du einen Anhang bewusst über „Speichern“, liegt die entschlüsselte Datei außerhalb der App in dem von dir gewählten Ordner. Mit „Alle lokalen Daten löschen“ entfernst du alle Daten, Schlüssel und Erinnerungen von diesem Gerät. Mit „Konto löschen“ (Einstellungen → Konto) löschst du dein Konto dauerhaft beim Anbieter und danach alle Daten auf diesem Gerät; bei Anbietern mit Anmeldung im Browser (z. B. matrix.org) bestätigst du die Löschung auf dessen Seite. Nachrichten auf Geräten anderer Mitglieder lassen sich technisch nicht erzwungen löschen. Dein Wiederherstellungsschlüssel ist das einzige Mittel, Nachrichten nach Verlust aller Geräte zu retten – bewahre ihn sicher auf.

## Kinder

Kinder können Familienmitglieder sein. Dafür ist die Einwilligung der Sorgeberechtigten nötig; Konten Minderjähriger laufen über die Einladung und Bestätigung eines Moderators.

## Deine Rechte

Du kannst jederzeit Auskunft, Berichtigung und Löschung verlangen. Lokale Daten verwaltest du in dieser App, dein Konto löschst du unter Einstellungen → Konto → „Konto löschen“; weitere Serverdaten beim Betreiber deines Servers.

## Online-Status, Einzelchats, Einkaufszettel

Der Online-Status („online“ oder „offline“ mit Zeitpunkt) wird nur als Ende-zu-Ende-verschlüsselte Gerätenachricht an Geräte beigetretener Familienmitglieder gesendet und nie gespeichert; du kannst ihn in den Einstellungen ausschalten. Einzelchats sind verschlüsselte Räume zwischen zwei Familienmitgliedern. Der Einkaufszettel wird wie geteilte Termine verschlüsselt im Familienraum übertragen und liegt verschlüsselt auf deinem Gerät; alle Familienmitglieder können ihn ändern. Der Server sieht nur Metadaten wie Zeitpunkte und Größe.
