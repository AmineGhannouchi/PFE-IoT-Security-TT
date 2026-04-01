#!/bin/sh
set -e

VAULT="http://192.168.30.10:8200"
ROOT_TOKEN_FILE="/work/vault/root_token.txt"

if [ ! -f "$ROOT_TOKEN_FILE" ]; then
  echo "❌ root_token.txt introuvable. Fais d'abord init/unseal."
  exit 1
fi

ROOT_TOKEN=$(cut -d= -f2 "$ROOT_TOKEN_FILE")

h() { echo "==> $1"; }
req() {
  method=$1; path=$2; data=$3
  if [ -n "$data" ]; then
    curl -sS -X "$method" \
      -H "X-Vault-Token: $ROOT_TOKEN" \
      -H "Content-Type: application/json" \
      --data "$data" \
      "$VAULT$path"
  else
    curl -sS -X "$method" \
      -H "X-Vault-Token: $ROOT_TOKEN" \
      "$VAULT$path"
  fi
}

# ----------------------------
# 1) Enable PKI engines
# ----------------------------
h "Enable PKI root at /pki (ignore error if exists)"
req POST "/v1/sys/mounts/pki" '{"type":"pki","config":{"max_lease_ttl":"87600h"}}' || true

h "Enable PKI intermediate at /pki_int (ignore error if exists)"
req POST "/v1/sys/mounts/pki_int" '{"type":"pki","config":{"max_lease_ttl":"43800h"}}' || true

# ----------------------------
# 2) Generate Root CA (internal)
# ----------------------------
h "Generate Root CA"
req POST "/v1/pki/root/generate/internal" '{
  "common_name":"PFE-IoT-Security Root CA",
  "organization":"FST / Tunisie Telecom",
  "country":"TN",
  "locality":"Tunis",
  "province":"Tunis",
  "ttl":"87600h",
  "key_type":"rsa",
  "key_bits":4096
}' | tee /work/vault/root-ca.json >/dev/null

# URLs Root
h "Configure Root URLs"
req POST "/v1/pki/config/urls" '{
  "issuing_certificates":"http://192.168.30.10:8200/v1/pki/ca",
  "crl_distribution_points":"http://192.168.30.10:8200/v1/pki/crl"
}' >/dev/null

# ----------------------------
# 3) Generate Intermediate CSR
# ----------------------------
h "Generate Intermediate CSR"
req POST "/v1/pki_int/intermediate/generate/internal" '{
  "common_name":"PFE-IoT-Security Intermediate CA",
  "organization":"FST / Tunisie Telecom",
  "ttl":"43800h",
  "key_type":"rsa",
  "key_bits":4096
}' | tee /work/vault/int-csr.json >/dev/null

CSR=$(jq -r '.data.csr' /work/vault/int-csr.json)

# ----------------------------
# 4) Sign Intermediate with Root
# ----------------------------
h "Sign Intermediate CSR with Root"
req POST "/v1/pki/root/sign-intermediate" "$(jq -n --arg csr "$CSR" '{
  csr:$csr,
  common_name:"PFE-IoT-Security Intermediate CA",
  ttl:"43800h"
}')" | tee /work/vault/int-signed.json >/dev/null

CERT=$(jq -r '.data.certificate' /work/vault/int-signed.json)

# ----------------------------
# 5) Set signed Intermediate
# ----------------------------
h "Set signed Intermediate cert"
req POST "/v1/pki_int/intermediate/set-signed" "$(jq -n --arg cert "$CERT" '{certificate:$cert}')" >/dev/null

# URLs Intermediate
h "Configure Intermediate URLs"
req POST "/v1/pki_int/config/urls" '{
  "issuing_certificates":"http://192.168.30.10:8200/v1/pki_int/ca",
  "crl_distribution_points":"http://192.168.30.10:8200/v1/pki_int/crl"
}' >/dev/null

# ----------------------------
# 6) Roles
# ----------------------------
h "Create role iot-services"
req POST "/v1/pki_int/roles/iot-services" '{
  "allowed_domains":"iot-pfe.local,dmz.iot-pfe.local",
  "allow_subdomains":true,
  "allow_bare_domains":true,
  "max_ttl":"8760h",
  "ttl":"720h",
  "key_type":"rsa",
  "key_bits":2048,
  "server_flag":true,
  "client_flag":true
}' >/dev/null

h "Create role iot-devices"
req POST "/v1/pki_int/roles/iot-devices" '{
  "allowed_domains":"iot-pfe.local,iot.iot-pfe.local",
  "allow_subdomains":true,
  "max_ttl":"720h",
  "ttl":"24h",
  "key_type":"rsa",
  "key_bits":2048,
  "server_flag":false,
  "client_flag":true
}' >/dev/null

h "✅ PKI bootstrap done."
echo "Artifacts in /work/vault/"