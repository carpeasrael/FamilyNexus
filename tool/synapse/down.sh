#!/usr/bin/env bash
# Entfernt den Test-Homeserver samt Daten.
DATA="${FN_SYNAPSE_DATA:-/tmp/fn-synapse-data}"
docker rm -f fn-synapse fn-synapse-tls >/dev/null 2>&1 || true
docker network rm fn-synapse-net >/dev/null 2>&1 || true
# Dateien gehören ggf. dem Container-Nutzer: zuerst über den Container leeren.
if [ -d "$DATA" ]; then
  docker run --rm -v "$DATA":/data --entrypoint sh matrixdotorg/synapse:latest -c 'rm -rf /data/* /data/.[!.]*' >/dev/null 2>&1 || true
  rm -rf "$DATA" 2>/dev/null || true
fi
echo "Test-Homeserver entfernt"
