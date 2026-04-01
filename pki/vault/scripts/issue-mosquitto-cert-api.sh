#!/bin/sh
set -e
VAULT="http://192.168.30.10:8200"
ROOT_TOKEN=$(cut -d= -f2 /work/vault/root_token.txt)

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