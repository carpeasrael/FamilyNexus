#!/usr/bin/env bash
# Entfernt den Test-Homeserver samt Daten.
docker rm -f fn-synapse fn-synapse-tls >/dev/null 2>&1 || true
docker network rm fn-synapse-net >/dev/null 2>&1 || true
rm -rf "${FN_SYNAPSE_DATA:-/tmp/fn-synapse-data}"
echo "Test-Homeserver entfernt"
