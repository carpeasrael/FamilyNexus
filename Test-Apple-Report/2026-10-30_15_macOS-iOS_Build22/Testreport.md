# Nachtest #103 – Lauf 15 – Build 1.2.1 (22)

**Datum:** 30.10.2026, ca. 14:20–14:30. **Tester:** automatisiert (Claude Code). **Umfang:** Teilplan V-04, A-03 (Fix zu #103). G1 = macOS 27.2 (TestFlight-Build 1.2.1 (22), Distribution-Signatur), G2 = iPhone-17-Simulator, iOS 27.0 (Simulator-Build aus `main` @ 97e37ab, `CFBundleVersion` 22). Es wurden keine Konten angelegt.

| Schritt | Gerät | Ergebnis | Beobachtet |
|---|---|---|---|
| V-04 | G1 | ✅ | Einladungslink per `open -a` geöffnet → „Konto erstellen“ mit dem Testserver; Zurück-Pfeil → „Willkommen“; App beendet und neu gestartet → **„Willkommen“** (Build 21: „Konto erstellen“). Auch bei Link, sofort beenden und neu starten: „Konto erstellen“ (Link noch vorgemerkt, wie gewollt); nach Zurück und Neustart wieder „Willkommen“ |
| A-03 | G1 | ✅ | „Neue Familie gründen“ → „Bei matrix.org legst du dein Konto auf der Seite des Anbieters an. …“, „Dein Konto liegt bei matrix.org.“ (Build 21: Testserver) |
| V-04 | G2 | ✅ | Link per `simctl openurl` → Web-Seite → „App öffnen“ → „Konto erstellen“; Zurück-Pfeil, App beenden und neu starten → „Willkommen“ |
| A-03 | G2 | ✅ | „Neue Familie gründen“ → „Dein Konto liegt bei matrix.org.“ |

**Ergebnis:** #103 ist mit Build 22 auf macOS und iOS behoben. Aufnahmen: `screenshots/N-*`. Nicht geprüft: iOS-TestFlight-Build (G2 ist ein Simulator-Build vom selben Stand); der Familienschritt (Beitrittskarte statt Gründung) ist durch den Test `#103` in `test/features/invite_onboarding_test.dart` abgedeckt, nicht erneut in der App durchlaufen.
