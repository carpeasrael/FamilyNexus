# Datenschutzerklärung für FamilyNexus

**Stand: 31. Oktober 2026 · App-Version: 1.2.1 (Build 22)**

**Geltungsbereich: native Apps für iOS, macOS, Windows, Linux und Android.**

> **Vor Veröffentlichung ergänzen:** Name bzw. Firma, vollständige Postanschrift und
> Datenschutz-Kontakt des Herausgebers in Abschnitt 1 fehlen noch. Falls ein
> Datenschutzbeauftragter benannt ist, sind dessen Kontaktdaten zu ergänzen. Für selbst
> betriebene Server sind außerdem die konkreten Betreiber-, Hosting-, Speicherfrist-
> und gegebenenfalls Drittlandangaben aufzunehmen. Bis dahin ist dies ein Entwurf.

FamilyNexus ist ein Familienkalender und Messenger mit gemeinsamer Einkaufs- und
Aufgabenverwaltung. Diese Erklärung beschreibt die Verarbeitung personenbezogener
Daten auf den genannten Betriebssystemen. Unterschiede sind ausdrücklich angegeben.
Die eigenständige Web-App ist nicht Gegenstand dieser Erklärung. Browserseiten, die
du aus einer nativen App heraus öffnest, werden in Abschnitt 8 berücksichtigt.

## 1. Herausgeber, Verantwortlichkeit und Kontakt

**Herausgeber und Kontakt für die in seinem Verantwortungsbereich liegende Verarbeitung:**

- Name bzw. Firma: **[VOLLSTÄNDIGEN NAMEN / FIRMA EINTRAGEN]**
- Postanschrift: **[STRASSE, HAUSNUMMER, POSTLEITZAHL, ORT, LAND EINTRAGEN]**
- E-Mail für Datenschutzanfragen: **[KONTAKT-E-MAIL EINTRAGEN]**

FamilyNexus ist freie Software unter der AGPL-3.0-or-later. Der Herausgeber erhält
über die App keine automatischen Nutzungsberichte und keine Kopien deiner
Chatnachrichten, Termine oder Dateien. Die Bereitstellung der Software allein
verschafft ihm keinen Zugriff auf deinen Matrix-Server oder deine lokalen Daten.
Wenn du ihn selbst kontaktierst, verarbeitet er deine Kontaktdaten und die von dir
übermittelten Inhalte zur Bearbeitung deiner Anfrage.

Für Kontoführung, Serverbetrieb und die dortige Verarbeitung ist der Betreiber des
von dir gewählten **Matrix-Homeservers** verantwortlich. Standardmäßig ist
`https://matrix.org` voreingestellt; du kannst einen anderen kompatiblen Anbieter
oder einen eigenen Server verwenden. Der Anbieter ist bei der Einrichtung unter
„Erweitert“ sichtbar. Ergänzend gelten seine Datenschutzhinweise, insbesondere zu
Betreiberdaten, Protokollierung, Hosting, Löschfristen und Dienstleistern. Betreibt
der Herausgeber zugleich deinen Server, umfasst seine Verantwortung auch diesen
Betrieb. Ein Familienmoderator ist nicht automatisch der Serverbetreiber.

## 2. Datenarten, Zwecke und Herkunft

Die App verarbeitet deine Eingaben sowie Daten, die andere Mitglieder mit dir
teilen oder die dein Anbieter zur Synchronisierung bereitstellt.

| Daten | Zweck und Verarbeitung |
|---|---|
| Benutzername, Matrix-Konto-ID, Anzeigename, Anbieteradresse; bei Registrierung gegebenenfalls E-Mail-Adresse, Passwort und Bestätigungsschritte | Konto anlegen und anmelden, Profil zuordnen und Zugang zum Anbieter herstellen. Bei Browseranmeldung werden die Angaben auf dessen Seite eingegeben. |
| Gerätekennungen und -namen, Zugriffstoken, gegebenenfalls Aktualisierungstoken, Verifizierungsinformationen und kryptografische Schlüssel | Anmeldung aufrechterhalten, eigene Geräte verbinden, Inhalte ver- und entschlüsseln, Geräte überprüfen und Schlüssel wiederherstellen. |
| Nachrichten, Antworten, Reaktionen und ausgewählte Dateianhänge einschließlich Dateinamen | Familienchat und Einzelchats zwischen Familienmitgliedern. |
| Gemeinsame und private Termine, Titel, Orte, Notizen, Zeiten, Zeitzonen, Wiederholungen und Zu- oder Absagen | Kalender, Terminabstimmung und lokale Erinnerungen. Ein eingegebener Terminort ist keine Erfassung des Gerätestandorts. |
| Einkaufsartikel, Mengen und Bearbeitungszustände | Gemeinsame Einkaufsliste. |
| Aufgabenlisten, Zuordnungen, Wiederholungsregeln, Erledigungen, Zeitpunkte und freiwillige Kommentare | Aufgaben verteilen und den Erledigungsverlauf anzeigen. Der Verlauf bleibt auch nach einem periodischen Neustart der Liste erhalten. |
| Familien- und Raumnamen, Mitgliedschaften, Rollen, Einladungen und Beitrittsanfragen | Familie verwalten und den Zugriff auf gemeinsame Inhalte steuern. |
| Online-/Offline-Status mit Zeitpunkt | Optional anderen Familienmitgliedern die Erreichbarkeit anzeigen. |
| Sprache, Darstellung, Erinnerungs- und Sicherheitseinstellungen, lokal blockierte Konten und vorgemerkte Einladungen | App konfigurieren und begonnene Abläufe fortsetzen. |
| IP-Adresse, Verbindungszeitpunkte, Konto-, Raum- und Gerätekennungen sowie technische Übertragungsdaten | Verbindung, Zustellung und Betrieb beim jeweils angesprochenen Server; dessen Protokollierung richtet sich nach seinen Datenschutzhinweisen. |

Du entscheidest, welche Inhalte du eingibst und teilst. Freitexte und Dateien können
auch Angaben über andere Personen oder besonders sensible Informationen, etwa zur
Gesundheit, enthalten. Teile solche Angaben nur mit entsprechender Berechtigung
und mit den vorgesehenen Empfängern.

## 3. Lokale Speicherung und Schutz auf den Plattformen

Die Anwendungs- und Matrix-Datenbanken werden auf dem Gerät mit **SQLCipher
verschlüsselt** gespeichert. Darin liegen unter anderem synchronisierte Inhalte,
Einstellungen und benötigte Sitzungsdaten. Für die Datenbankschlüssel verwendet
die App die sichere Speicherlösung der jeweiligen Plattform.

| Plattform | Schlüsselablage und Besonderheiten |
|---|---|
| Android | Durch Android Keystore geschützte Ablage. Die App deaktiviert die vorgesehenen automatischen Android-App-Backups und schließt App-Daten über Sicherungsregeln aus. |
| iOS | Apple-Schlüsselbund mit gerätegebundener Zugänglichkeit nach dem ersten Entsperren. Die verwendete Schlüsselkonfiguration sieht keine Übertragung dieser Schlüssel auf andere Geräte vor. |
| macOS | Apple-Schlüsselbund; die App aktiviert für diese Schlüssel keine iCloud-Synchronisierung. |
| Windows | Sichere Ablage über `flutter_secure_storage` mit Schutz durch die Windows-Anmeldeinformationsverwaltung. Die Datenbanken liegen im lokalen Benutzerprofil. |
| Linux | Secret Service über `libsecret`, beispielsweise der Schlüsselbund deiner Desktopumgebung. Die Datenbanken liegen im App-Datenverzeichnis des Benutzerkontos. |

Für Anzeige und Bearbeitung werden Inhalte auf dem Gerät entschlüsselt. Auf
unterstützten Geräten nutzt die optionale App-Sperre die Geräteauthentifizierung,
beispielsweise Face ID, Touch ID oder Windows Hello. Die App erhält dabei das
Authentifizierungsergebnis, keine biometrischen Vorlagen und keine Geräte-PIN.
Unter Linux steht diese App-Sperre nicht zur Verfügung.

Die App-Sperre verdeckt die Oberfläche; sie ist keine zusätzliche, an jede
Entschlüsselung gekoppelte Schlüsselsperre. Bildschirmschutz und Schutz gegen
Aufnahmen unterscheiden sich je nach Betriebssystem und verhindern nicht jede
Form der Aufnahme. System-, Datenträger- und manuell angelegte Sicherungen können
je nach Plattform und Geräteeinstellung weiterhin Daten enthalten. Ein genereller
Ausschluss sämtlicher Backups auf allen fünf Plattformen wird nicht zugesagt.

## 4. Verschlüsselung, Empfänger und sichtbare Metadaten

Chatinhalte, Anhänge, Kalender-, Einkaufs- und Aufgabendaten werden vor der
Übertragung mit den Verschlüsselungsverfahren des Matrix-Protokolls geschützt.
Nachrichten verwenden Olm/Megolm; Anhänge werden vor dem Hochladen verschlüsselt.
Die Verbindungen zum Anbieter sind zusätzlich mit HTTPS/TLS geschützt.

- **Familienraum:** Gemeinsame Nachrichten, Termine, Einkaufslisten und Aufgaben
  einschließlich ihres Verlaufs sind für berechtigte Familienmitglieder auf ihren
  freigeschalteten Geräten lesbar.
- **Einzelchat:** Inhalte werden zwischen den beiden beteiligten Konten geteilt.
- **Private Termine:** Sie werden über einen gesonderten verschlüsselten Raum
  deines Kontos zwischen deinen eigenen Geräten synchronisiert. „Privat“ bedeutet
  daher nicht „ausschließlich auf diesem einen Gerät gespeichert“.
- **Einladungen:** Eine direkte Matrix-Einladung kann bereits zur Verteilung von
  Schlüsseln für neue Nachrichten an verifizierte Geräte des eingeladenen Kontos
  führen, bevor die Person die Einladung ausdrücklich annimmt. Lade nur die
  tatsächlich vorgesehenen Personen ein.

Ende-zu-Ende-Verschlüsselung verbirgt **nicht sämtliche Metadaten**. Der Anbieter
kann unter anderem Konto- und Gerätekennungen, Profilangaben, Raumnamen,
Mitgliedschaften und Rollen, Zeitpunkte, IP-Adressen sowie Größen und Zuordnungen
verschlüsselter Ereignisse verarbeiten. Insbesondere Raumzustand und
Kontoverwaltung sind nicht wie Nachrichteninhalte Ende-zu-Ende-verschlüsselt.

Bei serverübergreifender Kommunikation können über die Matrix-Föderation auch
Homeserver anderer beteiligter Konten verschlüsselte Ereignisse und die für die
Zustellung erforderlichen Metadaten erhalten. Ein eigener Homeserver ändert,
wer deinen Server betreibt; er beseitigt Metadaten und mögliche Föderation nicht.
Empfänger können gelesene Inhalte kopieren, exportieren oder weitergeben.

## 5. Online-Status, Blockierungen und Meldungen

Der Online-Status wird als Ende-zu-Ende-verschlüsselte Gerätenachricht an Geräte
beigetretener Familienmitglieder gesendet. Die App hält den empfangenen Status
nur im Arbeitsspeicher und führt daraus keinen dauerhaften Verlauf. Für die
Zustellung kann der Server verschlüsselte Gerätenachrichten vorübergehend
vorhalten. Du kannst das Teilen unter **Einstellungen → Datenschutz →
Online-Status teilen** ausschalten. Der Anbieter kann dennoch Verbindungszeitpunkte
erkennen.

Blockierungen werden lokal in der verschlüsselten Datenbank gespeichert. Sie
blenden Inhalte auf deinem Gerät aus; sie entfernen die betroffene Person nicht
automatisch aus der Familie und entziehen ihr keine bereits erhaltenen Inhalte.

Wenn du eine Nachricht meldest, erhält dein Homeserver die Raum- und
Nachrichtenkennung, den gewählten Meldegrund und deinen optionalen Freitext.
Durch die angemeldete Anfrage ist die Meldung deinem Konto zuordenbar. Diese
Meldedaten sind für den Betreiber lesbar. Die App übermittelt dabei keine
entschlüsselte Kopie der gemeldeten Nachricht. Zitierst du Inhalte selbst im
Meldetext, werden diese Bestandteil der lesbaren Meldung.

## 6. Berechtigungen und lokale Erinnerungen

Die App benötigt Netzwerkzugriff für Kontofunktionen, Serverprüfung und
Synchronisierung. Bereits lokal vorhandene Inhalte lassen sich auch offline
nutzen; ausstehende Änderungen werden bei wiederhergestellter Verbindung
übertragen.

Erinnerungen werden lokal geplant und enthalten keinen Termintitel, Ort oder
Notiztext, sondern einen allgemeinen Hinweis wie „Termin in …“. FamilyNexus
bindet keinen eigenen Remote-Pushdienst und keine Chat-Pushübertragung über
Firebase Cloud Messaging oder Apple Push Notification Service ein.

| Zugriff | Verwendung |
|---|---|
| Benachrichtigungen | Lokale Terminerinnerungen; je nach Betriebssystem mit vorheriger Freigabe. |
| Genaue Alarme und Neustart-Ereignisse unter Android | Erinnerungen zeitgerecht auslösen und nach einem Geräteneustart neu planen. |
| Geräteauthentifizierung auf unterstützten Plattformen | Freigabe der optionalen App-Sperre. |
| Systemdialoge für Dateien | Von dir ausgewählte Dateien einlesen oder von dir veranlasste Exporte speichern. |
| Zwischenablage | Von dir ausgelöstes Kopieren, etwa von Einladungen, Datenprotokollen oder dem Notfall-Schlüssel. |

Unter Windows und Linux werden Erinnerungen in dieser Version über Zeitgeber der
laufenden App ausgelöst. Die App verlangt keinen Zugriff auf Kontakte,
Gerätestandort, Kamera oder Mikrofon. Ein QR-Code kann mit einer externen
Kamera-App gelesen werden; dadurch erhält FamilyNexus keinen Kamerazugriff.
Berechtigungen kannst du, soweit das System dies unterstützt, dort widerrufen;
betroffene Funktionen stehen dann gegebenenfalls nicht mehr zur Verfügung.

## 7. Schlüsselsicherung, Dateien und Datenprotokolle

Bei der Einrichtung wird eine verschlüsselte Matrix-Schlüsselsicherung eingerichtet.
Sie dient der Wiederherstellung auf weiteren oder neuen Geräten. Der Anbieter
speichert dabei verschlüsselte Schlüsseldaten. Bewahre deinen **Notfall-Schlüssel**
sicher auf und gib ihn nicht an Supportstellen oder andere Personen weiter.

Beim ausdrücklichen Speichern von Anhängen, Datenprotokollen oder des
Notfall-Schlüssels entstehen **unverschlüsselte Dateien außerhalb der geschützten
App-Datenbanken**. Der gewählte Ordner kann mit einem Cloudspeicher synchronisiert
werden. Dann gelten zusätzlich dessen Zugriffs- und Datenschutzbedingungen.
Ausgewählte Originaldateien bleiben an ihrem bisherigen Speicherort; beim
Einlesen versucht die App, temporäre Auswahlkopien zu entfernen.

Beim Kopieren des Notfall-Schlüssels versucht die App, den entsprechenden
Zwischenablageeintrag nach einer Minute zu entfernen. Hintergrundbeschränkungen
und Zwischenablageverläufe können eine vollständige Entfernung verhindern.
Andere Apps oder Systemdienste können kopierte Inhalte je nach Plattform verarbeiten.

In den Einstellungen kannst du Protokolle der lokal bzw. online gespeicherten
Daten anzeigen, kopieren oder speichern. Sie enthalten unter anderem Speicherorte,
Kontoinformationen und Datenbestände, aber keine Schlüsselwerte oder Zugriffstoken.
Sie können dennoch persönliche Angaben enthalten und sind keine vollständige
Auskunft über sämtliche Serverprotokolle oder Backups deines Anbieters.

## 8. Externe Seiten, Stores und weitere Anbieter

Bei einer browsergestützten Anmeldung oder Kontolöschung öffnet die App die vom
gewählten Anbieter bereitgestellte Seite. Dort können weitere Dienste für
Anmeldung, E-Mail-Bestätigung oder CAPTCHA beteiligt sein. Diese Verarbeitung
richtet sich nach den Hinweisen des jeweiligen Anbieters.

Einladungslinks können die GitHub-Pages-Seite
`https://carpeasrael.github.io/FamilyNexus/join/` öffnen. Beim Seitenabruf werden
technisch notwendige Verbindungsdaten wie IP-Adresse und Browserinformationen an
den Hostinganbieter übermittelt. Die von der App erzeugten Einladungsdaten stehen
im URL-Fragment nach `#`; dieser Teil wird beim üblichen HTTP-Seitenabruf nicht an
den Webserver gesendet, aber im Browser verarbeitet und kann im Browserverlauf
stehen. Die Seite übergibt den Link auf deine Aktion an die App.

Die öffentliche Projektseite dient außerdem als OAuth-Client-Webseite. Optional
kann die App auf Element als externen Matrix-Client verweisen. Beim Teilen per
E-Mail oder Öffnen anderer externer Programme erhalten diese die von dir
übergebenen Daten. Für Hosting, Browser, E-Mail-Dienste und externe Programme
gelten jeweils deren Datenschutzhinweise.

Download, Installation und Updates über einen App-Store oder eine Downloadplattform
können dort Konto-, Geräte- und Abrufdaten auslösen. FamilyNexus enthält keine
Werbung, Analyse-SDKs, Telemetrie oder automatische Übermittlung von
Absturzberichten an den Herausgeber. Technische Fehler können lokal protokolliert
werden; die App maskiert dabei sensible Kennungen und Geheimnisse. Unabhängige
Betriebssystemdiagnosen richten sich nach deinen Systemeinstellungen.

## 9. Verarbeitungsorte und mögliche Drittlandübermittlungen

Lokale App-Daten werden auf deinen Geräten verarbeitet. Wo Serverdaten liegen,
hängt von deinem Homeserver, dessen Hosting und gegebenenfalls den Servern anderer
Beteiligter ab. Die App erzwingt keinen ausschließlichen Speicherort innerhalb
Deutschlands, der EU oder des Europäischen Wirtschaftsraums.

Auch beim Aufruf externer Webseiten oder bei selbst gewählten Cloudexporten kann
eine Verarbeitung außerhalb dieses Gebiets stattfinden. Der jeweils verantwortliche
Anbieter muss über konkrete Empfänger, Länder und einschlägige Garantien informieren.
Soweit die DSGVO anwendbar ist, sind bei Drittlandübermittlungen die Voraussetzungen
der Art. 44 ff. zu beachten, etwa ein einschlägiger Angemessenheitsbeschluss oder
geeignete Garantien. Verschlüsselung allein ersetzt diese Voraussetzungen nicht.

## 10. Zwecke und Rechtsgrundlagen

Die technische Verarbeitung dient den von dir gewählten Kommunikations-,
Organisations- und Sicherheitsfunktionen. Welche Rechtsgrundlage dafür im
Einzelfall gilt, richtet sich nach dem tatsächlich Verantwortlichen und dem
Nutzungsverhältnis. Die Nutzung freier Software ist keine pauschale Einwilligung
in beliebige Datenverarbeitungen.

- Für ein vereinbartes Konto- und Kommunikationsangebot erforderliche Verarbeitung
  kann auf **Art. 6 Abs. 1 Buchst. b DSGVO** beruhen. Der Serveranbieter benennt die
  für sein Angebot geltende Grundlage.
- Soweit eine Verarbeitung auf deiner Einwilligung beruht, gilt **Art. 6 Abs. 1
  Buchst. a DSGVO**. Sie ist für die Zukunft widerruflich. Eine
  Betriebssystemberechtigung allein ersetzt nicht automatisch eine
  datenschutzrechtliche Einwilligung.
- Bei einer von dir veranlassten Supportanfrage verarbeitet der Herausgeber deine
  Angaben zur Bearbeitung. Bei Vertragsbezug gilt **Art. 6 Abs. 1 Buchst. b DSGVO**,
  sonst **Art. 6 Abs. 1 Buchst. f DSGVO**; das berechtigte Interesse ist die
  Beantwortung der Anfrage und Behebung gemeldeter Probleme.
- Für serverseitige Sicherheitsprotokolle und Missbrauchsmeldungen muss der
  Betreiber seine konkrete Rechtsgrundlage und gegebenenfalls seine berechtigten
  Interessen in seinen eigenen Hinweisen erläutern.

Für unbedingt erforderliche lokale Speicherung und Zugriffe zur Bereitstellung
von dir ausdrücklich gewünschter App-Funktionen ist in Deutschland **§ 25 Abs. 2
Nr. 2 TDDDG** maßgeblich, soweit diese Vorschrift anwendbar ist. Es werden keine
zusätzlichen Speicherzugriffe zu Werbe- oder Analysezwecken eingesetzt.
Gesetzestexte:
[DSGVO](https://eur-lex.europa.eu/legal-content/DE/TXT/?uri=CELEX%3A32016R0679) und
[§ 25 TDDDG](https://www.gesetze-im-internet.de/ttdsg/__25.html).

Konto- und Verbindungsdaten sind für Anmeldung und Synchronisierung erforderlich.
Ohne sie sind die Onlinefunktionen nicht nutzbar. Inhalte, Anhänge, Kommentare und
das Teilen des Online-Status bestimmst du selbst; einzelne Registrierungsangaben
kann dein Anbieter voraussetzen. FamilyNexus führt kein Profiling und keine
automatisierten Entscheidungen mit rechtlicher oder vergleichbar erheblicher
Wirkung über dich durch.

## 11. Speicherdauer und Löschung

**Auf deinem Gerät:** Daten bleiben gespeichert, solange sie für die Nutzung
vorgehalten werden und du sie nicht über die vorgesehenen Funktionen entfernst.
Es gibt keine allgemeine automatische Löschfrist für Nachrichten, Termine oder
Aufgabenverläufe. Unter **Einstellungen → Datenschutz → Alle lokalen Daten
löschen** werden die App- und Matrix-Datenbanken, die zugehörigen lokal abgelegten
Schlüssel und die durch die App verwalteten Erinnerungen entfernt.

**Abmelden:** Beim Abmelden unter **Einstellungen → Konto → Abmelden** entfernt die
App die Termine (auch private), Einkaufslisten und Aufgaben dieses Kontos vom Gerät
und bricht geplante Erinnerungen ab. Das gilt auch, wenn die Sitzung auf andere
Weise endet, etwa weil das Gerät von einem anderen Gerät aus abgemeldet wurde.
App-Einstellungen wie Sprache und Darstellung bleiben erhalten. Bereits gesendete
Inhalte werden nach der nächsten Anmeldung wieder synchronisiert; noch nicht
gesendete Änderungen gehen verloren.

**Auf dem Server:** Lokale Löschung ist keine Kontolöschung. Nach erneuter Anmeldung
können noch vorhandene Serverdaten wieder synchronisiert werden. Speicherfristen
für Konto-, Inhalts-, Verbindungs- und Meldedaten sowie Backups bestimmt der
jeweilige Betreiber. Die App legt keine einheitliche Frist für fremde Server fest.

**Konto löschen:** Unter **Einstellungen → Konto → Konto löschen** kannst du die
Löschung beim Anbieter anstoßen. Bei klassischer Matrix-Anmeldung fordert die App
eine Kontodeaktivierung mit Löschwunsch (`erase`) an. Bei browsergestützter
Kontoverwaltung erfolgt die Bestätigung auf der Anbieterseite. Nach bestätigtem
Abschluss werden die lokalen Kontodaten bereinigt. Welche Serverdaten tatsächlich
gelöscht oder weiter aufbewahrt werden, richtet sich nach dem Anbieter und
gegebenenfalls bestehenden gesetzlichen Pflichten.

**Verbleibende Kopien:** Weder lokale Löschung noch Kontolöschung garantieren die
Entfernung bereits zugestellter Inhalte auf Geräten anderer Personen, föderierten
Servern oder in deren Sicherungen. Selbst exportierte Dateien, Ausdrucke,
Zwischenablageverläufe und externe Backups werden nicht durch die App gelöscht.
Auch eine Deinstallation ersetzt die gezielte Kontolöschung nicht.

**Anfragen an den Herausgeber:** Angaben aus Datenschutz- oder Supportanfragen
werden nur so lange aufbewahrt, wie es für die Bearbeitung und gegebenenfalls die
Erfüllung gesetzlicher Pflichten oder die Geltendmachung, Ausübung oder
Verteidigung von Rechtsansprüchen erforderlich ist; anschließend werden sie gelöscht.

## 12. Kinder und Jugendliche

FamilyNexus kann innerhalb einer Familie auch von Kindern genutzt werden.
Sorgeberechtigte sollen die Einrichtung begleiten, die Bedingungen des gewählten
Kontoanbieters beachten und mit dem Kind besprechen, wer gemeinsame Inhalte sehen
kann.

Soweit bei einem direkt an Kinder gerichteten Onlineangebot eine Einwilligung
nach Art. 6 Abs. 1 Buchst. a DSGVO erforderlich ist, gelten die Voraussetzungen des
**Art. 8 DSGVO**. In Deutschland ist dafür bei unter 16-Jährigen grundsätzlich die
Einwilligung oder Zustimmung der Sorgeberechtigten erforderlich; andere Länder
können im gesetzlichen Rahmen andere Altersgrenzen vorsehen. Die Bestätigung durch
einen Familienmoderator ist keine automatische Prüfung von Alter, Sorgeberechtigung
oder rechtlich wirksamer Einwilligung.

## 13. Deine Datenschutzrechte

Soweit die gesetzlichen Voraussetzungen erfüllt sind, hast du insbesondere
folgende Rechte gegenüber dem jeweils Verantwortlichen:

- **Auskunft** über deine personenbezogenen Daten (Art. 15 DSGVO).
- **Berichtigung** unrichtiger und Vervollständigung unvollständiger Angaben
  (Art. 16 DSGVO).
- **Löschung** und **Einschränkung der Verarbeitung** (Art. 17 und 18 DSGVO).
- **Datenübertragbarkeit** bei den dafür vorgesehenen Verarbeitungen (Art. 20 DSGVO).
- **Widerspruch** aus Gründen deiner besonderen Situation gegen eine auf
  Art. 6 Abs. 1 Buchst. e oder f DSGVO gestützte Verarbeitung (Art. 21 DSGVO).
- **Widerruf einer Einwilligung** mit Wirkung für die Zukunft; die Rechtmäßigkeit
  der Verarbeitung bis zum Widerruf bleibt unberührt (Art. 7 Abs. 3 DSGVO).
- **Beschwerde bei einer Datenschutzaufsichtsbehörde**, insbesondere am Ort deines
  gewöhnlichen Aufenthalts, deines Arbeitsplatzes oder des vermuteten Verstoßes
  (Art. 77 DSGVO).

Für Verarbeitungen des Herausgebers nutze den Kontakt in Abschnitt 1; für Konto-
und Serverdaten wende dich an deinen Anbieter. Der Herausgeber kann Daten auf
fremden Servern nicht selbst löschen oder entschlüsseln. Sende für eine Anfrage
niemals dein Passwort, Zugriffstoken oder deinen Notfall-Schlüssel. Die Rechte
ergeben sich aus der
[Datenschutz-Grundverordnung](https://eur-lex.europa.eu/legal-content/DE/TXT/?uri=CELEX%3A32016R0679).

## 14. Änderungen dieser Erklärung

Diese Erklärung wird angepasst, wenn sich die tatsächliche Verarbeitung oder die
rechtlichen Anforderungen ändern. Stand-Datum und App-Version oben zeigen, auf
welche Fassung sie sich bezieht. Neue Verarbeitungszwecke oder einwilligungspflichtige
Funktionen werden nicht allein durch eine Änderung dieses Textes erlaubt.
