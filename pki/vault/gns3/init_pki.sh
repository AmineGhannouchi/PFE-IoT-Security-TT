#!/usr/bin/env bash
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
OUT_DIR="${OUT_DIR:-/pfe/out}"
INIT_JSON="$OUT_DIR/init-keys.json"

log(){ echo "[$(date '+%F %T')] $*"; }

mkdir -p "$OUT_DIR"

log "=== Vault init/unseal + PKI setup ==="
log "VAULT_ADDR=$VAULT_ADDR"
log "OUT_DIR=$OUT_DIR"

# 1) Init si nécessaire
if vault status -address="$VAULT_ADDR" 2>/dev/null | grep -q "Initialized.*true"; then
  log "Vault déjà initialisé."
else
  log "Initialisation Vault..."
  vault operator init -address="$VAULT_ADDR" -key-shares=5 -key-threshold=3 -format=json > "$INIT_JSON"
  log "Init terminé. Fichier: $INIT_JSON"
fi

ROOT_TOKEN="$(jq -r '.root_token' "$INIT_JSON")"
K1="$(jq -r '.unseal_keys_b64[0]' "$INIT_JSON")"
K2="$(jq -r '.unseal_keys_b64[1]' "$INIT_JSON")"
K3="$(jq -r '.unseal_keys_b64[2]' "$INIT_JSON")"

# 2) Unseal si nécessaire
if vault status -address="$VAULT_ADDR" 2>/dev/null | grep -q "Sealed.*false"; then
  log "Vault déjà unsealed."
else
  log "Unsealing..."
  vault operator unseal -address="$VAULT_ADDR" "$K1" >/dev/null
  vault operator unseal -address="$VAULT_ADDR" "$K2" >/dev/null
  vault operator unseal -address="$VAULT_ADDR" "$K3" >/dev/null
  log "Vault unsealed ✅"
fi

export VAULT_TOKEN="$ROOT_TOKEN"

# 3) Enable PKI engines
log "Enable PKI root (/pki) et intermediate (/pki_int)..."
vault secrets enable -address="$VAULT_ADDR" -path=pki -max-lease-ttl=87600h pki 2>/dev/null || true
vault secrets enable -address="$VAULT_ADDR" -path=pki_int -max-lease-ttl=43800h pki 2>/dev/null || true

# 4) Root CA
if vault read -address="$VAULT_ADDR" pki/cert/ca >/dev/null 2>&1; then
  log "Root CA déjà présente."
else
  log "Génération Root CA..."
  vault write -address="$VAULT_ADDR" pki/root/generate/internal \
    common_name="PFE-IoT-Security Root CA" \
    organization="FST / Tunisie Telecom" \
    country="TN" locality="Tunis" province="Tunis" \
    ttl=87600h key_type=rsa key_bits=4096 >/dev/null
  log "Root CA générée ✅"
fi

vault write -address="$VAULT_ADDR" pki/config/urls \
  issuing_certificates="$VAULT_ADDR/v1/pki/ca" \
  crl_distribution_points="$VAULT_ADDR/v1/pki/crl" >/dev/null

# 5) Intermediate CA
if vault read -address="$VAULT_ADDR" pki_int/cert/ca >/dev/null 2>&1; then
  log "Intermediate CA déjà présente."
else
  log "Génération CSR intermediate..."
  CSR="$(vault write -address="$VAULT_ADDR" -format=json pki_int/intermediate/generate/internal \
    common_name="PFE-IoT-Security Intermediate CA" \
    organization="FST / Tunisie Telecom" \
    country="TN" ttl=43800h key_type=rsa key_bits=4096 | jq -r '.data.csr')"

  echo "$CSR" > "$OUT_DIR/intermediate.csr"

  log "Signature par Root CA..."
  CERT="$(vault write -address="$VAULT_ADDR" -format=json pki/root/sign-intermediate \
    csr=@"$OUT_DIR/intermediate.csr" common_name="PFE-IoT-Security Intermediate CA" ttl=43800h | jq -r '.data.certificate')"
  echo "$CERT" > "$OUT_DIR/intermediate.crt"

  log "Import du cert intermediate signé..."
  vault write -address="$VAULT_ADDR" pki_int/intermediate/set-signed certificate=@"$OUT_DIR/intermediate.crt" >/dev/null
  log "Intermediate CA configurée ✅"
fi

vault write -address="$VAULT_ADDR" pki_int/config/urls \
  issuing_certificates="$VAULT_ADDR/v1/pki_int/ca" \
  crl_distribution_points="$VAULT_ADDR/v1/pki_int/crl" >/dev/null

# 6) Roles
log "Création des rôles..."
vault write -address="$VAULT_ADDR" pki_int/roles/iot-services \
  allowed_domains="iot-pfe.local,dmz.iot-pfe.local" allow_subdomains=true allow_bare_domains=true \
  server_flag=true client_flag=true require_cn=true \
  key_type=rsa key_bits=2048 \
  ttl=720h max_ttl=8760h >/dev/null

vault write -address="$VAULT_ADDR" pki_int/roles/iot-devices \
  allowed_domains="iot-pfe.local,iot.iot-pfe.local" allow_subdomains=true \
  server_flag=false client_flag=true require_cn=true \
  key_type=rsa key_bits=2048 \
  ttl=24h max_ttl=720h >/dev/null

vault write -address="$VAULT_ADDR" pki_int/roles/iot-siem \
  allowed_domains="iot-pfe.local,siem.iot-pfe.local" allow_subdomains=true \
  server_flag=true client_flag=true require_cn=true \
  key_type=rsa key_bits=2048 \
  ttl=720h max_ttl=8760h >/dev/null

log "Roles OK ✅"

# 7) Export CA chain (utile pour services)
log "Export CA chain..."
vault read -address="$VAULT_ADDR" -format=json pki/cert/ca | jq -r '.data.certificate' > "$OUT_DIR/root-ca.crt"
vault read -address="$VAULT_ADDR" -format=json pki_int/cert/ca | jq -r '.data.certificate' > "$OUT_DIR/intermediate-ca.crt"
cat "$OUT_DIR/root-ca.crt" "$OUT_DIR/intermediate-ca.crt" > "$OUT_DIR/ca-chain-full.crt"

log "Fichiers CA dans $OUT_DIR"
log "=== Terminé ==="