#!/usr/bin/env bash
# Startet einen isolierten Test-Homeserver (Synapse + Caddy-TLS-Proxy) NUR für lokale Tests.
# https://localhost:18448 (selbstsigniert; Tests akzeptieren das Zertifikat ausschließlich im Testcode).
# Aufräumen: tool/synapse/down.sh
set -euo pipefail
DATA="${FN_SYNAPSE_DATA:-/tmp/fn-synapse-data}"
NET=fn-synapse-net
docker rm -f fn-synapse fn-synapse-tls >/dev/null 2>&1 || true
docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET" >/dev/null
# Reste eines früheren Laufs gehören ggf. dem Container-Nutzer: über den Container entfernen.
if [ -d "$DATA" ]; then
  docker run --rm -v "$DATA":/data --entrypoint sh matrixdotorg/synapse:latest -c 'rm -rf /data/* /data/.[!.]*' >/dev/null 2>&1 || true
  rm -rf "$DATA" 2>/dev/null || true
fi
mkdir -p "$DATA"
docker run --rm -v "$DATA":/data -e SYNAPSE_SERVER_NAME=localhost -e SYNAPSE_REPORT_STATS=no \
  matrixdotorg/synapse:latest generate >/dev/null
# Neuere Images legen die Dateien als Container-Nutzer an; für den Nachtrag unten beschreibbar machen.
docker run --rm -v "$DATA":/data --entrypoint sh matrixdotorg/synapse:latest -c 'chmod -R a+rwX /data' >/dev/null
cat >> "$DATA/homeserver.yaml" <<'YAML'

# --- nur für Tests ---
enable_registration: true
enable_registration_without_verification: true
rc_message: {per_second: 1000, burst_count: 1000}
rc_registration: {per_second: 1000, burst_count: 1000}
rc_login:
  address: {per_second: 1000, burst_count: 1000}
  account: {per_second: 1000, burst_count: 1000}
  failed_attempts: {per_second: 1000, burst_count: 1000}
rc_joins:
  local: {per_second: 1000, burst_count: 1000}
rc_invites:
  per_room: {per_second: 1000, burst_count: 1000}
  per_user: {per_second: 1000, burst_count: 1000}
rc_key_requests: {per_second: 1000, burst_count: 1000}
experimental_features:
  msc3967_enabled: true
YAML
docker run --rm -v "$DATA":/data --entrypoint sh matrixdotorg/synapse:latest -c 'chmod -R a+rwX /data' >/dev/null
docker run -d --name fn-synapse --network "$NET" -v "$DATA":/data matrixdotorg/synapse:latest >/dev/null
docker run -d --name fn-synapse-tls --network "$NET" -p 127.0.0.1:18448:18448 caddy:2 \
  caddy reverse-proxy --from https://localhost:18448 --to http://fn-synapse:8008 >/dev/null
for i in $(seq 1 60); do
  if curl -sk https://localhost:18448/_matrix/client/versions >/dev/null 2>&1; then echo "Synapse bereit: https://localhost:18448"; exit 0; fi
  sleep 2
done
echo "Synapse nicht erreichbar"; docker logs fn-synapse | tail -20; exit 1
