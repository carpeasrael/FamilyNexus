# Code-Testplan der offenen Issues (TP-FN-CODE-OFFEN v02)

Stand: 2026-11-18 (Einträge #528, #545), zuvor 2026-11-15, `main` + Branch `fix/497-einladung-server-mit-port`, 1.2.3+30. Regel: `CLAUDE.md`, Abschnitt „Abnahme und Schließen (Code-Test)“, Entscheidung E-103.

**Grundsatz:** Ist der Code-Test eines Issues positiv, darf das Issue schließen (PR mit `Closes`, Merge durch den Nutzer). Was nur auf dem Gerät belegbar ist, steht in der Spalte „Plattform-Pflichtschritt“ und wird im Release-Test je Plattform mit Screenshots geführt (`docs/release-e2e/<Version>.md`, Gate in `release.yml`), nicht mehr am Issue.

## Pflichtteil für jedes Issue

| Schritt | Befehl | Erwartung |
|---|---|---|
| P-1 | `flutter analyze` | keine Befunde |
| P-2 | Regressionstest des Issues (Spalte „Code-Test“): ohne Fix rot (Rot-Gegenprobe, z. B. Fix lokal zurücknehmen), mit Fix grün | beide Zustände belegt, Ausgabe im Issue |
| P-3 | `flutter test` | alles grün, kein bestehender Test abgeschwächt |
| P-4 | nur bei Matrix-Abläufen: `tool/e2e.sh` (Docker, lokaler Synapse) | alles grün; ein Einzelfall mit Zeitüberschreitung unter Last einzeln wiederholen und beides vermerken |
| P-5 | nur bei Web: `tool/web_selftest.sh` | grün |
| P-6 | CI auf dem PR (`dart.yml`) | alle Jobs grün |

Schließen darf das Issue, wenn P-1 bis P-3 (und P-4/P-5 falls zutreffend) und P-6 belegt sind **und** der Regressionstest das beschriebene Verhalten prüft (nicht nur „läuft ohne Fehler“).

Ausgangslage heute: die unten genannten vorhandenen Testdateien und -ordner laufen zusammen mit **946 bestanden, 0 fehlgeschlagen** (`flutter test` auf dem Mac, 2026-11-15). Das belegt nur den Ist-Zustand, nicht die Abnahme eines Issues.

## Gruppe A: Fix liegt vor oder Verhalten ist umgesetzt, Test vorhanden

| Issue | Code-Test (vorhanden) | Lücke / zusätzlich zu schreiben | Plattform-Pflichtschritt (Release-Gate) |
|---|---|---|---|
| #497 Einladungslink Server mit Port | `test/domain/invite_link_test.dart`, `test/data/default_account_server_test.dart`, `test/e2e/gateway_registration_e2e_test.dart` (+ P-4) | keine; Commits `ed3e173`, `8b195fb`, `9af5414` auf dem Branch | Beitritt per Link zu einem Server mit Port: iOS, Android |
| #498 Heute: „Keine Erinnerung geplant“ und „2 fällig“ | `test/features/today_reminders_ui_test.dart` | Regressionstest für den Fall „geplant 0, fällig 2“ (Analyse im Issue, `today_screen.dart:88-89`) | Karte auf „Heute“: iPad, iPhone |
| #486 Datenspeicher eingebettete Anmeldeseite | `test/features/embedded_browser_page_test.dart`, `test/data/website_data_test.dart`, `test/l10n/wording_test.dart`, `test/store/store_wording_test.dart` | keine (Swift-Teil nicht per Dart prüfbar) | **G-12 iOS und macOS**: Speicher nach Abbruch leer (`AppDelegate.swift`, `MainFlutterWindow.swift`) |
| #458 Anhang laden hängt | `test/data/attachment_download_test.dart` (+ P-4: Anhang-Download-Test lief grün) | keine | – |
| #463 Monatszellen Screenreader | `test/features/calendar/month_cell_semantics_test.dart` | keine | TalkBack/VoiceOver: Monatszelle (Android, iOS) |
| #451 Präsenz im Sync | `test/data/sync_presence_test.dart` | E2E-Test `set_presence` gegen Synapse (fehlt, Bericht Lauf 31) | – |
| #450 Abmelden löscht Blockierliste/Einladung | `test/app/account_bound_settings_test.dart`, `test/app/logout_wipe_test.dart`, `test/app/family_owner_test.dart` | keine | – |
| #445 Fehlertext beim Löschen eines Termins | `test/features/event_delete_error_test.dart` | keine | – |
| #441 Anmeldung matrix.org eingebettet | `test/features/embedded_nav_test.dart`, `embedded_browser_page_test.dart`, `registration_test.dart`, `sign_in_icons_test.dart`, `test/l10n/apple_cancel_hint_test.dart` | keine | **TP-OAUTH-11/-12** echte Anbieterseite (iPhone, Mac, Android); ohne echtes matrix.org-Konto nicht ausführbar, bleibt Release-Pflicht |
| #422 Avatare | `test/features/avatar_calendar_test.dart`, `avatar_ui_test.dart`, `test/ui/person_color_test.dart`, `test/data/avatar_gateway_test.dart`, `test/l10n/metadata_claims_test.dart` (+ P-4) | – | Avatar-Auswahl: Android, iOS |
| #423 Gesprächsliste im Chat-Tab | `test/features/chat_test.dart`, `chat_structure_test.dart`, `direct_chat_test.dart`, `chat_send_race_test.dart`, `chat_thread_list_test.dart` (+ P-4) | – | Gespräch bleibt beim Tab-Wechsel: Android, iOS |
| #424 Farben im Kalender (Themen) | `test/features/event_themes_ui_test.dart`, `test/data/event_theme_sync_test.dart`, `sql_event_theme_store_test.dart` (+ P-4) | Themen-Chips im Termin-Editor unter „Geteilt“ (Befund B2, Lauf 31) als Widget-Test | Chips mit echtem Server: Android, iOS |
| #524 Anordnung Bereiche (Feature, E-105) | `test/features/shell/shell_tasks_family_menu_test.dart` (Fußzeile, Badges, Menü, Anfragen-Badge, Heute-Karte), `home_shell_adaptive_test.dart` (130 % und 200 % mit Badge), `focus_and_dropdown_test.dart`, `adaptive_screens_test.dart`, `test/features/home_shell_open_failure_test.dart`, `join_and_security_test.dart`, `test/l10n/plural_counts_test.dart`, Semantik-Schnappschüsse (`home_shell_structure_test.dart`, `chat_structure_test.dart`, `ap4e_shopping_structure_test.dart`) | keine; Integrationstests `integration_test/store_screenshots_test.dart`, `manual/ui_tour_test.dart`, `tasks_tour_test.dart`, `tasks_member_tour_test.dart` nachgezogen, nicht ausgeführt (Gerät) | Leiste bei großer Systemschrift auf Android, iOS, Windows, macOS, Linux, Web (`RT3-J-04`) |
| #539 Geburtstage (Feature, E-104) | `test/domain/anniversary_calc_test.dart`, `anniversary_display_test.dart`, `anniversary_codec_test.dart`, `anniversary_service_test.dart`, `test/data/sql_anniversary_store_test.dart`, `anniversary_sync_test.dart`, `test/features/anniversary_tile_test.dart`, `anniversaries_ui_test.dart`, `anniversary_factory_test.dart`, `error_text_test.dart`, `settings_controller_test.dart`, `test/domain/app_settings_test.dart`, `test/l10n/anniversaries_claim_test.dart` (+ P-4: `tool/e2e.sh` mit zwei Konten: Eintrag von A erscheint verschlüsselt bei B, B ändert ihn, A sieht die Änderung; auf dem Host nicht ausgeführt, bis ein Lauf belegt ist) | Neufeature: Mutationsprobe (29.2.-Regel in `AnniversaryCalc.effectiveDate`, Zukunftsregel im Dienst, Anzeigeregel) ohne den Code rot, mit Code grün | Optik (Symbole, Schriftgrößen 200 %) in Liste, Dialog, „Heute“-Karte und Monatsraster: RT3-E-12 je Plattform |
| #526 Chat: Zustellstatus (Feature, E-106) | `test/domain/chat_read_test.dart`, `test/domain/app_settings_test.dart`, `test/data/chat_mapper_test.dart` (Gruppe #526: Position, `join`/`leave`/fehlendes Member-Ereignis, `mainThread`, Reaktion als Marker-Ziel, `ts`-Rückfall, Schalter aus), `test/data/read_receipts_gateway_test.dart` (HTTP-Mock `read_markers`: `m.read` nur bei an, `m.read.private` immer; `refreshReadStates`; Receipt-Sync löst Neuaufbau aus), `test/features/chat_delivery_status_test.dart` (Sendet, Gesendet, Gelesen, Gelesen von n, Namensblatt, Einzelchat ohne Blatt, blockierte Nutzer, Großschrift 2.0), `read_receipts_settings_test.dart` (Schalter, genau ein Abgleich), `test/features/chat_structure_test.dart`, `ap4e_settings_structure_test.dart` (Schnappschüsse), `test/l10n/read_receipts_claim_test.dart`, `test/store/privacy_policy_parity_test.dart` (+ P-4: `test/e2e/read_receipts_e2e_test.dart` mit zwei Konten: A sendet, B liest öffentlich, A sieht `{B}`; B mit Schalter aus: A sieht nichts; **auf dem Host ohne Docker nicht ausgeführt, bis ein Lauf belegt ist, bis dahin `Refs`**) | Neufeature: Rot-Gegenprobe (`public:` in `markChatRead` entfernen: Gateway-Test rot; Auswertung in `ReadMarkers` entfernen: Mapper-Test rot) | Optik der Haken (hell/dunkel, Großschrift), VoiceOver/TalkBack-Ansage („Gesendet“, „Gelesen von n“), reale Zustellung mit zwei Geräten: RT3-E-13 je Plattform |
| #516 Chat: Ungelesene zuerst, letztes Gespräch wieder öffnen (Feature, E-107) | `test/features/chat_thread_list_test.dart` (Gruppe „Ungelesene zuerst“: Familie oben, Ungelesenes älter vor Gelesenem neuer, Gleichstand Titel/ID; `restoreTarget` als Tabelle), `test/features/chat_restore_last_test.dart` (Wiederherstellung von Einzelchat und Familie, Start bleibt „Heute“, Schalter aus speichert nichts, Öffnen/Zurück/Timeout-Rückfall speichern, Ziel erst nach der ersten Aktivierung geladen: Liste und später nicht plötzlich, Ziel vorher geladen, Pinnen, blockiert, `chatRequest` ohne Build-Fehler, Ausschalten verwirft), `test/domain/app_settings_test.dart`, `test/app/account_bound_settings_test.dart`, `family_owner_test.dart`, `logout_wipe_test.dart` (Kennung gelöscht, Schalter bleibt), `test/ui/settings_screen_test.dart`, `ap4e_settings_structure_test.dart` (Schnappschuss), `test/l10n/restore_chat_claim_test.dart`, `test/store/privacy_policy_parity_test.dart` | Neufeature: Rot-Gegenprobe (Ungelesen-Schlüssel in `orderedThreadRows` entfernen: Sortiertest rot; `_applyRestore` entfernen: Wiederherstellungstests rot) | Neustart der echten App mit gemerktem Gespräch (Zeitpunkt des Erscheinens der Einzelchats nach Kaltstart), Liste mit Ungelesenen, VoiceOver/TalkBack: RT3-E-14 je Plattform |
| #545 Einrichtung: Schritt „Anbieter wählen“ (Feature, E-108) | `test/features/onboarding_server_step_test.dart` (Schritt und Zählung, `standard.host`, eigener Server, „Weiter“ bei leer/ungültig, Enter, ausgefallener Standard, Zurück-Regeln, Abmeldung und Einladung in jedem Schritt, Zurücksetzen nach verworfener Einladung auch mit Heimnetz-Server und genau eine Prüfung je Wegwahl, Englisch ohne Fachbegriffe, große Schrift, Radio-Semantik); angepasst: `onboarding_test.dart`, `invite_onboarding_test.dart`, `registration_test.dart`, `registration_password_test.dart`, `onboarding_finish_failure_test.dart`, `second_device_test.dart`, `sign_in_icons_test.dart`, `account_create_structure_test.dart`, `ap4e_login_structure_test.dart`, `test/ui/keyboard_dismiss_test.dart`, `test/l10n/wording_test.dart`, `test/store/docs_consistency_test.dart` | keine (Gateway unverändert) | **RT3-H-07**: neuer Schritt auf iPhone, Android, Desktop, große Schrift, VoiceOver/TalkBack |
| #381 Benachrichtigung | `test/data/activity_notifications_test.dart`, `activity_notifier_test.dart`, `test/features/activity_settings_test.dart`, `reminder_coordinator_test.dart`, `test/data/local_reminder_scheduler_test.dart` | – | Plan `Testplan_Benachrichtigungen_macOS-iOS.md` je Plattform (Systemdialog, Zustellung); Mac-Teil von Lauf 27 nicht ausgeführt |
| #350 „App bewerten“ / #351 „App teilen“ | `test/features/settings_recommend_test.dart` | Befund B1: Tap löst auf Android nichts aus; Test, der den Launcher-Aufruf mit der Store-URL belegt | I-03 Android (Play Store öffnet) |
| #349 Play-Store-Screenshots | `test/store/play_screenshots_test.dart` | – | – |
| #348 Play-Store-Beschreibung | `test/store/description_test.dart` | – | – |
| #554 macOS Kaltstart ohne schwarzen Rahmen | `test/platform/macos_launch_background_test.dart` (Textprüfung, kein Verhaltensbeleg) | – | Release-E2E `macos`: A-01 Kaltstart hell und dunkel, Montage im 0,13-s-Raster (nicht hier ausführbar) |
| #345 Startbild folgt App-Thema | `test/app/bootstrapper_test.dart` | – | A-01 Mac, iOS: kein heller Blitz im Dunkel-Thema |
| #332 „Nachricht von dir“ | `test/features/chat_test.dart` | – | Screenreader Android |
| #326 Text-Audit DE/EN | `test/l10n/wording_test.dart`, `plural_counts_test.dart`, `test/features/presence_label_test.dart`, `sender_name_test.dart` | – | – |
| #297 Hinweis „iPhone und Mac“ | `test/l10n/apple_cancel_hint_test.dart` | – | – |
| #274 Anzeige auf Tablets | `test/ui/adaptive_test.dart`, `test/platform/tablet_config_test.dart`, `test/features/shell/adaptive_screens_test.dart`, `test/features/calendar/section_card_test.dart` | Wortumbruch bei Schrift 200 % (Befund B3) | J-04 Schrift 200 % Telefon, iPad |
| #266 Web: Matrix-Datenbank „memory access out of bounds“ | `tool/web_selftest.sh`, `tool/web_selftest.dart`, `tool/web_smoke.py` (P-5) | – | Web: Start nach Tresor-Anlage mit Screenshot |
| #142 Identitätsvermerke | `test/data/identity_pins_test.dart`, `local_identity_pins_test.dart`, `account_provider_test.dart` (+ P-4) | Gateway-Verdrahtung `merged(..., local:)` ist #440 | – |

## Gruppe B: Test fehlt, zu schreiben (Rot-Gegenprobe Pflicht)

| Issue | Zu prüfendes Verhalten | Testdatei (neu oder erweitern) | Plattform-Pflichtschritt |
|---|---|---|---|
| #501 Statusleisten-Symbole auf hellem Design | `SystemUiOverlayStyle` je App-Thema (`lib/app/app.dart`): hell → dunkle Symbole, dunkel → helle | `test/app/system_overlay_test.dart` (neu): `AnnotatedRegion<SystemUiOverlayStyle>` je Thema | R-07 Android, iOS: Statusleiste lesbar (Screenshot) |
| #502 Tour: „Let's go“ statt „Überspringen“ | Entscheidung zuerst (Text oder Plan), dann Wortlaut de/en | `test/features/intro_tour_test.dart` (erweitern), `test/l10n/wording_test.dart` | H-03 Tour |
| #503 „Link zum Store-Eintrag kopiert“ | Wortlaut festlegen (Plan: „Link kopiert“), de/en | `test/features/settings_recommend_test.dart` | I-01 |
| #506 Profilbild-Dialog schließt nach „Speichern“ nicht | Dialog schließt, Avatar erscheint | `test/features/avatar_ui_test.dart` (erweitern) | D-01 iOS: Dialog schließt |
| #507 Tour nach erneuter Anmeldung desselben Kontos | Entscheidung (gewollt wegen #450 oder Fehler) in `ENTSCHEIDUNGEN.md`; Test belegt die gewählte Regel | `test/features/intro_tour_test.dart`, `test/app/logout_wipe_test.dart` | H-02 |
| #508 P-14: Editor-Text statt „nicht gespeichert“ | Entscheidung (Verhalten oder Plan), Test belegt das gewählte | `test/features/event_editor_structure_test.dart` o. ä. | P-14 |
| #504 Testpflege `ui_tour_test.dart`, `store_screenshots_test.dart` | beide Skripte laufen gegen die aktuelle Oberfläche, nicht abgeschwächt | `integration_test/manual/…`; Desktop-Integrationstests laufen auf Linux-Host nicht (kein clang), auf dem Mac/Simulator ja: `flutter test integration_test/manual/ui_tour_test.dart -d <Simulator>` | Lauf im Release-Test iOS/Android mit Screenshots |
| #505 Doku #485, „Gesprächsleiste“ | `docs/ENTSCHEIDUNGEN.md` enthält Eintrag zu #485; „Gesprächsleiste“ kommt in `docs/KONTAKTE.md` und `docs/ENTSCHEIDUNGEN.md` nur noch als Verweis auf E-100 vor | `test/store/docs_consistency_test.dart` (neu, Dateisuche) | – |
| #446 Release Notes nennen Themen, Avatare, Gesprächsliste | `test/store/release_notes_test.dart` (vorhanden, PR #474) | Rot-Gegenprobe im Issue vermerkt | – |
| #447 Datenschutzerklärung: Kalender-Themen | `test/store/privacy_policy_parity_test.dart`, `privacy_policy_notifications_test.dart` | Test für „Kalender-Themen“ als Datenkategorie (de, en, `privacy2Body`) | – |
| #448 Flatpak-Metainfo kennt 1.2.3 nicht | `pubspec.yaml`-Version steht als `<release version>` in `flatpak/de.inneso.familynexus.metainfo.xml`; Datum plausibel | `test/store/flatpak_metainfo_test.dart` (neu) | Linux: `appstreamcli validate` (macOS nicht ausführbar) |
| #449 ARCHITEKTUR.md: Migrationen | Zahl der Migrationen in der Doku = `migrations.length` in `app_database.dart`; `SqlEventThemeStore` genannt | `test/store/docs_consistency_test.dart` | – |

Für #446 bis #449 gilt der Text im Issue (PR #474, `Refs`): Nach neuer Regel genügt der grüne Code-Test, die Store-Texte werden mit der Release-Freigabe veröffentlicht.

## Gruppe C: Sammel-Issues

| Issue | Code-Test | Schließen, wenn |
|---|---|---|
| #453 Review-Observations Performance 1.2.3+29 | keiner (alle Urteile ABGELEHNT) | Kommentar belegt, dass kein bestätigter Befund offen ist |
| #455 Observations Sicherheit | die Tests von #450 und #451 | #450 und #451 geschlossen |
| #456 Observations Konsistenz | die Tests von #445 bis #449 | #445 bis #449 geschlossen |
| #254 Features 1.2.2 (Sammel) | `test/features/activity_*`, `chat_*`, `test/data/activity_*` (Pflichtlauf P-1 bis P-3) | alle darin genannten Punkte entweder durch Tests in Gruppe A belegt oder einzeln aufgelistet |
| #326 Text-Audit (Sammel, siehe Gruppe A) | `wording_test.dart`, `plural_counts_test.dart` | Pflichtlauf grün und im Issue gelistet, welche Texte geprüft sind |

## Gruppe D: Plattform-Fix ohne Dart-Code-Test (Beleg im Release-Gate)

| Issue | Fix / Stand | Code-seitig belegbar | Schließen mit Beleg aus |
|---|---|---|---|
| #330 Windows „9+“ am Rand | PR #342 auf `main` (`windows/runner/taskbar_badge.cpp`) | CI-Job `windows` baut den Runner | Release-E2E `windows`: „9+“ bei 100/125/150/200 %, Screenshot |
| #325 Tests auf Windows: Pfadtrenner, CRLF | `test/support/text_norm_test.dart` | `flutter test` auf Windows-Host (nicht hier ausführbar) | Release-E2E `windows`: Testlauf auf Windows, 0 Fehler |
| #263 Zeitwähler Windows | `test/features/calendar_flow_test.dart` | Dart-Teil | Release-E2E `windows`: Tastatureingabe der Stunde (physische Tastatur) |
| #317 App macOS, Linux, Windows | `calendar_flow_test.dart` u. a. | Dart-Teil | Release-E2E `macos`, `linux`, `windows` |
| #316 Start Performance iPhone | `test/app/bootstrapper_test.dart` | Dart-Teil | Release-E2E `ios`: Startzeit am Release-Build, Screenshot |
| #144 Screenshots-Schalter | `test/features/settings_secure_screen_hint_test.dart` | Dart-Teil | Release-E2E `windows` (Bildschirmaufnahme), `android` (`FLAG_SECURE` belegt) |

Nach neuer Regel darf ein Issue dieser Gruppe schließen, wenn der Dart-Teil grün ist **und** der zugehörige Plattformschritt im Release-Test als „bestanden“ mit Screenshot im Bericht steht. Ein Issue ohne jeden Code-Test bleibt bis dahin offen (`Refs`).

## Nicht Teil dieses Plans (kein Code-Test möglich oder nicht umgesetzt)

| Issue | Grund |
|---|---|
| #15 Prüfkonto vorbereiten | rein manuell: Apple, echte Konten, Testperson |
| #528 Anmeldung und Registrierung ohne Browser (macOS, Linux, Windows) | Wunschfunktion für Linux und Windows auf Entscheidung der Nutzerin (18.11.2026) nicht umgesetzt (kein gepflegtes, baubares Paket; Nachtrag zu E-102); macOS eingebettet durch #441, Gerätenachtest offen; reine Dokumentation, kein Code-Test; Issue bleibt offen (Refs) |
| #268 Registrierung über matrix.org | echtes Konto bei matrix.org nötig (verboten ohne Freigabe); Teile in #441 und `invite_onboarding_test.dart` |
| #273 Android-Hintergrundmeldungen (v1.3) | nur am Gerät belegbar, Milestone v1.3 |
| #431 (v1.3) | Teil 1 umgesetzt (Empfang, E-112): `event_editor_codec_test`, `conflict_editor_test`, `calendar_service_foreign_test`, `calendar_moderator_sync_test`, `sql_event_store_editor_test`, `calendar_roleof_wiring_test`, `calendar_apply_guard_test`; Teil 2 (Bearbeiten, Senden, Oberfläche) folgt |
| #311 (v1.3) | Teile 1, 2a, 2b, 2c, 3a, 3b, 4a-1, 4a-2 und 4b von 7 umgesetzt (1: Format, Ordnung, Dienst, Ablage, Migration 8, E-113, gesperrt: `cash_book_codec_test`, `cash_book_resolver_test`, `cash_book_service_test`, `sql_cash_book_store_test`; 2a: Einladungstrennung, ungesperrt: `book_invitation_test`; 2b: Buchverwaltung, gesperrt: `book_policy_test`, `book_gateway_test`; 2c: Buch-Sync, gesperrt: `book_signal_scan_test`, `cash_book_sync_test`, `book_gateway_sync_test`, `cash_book_store_books_test`, `cash_book_service_restamp_test`, `cash_book_wiring_test`, E2E `gateway_cashbook_e2e_test` **nicht ausgeführt**); 3a: Bon-Foto-Aufbereitung, ohne Aufrufer: `receipt_photo_processing_test`); 3b: Bon-Datei, Prüfungen, Schwärzen, gesperrt: `cash_receipt_check_test`, `book_gateway_receipts_test`, `cash_book_receipts_test`, `cash_book_service_receipt_test`, E2E-Test **nicht ausgeführt**); 4a-1: Logik der Oberfläche, gesperrt: `cash_amount_test`, `cash_month_test`, `receipt_preview_test`, `cash_book_controller_test`, Gateway/Sync-Tests für `bookMembers`/`staleBooks`); 4a-2: Bildschirme, unsichtbar hinter der Sperre: `cash_book_screens_test`; 4b: Datenübersicht, Datenschutztexte, Store-Angaben, Abhängigkeiten: `cash_book_claims_test`, `data_report_rooms_test`, `book_gateway_sync_test` (Raumart), `docs_consistency_test`; die Freigabe (Sperre auf `true`, nur mit Freigabe des Eigentümers) folgen |
| #119 (v1.3) | Phase K1 (Härtung, E-114) umgesetzt: B1 `family_invitation_test`, `book_invitation_test` (Gruppe nie als Familie, fail-closed nach dem Beitritt), B3 `chat_mapper_test` (Terminverweis nur im Familienraum), `chat_thread_list_test`, B4 `chat_send_race_test` D1 bis D5 (Entwurf je Gespräch). **K0 (Synapse, matrix.org) nicht ausführbar, Plattform-Pflichtschritt.** K2a (Einstufung): `conversation_policy_test`, Gateway-Harness „Einzelchat-Einstufung“, `calendar_flow_test` (familyUnreadCount); K2b bis K6 offen |
| #120, #121 (v1.3) | Entwürfe bzw. nicht umgesetzt; Plan erst mit der Umsetzung |

## Durchführung

1. Je Issue läuft der Standardablauf aus `CLAUDE.md` (Schritte 1 bis 6); dieser Plan ersetzt dort nur die Frage „was belegt die Abnahme“.
2. Testplan-Agent und Tester-Agent bekommen die Zeile des Issues aus diesem Plan als Ausgangspunkt; der Tester meldet je Schritt bestanden/fehlgeschlagen mit Befehl und Ausgabe.
3. Der Plan wird je Lauf nachgezogen (Spalte „Lücke“ wird zu „vorhanden“); erledigte Zeilen bleiben stehen, bis das Issue geschlossen ist.
4. Plattform-Pflichtschritte fließen in den Release-Test (`User E2E Test/Release_1.2.3_v01/`) und werden dort mit Screenshots belegt; der Beleg je Plattform steht in `docs/release-e2e/<Version>.md`.
