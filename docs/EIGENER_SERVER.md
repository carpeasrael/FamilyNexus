# Eigenen Matrix-Homeserver betreiben (Vorlage)

FamilyNexus funktioniert mit jedem Matrix-Homeserver, der die Client-Server-API ab **v1.1** unterstützt
(Raumversion 10, Anklopfen/„knock“, Anmeldung mit Passwort). Mit einem eigenen Server bestimmst du selbst,
wer die **Metadaten** (wer schreibt wann mit wem, Raum- und Profilnamen wie der Familienname) sieht; sie verschwinden dadurch nicht. Inhalte sind ohnehin Ende-zu-Ende-verschlüsselt.

> Diese Anleitung ist eine Ausgangsbasis, kein Ersatz für die Dokumentation von Synapse bzw. deines
> Reverse-Proxys. Nimm aktuelle Versionen und halte sie aktuell.

## Voraussetzungen
- Eine Domain (z. B. `matrix.example.org`) mit gültigem **TLS-Zertifikat** (z. B. Let's Encrypt). Die App
  akzeptiert ausschließlich `https://`; selbstsignierte Zertifikate werden nicht akzeptiert.
- Docker oder ein Linux-Server, Reverse-Proxy (Caddy/nginx) für TLS.

## Minimale Konfiguration (Synapse, Ausschnitt `homeserver.yaml`)

```yaml
server_name: "example.org"            # Teil der Matrix-IDs (@name:example.org)
public_baseurl: "https://matrix.example.org/"

listeners:
  - port: 8008
    type: http
    x_forwarded: true
    bind_addresses: ['127.0.0.1']
    resources:
      - names: [client, federation]

# Familienserver: Registrierung nur durch dich, Föderation nach Bedarf
enable_registration: false
# federation_domain_whitelist: []     # leer = keine Föderation (nur eigene Nutzer)

# Datenschutz
report_stats: false
allow_public_rooms_over_federation: false
presence:
  enabled: false

# Empfohlen für FamilyNexus
encryption_enabled_by_default_for_room_type: all
```

Konten legst du selbst an (FamilyNexus registriert keine Konten):

```bash
register_new_matrix_user -c homeserver.yaml http://localhost:8008
```

## `.well-known` (Server-Betreiber anzeigen und Auto-Erkennung)

Unter `https://example.org/.well-known/matrix/client`:

```json
{ "m.homeserver": { "base_url": "https://matrix.example.org" } }
```

Unter `https://example.org/.well-known/matrix/support` (die App zeigt den Kontakt bei der Einrichtung an):

```json
{ "contacts": [ { "role": "m.role.admin", "email_address": "admin@example.org" } ],
  "support_page": "https://example.org/hilfe" }
```

## Reverse-Proxy (Caddy, Beispiel)

```
matrix.example.org {
    reverse_proxy 127.0.0.1:8008
}
```

## Prüfliste
- [ ] `https://matrix.example.org/_matrix/client/versions` liefert `v1.1` oder höher.
- [ ] `https://matrix.example.org/_matrix/client/v3/login` nennt `m.login.password`.
- [ ] Sicherungen der Datenbank des Servers sind verschlüsselt; Server-Logs enthalten keine Inhalte.
- [ ] Mindestens **zwei Moderatoren** in der Familie und Notfall-Schlüssel gesichert.

## Serverwechsel
Ein Wechsel des Homeservers bedeutet: neue Konten, neue Familie (neuer Raum), neue Einladungen. Ein
Migrationsablauf ist in dieser Phase **nicht** umgesetzt (siehe `OFFEN.md`).
