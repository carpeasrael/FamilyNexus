# Website

Statische Webseite für https://FamilyNexus.inneso.de (kein Build-Schritt): `index.html` (Bewerbung, Screenshots, Downloads),
`datenschutz.html` (Datenschutzerklärung), `style.css`, `img/`. Lokal ansehen: `python3 -m http.server -d Website`.

Vor der Veröffentlichung eintragen (jeweils per `TODO` im HTML markiert):

- `datenschutz.html`: Verantwortlicher, Anschrift, Kontakt.
- `index.html`: App-Store-Link (Apple), sobald die App veröffentlicht ist.
- Windows-/Linux-/macOS-Downloads verweisen auf das neueste GitHub-Release; die Dateien müssen dort noch angehängt werden
  (der Release-Workflow baut bisher nur APK/AAB).

Die Datenschutzerklärung muss mit `store/privacy/privacy-policy.de.md` übereinstimmen.

Store-Badges (`img/badge-appstore.svg`, `img/badge-googleplay.png`) sind die offiziellen Vorlagen von Apple und Google; sie dürfen
nicht verändert werden (Farben, Proportionen, Text) und müssen die Markenrichtlinien der Stores einhalten.
Betriebssystem-Logos (`img/os-*.svg`): Apfel aus Simple Icons (einfarbig), Windows 11 als Vier-Quadrate-Logo (einfarbig), Tux (Larry Ewing, Wikimedia Commons, farbig), Marken
der jeweiligen Inhaber (Apple, Microsoft, Linux/Larry Ewing) – Nutzungsrichtlinien beachten.
