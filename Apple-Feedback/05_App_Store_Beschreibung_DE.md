## App Store Beschreibung

FamilyNexus bringt euren Familienalltag an einen Ort: Termine, Nachrichten, Einkaufszettel und Aufgaben. Ob Schultermin, Wocheneinkauf oder Haushalt – ihr plant gemeinsam, verteilt Zuständigkeiten und bleibt miteinander in Kontakt. Für Familien, die ihren Alltag übersichtlich organisieren und ihre privaten Inhalte schützen möchten.

**Das könnt ihr mit FamilyNexus erledigen:**

- **Den Tag überblicken:** Die Heute-Ansicht zeigt anstehende Termine und eine Übersicht deiner Aufgaben. Von dort gelangst du zu den Bereichen für Kalender, Chat, Einkauf und Familie; Aufgabenlisten findest du im Menü.
- **Termine gemeinsam planen:** Wechselt zwischen Tages-, Wochen-, Monats- und Agendaansicht oder filtert nach Personen. Legt einmalige und wiederkehrende Termine an, berücksichtigt Zeitzonen, sagt zu gemeinsamen Terminen zu oder ab und teilt Termine als Karte im Chat. Private Termine werden nur zwischen den Geräten deines eigenen Kontos synchronisiert.
- **An Termine erinnert werden:** Lokale Erinnerungen helfen euch, nichts zu verpassen. Termintitel, Orte und persönliche Notizen erscheinen dabei nicht in der Benachrichtigung.
- **Vertraulich miteinander sprechen:** Tauscht im Familienchat oder im Einzelchat mit einem Familienmitglied Nachrichten und Anhänge aus. Antwortet auf einzelne Nachrichten und nutzt Reaktionen. Anhänge werden gezielt geladen. Offline verfasste Nachrichten werden bei erneuter Verbindung versendet.
- **Gemeinsam einkaufen:** Sammelt Artikel mit Mengen auf einer gemeinsamen Einkaufsliste. Alle Familienmitglieder können Einträge ergänzen, bearbeiten, abhaken oder löschen. Erledigte Einkäufe lassen sich gemeinsam entfernen; Änderungen werden zwischen euren Geräten abgeglichen.
- **Aufgaben verteilen:** Moderatoren erstellen Aufgabenlisten, weisen sie einer Person zu und legen tägliche, wöchentliche oder monatliche Wiederholungen fest. Nur die zugewiesene Person hakt ihre Punkte ab und kann einen Kommentar ergänzen. Zum nächsten Zeitraum beginnt die Liste neu; der Verlauf mit bisherigen Erledigungen bleibt erhalten.
- **Die Familie verwalten:** Gründet eine Familie oder tretet über eine Einladung bei. Moderatoren laden Mitglieder per Link oder QR-Code ein, bestätigen Beitritte und verwalten Rollen. Nachrichten können an den Serverbetreiber gemeldet werden. Blockierungen blenden Nachrichten und Einzelchats eines Mitglieds auf dem eigenen Gerät aus und lassen sich wieder aufheben.

**Privatsphäre gehört von Anfang an dazu.**

Eure Inhalte werden Ende-zu-Ende verschlüsselt übertragen und auf dem Gerät verschlüsselt gespeichert. Bereits synchronisierte Inhalte stehen offline zur Verfügung; unterstützte Änderungen werden bei erneuter Verbindung abgeglichen.

FamilyNexus setzt auf das offene Matrix-Protokoll. Ihr könnt einen kompatiblen Anbieter wählen oder einen eigenen Server verwenden. Der Quellcode ist offen einsehbar. Es gibt keine Werbung, keine Analyse- oder Tracking-SDKs und keine Abonnements oder In-App-Käufe.

Mit deutscher und englischer Oberfläche, hellem und dunklem Design, wählbaren Akzentfarben und reduzierbaren Effekten passt ihr FamilyNexus an eure Vorlieben an.

Für Einrichtung und Synchronisation benötigt ihr Internet und ein Matrix-Konto. Terminerinnerungen benötigen die Mitteilungserlaubnis. Chat-Nachrichten werden beim Öffnen beziehungsweise Synchronisieren aktualisiert; Chat-Push-Mitteilungen sind nicht enthalten.

## Technische App Beschreibung für Registrierung

FamilyNexus ist eine mit Flutter entwickelte Anwendung zur privaten Familienorganisation und Kommunikation. Die Kernfunktionen umfassen einen gemeinsamen und privaten Kalender, Familien- und Einzelchats mit Anhängen, eine gemeinsame Einkaufsliste sowie wiederkehrende Aufgabenlisten mit Zuweisung und Erledigungsverlauf. Die Anwendung verwendet das offene Matrix-Protokoll für Konten, verschlüsselte Kommunikation und Synchronisation zwischen Geräten.

**Kontoerstellung und Einrichtung:** Für Einrichtung und Synchronisation sind eine Internetverbindung und ein Konto bei einem kompatiblen Matrix-Anbieter erforderlich. Die Kontoerstellung wird aus der App gestartet. Je nach Anbieter erfolgt sie direkt in der App oder auf dessen Kontoseite im Browser. Der Standardanbieter ist matrix.org; dort werden Registrierung und Anmeldung im Browser durchgeführt. Anschließend kehrt die Person zur App zurück, richtet die Schlüsselsicherung ein und gründet eine Familie oder tritt über eine Einladung bei. Ein bestehendes Matrix-Konto kann ebenfalls verwendet werden.

**Zugriff und Rollen:** Die Anwendung unterscheidet zwischen Moderatoren und Mitgliedern einer Familie. Moderatoren verwalten Einladungen, Beitritte und Rollen und erstellen Aufgabenlisten. Aufgaben können ausschließlich von der jeweils zugewiesenen Person abgehakt werden. Neue Geräte werden mit dem persönlichen Notfall-Schlüssel oder durch Bestätigung eines bereits verifizierten Geräts freigeschaltet. Der Notfall-Schlüssel muss sicher aufbewahrt werden.

**Verschlüsselung und Speicherung:** Nachrichten, Anhänge, Termine, Einkaufs- und Aufgabenlisten werden Ende-zu-Ende verschlüsselt übertragen. Die Matrix-Anbindung nutzt das Matrix Dart SDK; die Ende-zu-Ende-Verschlüsselung basiert auf Olm/Megolm mit vodozemac. Die lokale Datenbank der Apple-App wird mit SQLCipher verschlüsselt; lokale Schlüssel werden im Apple-Schlüsselbund gespeichert. Private Termine werden ausschließlich zwischen Geräten desselben Kontos synchronisiert. Verbindungs- und Kontometadaten bleiben für den ausgewählten Serverbetreiber sichtbar.

**Offline-Nutzung und Benachrichtigungen:** Bereits synchronisierte Inhalte werden lokal bereitgestellt. Unterstützte Offline-Änderungen und ausstehende Nachrichten werden bei erneuter Verbindung abgeglichen beziehungsweise versendet. Terminerinnerungen werden lokal auf dem Gerät ausgelöst und enthalten keine Termintitel, Orte oder persönlichen Notizen. Dafür ist die Mitteilungserlaubnis erforderlich. Eine Remote-Push-Anbindung für Chat-Nachrichten ist nicht enthalten.

**Sicherheit und Nutzerinhalte:** Eine optionale App-Sperre verwendet die Geräteauthentifizierung. Nutzer können Chat-Nachrichten an den Betreiber ihres Matrix-Servers melden. Eine Meldung enthält Kennungen, den Meldegrund und gegebenenfalls einen lesbaren Erklärungstext, jedoch nicht den entschlüsselten Nachrichteninhalt. Blockierungen gelten auf dem jeweiligen Gerät und blenden Nachrichten und Einzelchats des blockierten Mitglieds aus. Moderatoren können Mitglieder aus der Familie entfernen.

**Daten- und Kontolöschung:** In den Einstellungen können lokale Daten entfernt oder die Löschung des Matrix-Kontos beim Anbieter gestartet werden. Bei Anbietern mit Browseranmeldung wird die Kontolöschung auf der Anbieterseite bestätigt. Nach Abschluss werden die lokalen App-Daten gelöscht. Das alleinige Entfernen lokaler Daten löscht das Konto nicht; bereits an andere Mitglieder zugestellte Nachrichten können dort erhalten bleiben.

**Dienste und Geschäftsmodell:** Nutzer können einen kompatiblen Matrix-Anbieter auswählen oder einen eigenen Server betreiben. Die Anwendung enthält keine Werbung, Analyse- oder Tracking-SDKs, Abonnements oder In-App-Käufe. Der Quellcode ist unter AGPL-3.0-or-later veröffentlicht. Die Oberfläche unterstützt Deutsch und Englisch sowie ein helles und dunkles Design, wählbare Akzentfarben und eine Option zur Reduzierung visueller Effekte.
