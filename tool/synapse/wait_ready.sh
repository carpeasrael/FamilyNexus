#!/usr/bin/env bash
# Wartet, bis ein Test-Homeserver wirklich antwortet (HTTP 200 auf /_matrix/client/versions).
# Aufruf: wait_ready.sh <BASIS-URL> <NAME>
# Versuche und Pause: FN_WAIT_TRIES (Standard 60), FN_WAIT_SLEEP (Standard 2 Sekunden).
# `-f`: HTTP-Fehler (z. B. 502 von Caddy, solange Synapse startet) zählen nicht als bereit (#281).
# `-k`: nur für die selbstsignierten lokalen Testserver.
set -u
URL="${1:?Basis-URL fehlt}"
NAME="${2:?Name fehlt}"
TRIES="${FN_WAIT_TRIES:-60}"
PAUSE="${FN_WAIT_SLEEP:-2}"
i=0
while [ "$i" -lt "$TRIES" ]; do
  if curl -fsk --max-time 5 "$URL/_matrix/client/versions" >/dev/null 2>&1; then
    echo "$NAME bereit: $URL"
    exit 0
  fi
  i=$((i + 1))
  sleep "$PAUSE"
done
echo "$NAME nicht erreichbar"
exit 1
