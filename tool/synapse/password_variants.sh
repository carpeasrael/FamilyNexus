#!/usr/bin/env bash
# Drei zusätzliche Test-Homeserver NUR für die Annahmen zu Issue #117 (test/e2e/gateway_account_e2e_test.dart):
#   http://127.0.0.1:18449  password_config.localdb_enabled: false   (keine Passwort-Anmeldung: 401 mit leeren Flows)
#   http://127.0.0.1:18450  password_config.enabled: false           (keine Passwort-Anmeldung: 401 mit leeren Flows)
#   http://127.0.0.1:18451  password_config.enabled: only_for_reauth (Passwort-Stufe vorhanden, richtiges Passwort: 403
#                           `M_FORBIDDEN` ohne Flows; Anmeldung gesperrt; Richtlinie: mindestens 20 Zeichen, eine Ziffer)
# Eigene Container und eigenes Netz; fn-synapse aus tool/synapse/up.sh bleibt unberührt.
# Aufruf: tool/synapse/password_variants.sh up|down
set -euo pipefail
NET=fn-synapse-pw-net
IMAGE=matrixdotorg/synapse:latest

clean_data() {
  local data="$1"
  [ -d "$data" ] || return 0
  # Dateien gehören ggf. dem Container-Nutzer: zuerst über den Container leeren.
  docker run --rm -v "$data":/data --entrypoint sh "$IMAGE" -c 'rm -rf /data/* /data/.[!.]*' >/dev/null 2>&1 || true
  rm -rf "$data" 2>/dev/null || true
}

start() {
  local name="$1" port="$2" password_config="$3"
  local data="/tmp/$name-data"
  docker rm -f "$name" >/dev/null 2>&1 || true
  clean_data "$data"
  mkdir -p "$data"
  docker run --rm -v "$data":/data -e SYNAPSE_SERVER_NAME=localhost -e SYNAPSE_REPORT_STATS=no "$IMAGE" generate >/dev/null
  docker run --rm -v "$data":/data --entrypoint sh "$IMAGE" -c 'chmod -R a+rwX /data' >/dev/null
  cat >> "$data/homeserver.yaml" <<YAML

# --- nur für Tests ---
enable_registration: true
enable_registration_without_verification: true
rc_registration: {per_second: 1000, burst_count: 1000}
password_config: $password_config
YAML
  docker run --rm -v "$data":/data --entrypoint sh "$IMAGE" -c 'chmod -R a+rwX /data' >/dev/null
  docker run -d --name "$name" --network "$NET" -p "127.0.0.1:$port:8008" -v "$data":/data "$IMAGE" >/dev/null
  for _ in $(seq 1 60); do
    if curl -s "http://127.0.0.1:$port/_matrix/client/versions" >/dev/null 2>&1; then echo "$name bereit: http://127.0.0.1:$port"; return 0; fi
    sleep 2
  done
  echo "$name nicht erreichbar"; docker logs "$name" | tail -20; exit 1
}

case "${1:-}" in
  up)
    docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET" >/dev/null
    start fn-synapse-pw-change-off 18449 '{localdb_enabled: false}'
    start fn-synapse-pw-login-off 18450 '{enabled: false}'
    start fn-synapse-pw-reauth 18451 '{enabled: only_for_reauth, policy: {enabled: true, minimum_length: 20, require_digit: true}}'
    ;;
  down)
    for name in fn-synapse-pw-change-off fn-synapse-pw-login-off fn-synapse-pw-reauth; do
      docker rm -f "$name" >/dev/null 2>&1 || true
      clean_data "/tmp/$name-data"
    done
    docker network rm "$NET" >/dev/null 2>&1 || true
    ;;
  *)
    echo "Aufruf: $0 up|down"; exit 2
    ;;
esac
