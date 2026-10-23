# Export Compliance für App Store Connect

Stand: 2026-10-23, App-Version 1.0.4 (Build 6). **Dies ist keine Rechtsberatung.** Alle Einordnungen sind Vorschläge auf Grundlage
von Apples Anleitung und der Projektquellen; Stellen mit **[verify]** bzw. „[publisher to confirm]“ muss der Herausgeber selbst klären.
Eingereicht oder hochgeladen wurde nichts; personenbezogene Angaben (Name, Anschrift) sind bewusst nicht eingetragen.

## Worum geht es

App Store Connect verlangt Unterlagen im Bereich **App-Informationen → App-Verschlüsselungsdokumentation**. Nach der Prüfung
vergibt Apple einen **Schlüsselwert**, der in die `Info.plist` kommt, damit die Verschlüsselungsfragen bei jedem Upload entfallen.

Was Apple je nach Art der Verschlüsselung verlangt ([Apple-Referenz](https://developer.apple.com/help/app-store-connect/reference/export-compliance-documentation-for-encryption)):

| Verschlüsselung der App | Unterlagen |
|---|---|
| nur die des Apple-Betriebssystems | keine |
| **Standardalgorithmen, nicht im Betriebssystem enthalten** | **französische Verschlüsselungserklärung** (nur nötig, wenn die App in Frankreich angeboten wird) |
| proprietäre Algorithmen, nicht von Normungsgremien (IEEE, IETF, ITU) anerkannt | US-CCATS **und** französische Erklärung |

**Einordnung von FamilyNexus:** Die App bringt eigene Verschlüsselung mit (vodozemac für Olm/Megolm, SQLCipher, TLS der Dart-Laufzeit),
also mehr als die des Betriebssystems. Die verwendeten Algorithmen sind Standard (AES-256, HMAC-SHA-256/512, HKDF, PBKDF2, Curve25519,
Ed25519, TLS 1.2/1.3). Die Protokolle Olm und Megolm sind offen spezifiziert, aber nicht von IEEE/IETF/ITU veröffentlicht – ob Apple
sie als „proprietär“ wertet, ist die eine echte Unsicherheit (siehe `encryption-description-en.md`, §3). Bei Standardalgorithmen wäre
nur die **französische Erklärung** nötig, und nur bei Angebot in Frankreich.

Laut Apple entfällt der jährliche US-„Self-Classification Report“, wenn du Dokumente bei Apple einreichst
([Apple](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)).

## Entscheidung: Frankreich

| Weg | Aufwand | Folge |
|---|---|---|
| **A: Frankreich aus der Verfügbarkeit nehmen** (App Store Connect → Preise und Verfügbarkeit) | gering | Apple verlangt für Standardalgorithmen keine Unterlagen; die App ist in Frankreich nicht erhältlich |
| **B: Frankreich behalten** | mittel | französische Erklärung bei der ANSSI abgeben, Bescheinigung bei Apple hochladen, Schlüsselwert erhalten |

Zu Weg B: Die Erklärung wird online bei der ANSSI abgegeben
([Formular](https://demarche.numerique.gouv.fr/commencer/declaration-relative-a-un-moyen-de-cryptologie); es war zuletzt als „in
Entwicklung“ gekennzeichnet). Üblich sind Nachweis des Herausgebers (z. B. Handelsregister-/Gewerbenachweis) und eine technische
Beschreibung der Kryptofunktionen – dafür dient `description-chiffrement-fr.md` (französischer Entwurf, vor dem Einreichen prüfen
lassen). Welche Unterlagen ein Einzelentwickler ohne Firma braucht, klärt die ANSSI bzw. ein Rechtsberater.

## Dateien

| Datei | Zweck |
|---|---|
| `encryption-description-en.md` | Technische Beschreibung der Verschlüsselung (Algorithmen, Schlüssellängen, Bibliotheken, Normen, Datenfluss). Grundlage für Apple und jede Behörde. Platzhalter für Herausgeberdaten ausfüllen, dann als PDF exportieren |
| `description-chiffrement-fr.md` | Französische Fassung (Entwurf) für die ANSSI-Erklärung |
| `../../tool/set_export_compliance.sh` | Trägt die Angaben nach der Genehmigung in die `Info.plist` von iOS und macOS ein |

## Ablauf

1. **Entscheiden:** Weg A oder B (oben).
2. **Platzhalter ausfüllen** in `encryption-description-en.md` (Herausgeber, Anschrift, Kontakt, Vertriebsländer, ECCN-Einschätzung) und die mit
   **[verify]** markierten Punkte prüfen (TLS-Suiten der Dart-Laufzeit; Krypto-Anbieter von SQLCipher im Pod).
3. **PDF erzeugen** (Pages/Word „Als PDF exportieren“, oder `brew install pandoc` und `pandoc encryption-description-en.md -o encryption-description-en.pdf`).
4. **App Store Connect:** App öffnen → *App-Informationen* → neben *App-Verschlüsselungsdokumentation* auf **+** → Fragen beantworten →
   *Datei auswählen* → *Sichern*. Vorher müssen App-Beschreibung und Verfügbarkeit gepflegt sein. Rollen: Account-Inhaber, Admin
   oder App-Manager. Apple nennt etwa zwei Werktage Prüfdauer. Alternativ: Bei einem Build mit fehlender Angabe (Tab *TestFlight*
   oder *Distribution*) auf **Verwalten** klicken.
5. **Fragen im Dialog** (Vorschlag, gegen Apples Wortlaut prüfen): Die App verwendet Verschlüsselung: **Ja**. Standardalgorithmen
   zusätzlich zur Betriebssystem-Verschlüsselung: **Ja**. Proprietäre, nicht standardisierte Algorithmen: **Nein** (siehe Unsicherheit oben).
6. **Nach der Genehmigung:** Schlüsselwert aus App Store Connect kopieren (neben der genehmigten Dokumentation) und eintragen:
   ```sh
   tool/set_export_compliance.sh <Schlüsselwert>
   ```
   Das setzt `ITSAppUsesNonExemptEncryption = true` und `ITSEncryptionExportComplianceCode` in `ios/Runner/Info.plist` und
   `macos/Runner/Info.plist`. Danach **Buildnummer erhöhen** (`pubspec.yaml`, z. B. `1.0.4+7`), `tool/build_ios_release.sh` und
   `tool/build_macos_release.sh` ausführen und hochladen. Ohne die Angabe in der Info.plist fragt App Store Connect bei jedem Upload erneut.
7. **Ohne Unterlagen (Weg A):** `tool/set_export_compliance.sh --no-code` setzt nur `ITSAppUsesNonExemptEncryption = true`; die
   Fragen im Fragebogen beantwortest du weiterhin selbst, bis Apple einen Schlüsselwert vergibt oder die Angabe akzeptiert.

## Weitere Pflichten, die der Herausgeber prüfen sollte

- **USA (BIS):** Mass-Market-Verschlüsselung ist üblicherweise als ECCN 5D992.c selbst einzustufen. Ob ein jährlicher
  Self-Classification-Report fällig ist, hängt von der Einstufung ab ([BIS](https://www.bis.doc.gov/index.php/policy-guidance/encryption)); Apple nennt ihn
  als entfallend, wenn Unterlagen bei Apple eingereicht werden.
- **Open Source:** Der Quellcode ist öffentlich (AGPL). Für öffentlich verfügbaren Verschlüsselungsquellcode kann eine Mitteilung an
  BIS/NSA nach 15 CFR §742.15(b) nötig sein; seit der Änderung 2021 gilt das nach meinem Kenntnisstand nur für „nicht standardmäßige
  Kryptografie“ **[verify]**.
- **Andere Länder:** Einzelne Länder (z. B. Indien, China, Russland) regeln Import/Nutzung von Verschlüsselung gesondert. Entweder
  die Verfügbarkeit entsprechend einschränken oder lokal prüfen lassen.
