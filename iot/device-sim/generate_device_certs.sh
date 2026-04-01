#!/bin/sh
set -e

VAULT="http://192.168.30.10:8200"
ROOT_TOKEN="$(cut -d= -f2 /work/vault/root_token.txt)"
LIST="/work/fleet-sim/out/devices_top50.txt"
OUT="/work/fleet-sim/certs"

if [ ! -f "$LIST" ]; then
  echo "Liste devices introuvable: $LIST"
  exit 1
fi

mkdir -p "$OUT"

# CA chain (on réutilise ce que tu as déjà généré)
if [ -f /work/vault/certs/ca-chain.crt ]; then
  cp /work/vault/certs/ca-chain.crt "$OUT/ca-chain.crt"
else
  echo "/work/vault/certs/ca-chain.crt introuvable. Génère-le depuis Vault (intermediate+root)."
  exit 1
fi

echo "==> Generating device certs into $OUT/<device_id>/client.(crt|key)"

i=0
while IFS= read -r DEV; do
  [ -z "$DEV" ] && continue
  i=$((i+1))
  echo "[$i] $DEV"

  mkdir -p "$OUT/$DEV"

  # Issue cert (role iot-devices)
  curl -sS -X POST \
    -H "X-Vault-Token: $ROOT_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"common_name\":\"$DEV.iot.iot-pfe.local\",\"ttl\":\"24h\"}" \
    "$VAULT/v1/pki_int/issue/iot-devices" \
    > "$OUT/$DEV/issue.json"

  jq -r '.data.certificate' "$OUT/$DEV/issue.json" > "$OUT/$DEV/client.crt"
  jq -r '.data.private_key' "$OUT/$DEV/issue.json" > "$OUT/$DEV/client.key"

done < "$LIST"

echo "Done. Generated $i device certs."