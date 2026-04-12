#!/bin/sh
set -e
VAULT="${VAULT_ADDR:-http://192.168.30.10:8200}"
ROOT_TOKEN_FILE="${ROOT_TOKEN_FILE:-/work/vault/root_token.txt}"

# Support both "VAULT_ROOT_TOKEN=xxx" and bare token formats
ROOT_TOKEN=$(grep -oP '(?<==)[^\s]+' "$ROOT_TOKEN_FILE" 2>/dev/null | head -1)
if [ -z "$ROOT_TOKEN" ]; then
  ROOT_TOKEN=$(cat "$ROOT_TOKEN_FILE" | tr -d '[:space:]')
fi

mkdir -p /work/vault/certs

curl -sS -X POST \
  -H "X-Vault-Token: $ROOT_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "common_name":"mosquitto.dmz.iot-pfe.local",
    "alt_names":"mqtt.iot-pfe.local,localhost",
    "ip_sans":"192.168.20.10,127.0.0.1",
    "ttl":"720h"
  }' \
  "$VAULT/v1/pki_int/issue/iot-services" \
  | tee /work/vault/certs/mosquitto.json | jq .

jq -r '.data.certificate' /work/vault/certs/mosquitto.json > /work/vault/certs/mosquitto.crt
jq -r '.data.private_key' /work/vault/certs/mosquitto.json > /work/vault/certs/mosquitto.key
jq -r '.data.issuing_ca'  /work/vault/certs/mosquitto.json > /work/vault/certs/intermediate-ca.crt

echo "✅ Written:"
ls -l /work/vault/certs