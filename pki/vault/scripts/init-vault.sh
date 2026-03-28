
#!/bin/sh
# ================================================
# PFE IoT Security TT — Initialisation PKI Vault
# ================================================

set -e

VAULT_ADDR="http://vault:8200"
INIT_FILE="/vault/init/init-keys.json"
LOG_FILE="/vault/init/init.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE; }

log "=== Démarrage initialisation Vault PKI ==="
log "Vault address: $VAULT_ADDR"

# Attendre que Vault soit prêt
log "Attente de Vault..."
until vault status -address=$VAULT_ADDR 2>&1 | grep -q "Initialized"; do
  sleep 2
done
log "Vault est disponible ✅"

# Vérifier si déjà initialisé
if vault status -address=$VAULT_ADDR 2>&1 | grep -q "Initialized.*true"; then
  log "Vault déjà initialisé — skip init"
else
  # ========================================
  # ÉTAPE 1 : Initialisation de Vault
  # ========================================
  log "Initialisation de Vault..."
  vault operator init \
    -address=$VAULT_ADDR \
    -key-shares=5 \
    -key-threshold=3 \
    -format=json > $INIT_FILE

  log "✅ Vault initialisé — clés sauvegardées dans $INIT_FILE"
  log "⚠️  IMPORTANT : Sauvegardez ces clés en lieu sûr !"
fi

# Récupérer le Root Token
ROOT_TOKEN=$(cat $INIT_FILE | grep -o '"root_token":"[^"]*"' | cut -d'"' -f4)
UNSEAL_KEY_1=$(cat $INIT_FILE | grep -o '"unseal_keys_b64":\["[^"]*"' | cut -d'"' -f4)
UNSEAL_KEY_2=$(cat $INIT_FILE | python3 -c "import sys,json; d=json.load(open('/vault/init/init-keys.json')); print(d['unseal_keys_b64'][1])")
UNSEAL_KEY_3=$(cat $INIT_FILE | python3 -c "import sys,json; d=json.load(open('/vault/init/init-keys.json')); print(d['unseal_keys_b64'][2])")

# ========================================
# ÉTAPE 2 : Descellement (Unseal)
# ========================================
log "Descellement de Vault (unseal)..."
vault operator unseal -address=$VAULT_ADDR $UNSEAL_KEY_1
vault operator unseal -address=$VAULT_ADDR $UNSEAL_KEY_2
vault operator unseal -address=$VAULT_ADDR $UNSEAL_KEY_3
log "✅ Vault descellé"

export VAULT_TOKEN=$ROOT_TOKEN

# ========================================
# ÉTAPE 3 : Configuration PKI Root CA
# ========================================
log "Configuration PKI Engine — Root CA..."

# Activer le moteur PKI pour Root CA
vault secrets enable \
  -address=$VAULT_ADDR \
  -path=pki \
  -max-lease-ttl=87600h \
  pki 2>/dev/null || log "PKI Root déjà activé"

# Générer le certificat Root CA
vault write -address=$VAULT_ADDR \
  pki/root/generate/internal \
  common_name="PFE-IoT-Security Root CA" \
  organization="FST / Tunisie Telecom" \
  country="TN" \
  locality="Tunis" \
  province="Tunis" \
  ttl=87600h \
  key_type=rsa \
  key_bits=4096 \
  > /vault/init/root-ca.json

log "✅ Root CA générée"

# Configurer les URLs Root CA
vault write -address=$VAULT_ADDR \
  pki/config/urls \
  issuing_certificates="http://vault:8200/v1/pki/ca" \
  crl_distribution_points="http://vault:8200/v1/pki/crl"

# ========================================
# ÉTAPE 4 : Configuration PKI Intermediate CA
# ========================================
log "Configuration PKI Engine — Intermediate CA..."

# Activer le moteur PKI pour Intermediate CA
vault secrets enable \
  -address=$VAULT_ADDR \
  -path=pki_int \
  -max-lease-ttl=43800h \
  pki 2>/dev/null || log "PKI Intermediate déjà activé"

# Générer le CSR de l'Intermediate CA
vault write -address=$VAULT_ADDR \
  -format=json \
  pki_int/intermediate/generate/internal \
  common_name="PFE-IoT-Security Intermediate CA" \
  organization="FST / Tunisie Telecom" \
  country="TN" \
  ttl=43800h \
  key_type=rsa \
  key_bits=4096 \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['csr'])" \
  > /vault/init/intermediate-ca.csr

log "✅ CSR Intermediate CA généré"

# Signer l'Intermediate CA par la Root CA
vault write -address=$VAULT_ADDR \
  -format=json \
  pki/root/sign-intermediate \
  csr=@/vault/init/intermediate-ca.csr \
  common_name="PFE-IoT-Security Intermediate CA" \
  ttl=43800h \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['certificate'])" \
  > /vault/init/intermediate-ca.crt

log "✅ Intermediate CA signée par Root CA"

# Importer le certificat signé dans pki_int
vault write -address=$VAULT_ADDR \
  pki_int/intermediate/set-signed \
  certificate=@/vault/init/intermediate-ca.crt

# Configurer les URLs Intermediate CA
vault write -address=$VAULT_ADDR \
  pki_int/config/urls \
  issuing_certificates="http://vault:8200/v1/pki_int/ca" \
  crl_distribution_points="http://vault:8200/v1/pki_int/crl"

log "✅ Intermediate CA configurée"

# ========================================
# ÉTAPE 5 : Création des Rôles PKI
# ========================================
log "Création des rôles PKI..."

# Rôle pour les brokers/services (DMZ)
vault write -address=$VAULT_ADDR \
  pki_int/roles/iot-services \
  allowed_domains="iot-pfe.local,dmz.iot-pfe.local" \
  allow_subdomains=true \
  allow_bare_domains=true \
  max_ttl=8760h \
  ttl=720h \
  key_type=rsa \
  key_bits=2048 \
  require_cn=true \
  server_flag=true \
  client_flag=true

# Rôle pour les devices IoT
vault write -address=$VAULT_ADDR \
  pki_int/roles/iot-devices \
  allowed_domains="iot-pfe.local,iot.iot-pfe.local" \
  allow_subdomains=true \
  max_ttl=720h \
  ttl=24h \
  key_type=rsa \
  key_bits=2048 \
  require_cn=true \
  server_flag=false \
  client_flag=true

# Rôle pour les composants SIEM
vault write -address=$VAULT_ADDR \
  pki_int/roles/iot-siem \
  allowed_domains="iot-pfe.local,siem.iot-pfe.local" \
  allow_subdomains=true \
  max_ttl=8760h \
  ttl=720h \
  key_type=rsa \
  key_bits=2048 \
  server_flag=true \
  client_flag=true

log "✅ Rôles PKI créés"

# ========================================
# ÉTAPE 6 : Création des Policies Vault
# ========================================
log "Création des policies Vault..."

# Policy pour les services IoT (brokers)
vault policy write -address=$VAULT_ADDR iot-services-policy - <<'EOF'
# Politique pour les services IoT (brokers, gateways)
path "pki_int/issue/iot-services" {
  capabilities = ["create", "update"]
}
path "pki_int/sign/iot-services" {
  capabilities = ["create", "update"]
}
path "pki_int/ca/pem" {
  capabilities = ["read"]
}
path "pki_int/crl/rotate" {
  capabilities = ["create", "update"]
}
path "pki/ca/pem" {
  capabilities = ["read"]
}
EOF

# Policy pour les devices IoT
vault policy write -address=$VAULT_ADDR iot-devices-policy - <<'EOF'
# Politique pour les devices IoT (capteurs)
path "pki_int/issue/iot-devices" {
  capabilities = ["create", "update"]
}
path "pki_int/ca/pem" {
  capabilities = ["read"]
}
path "pki/ca/pem" {
  capabilities = ["read"]
}
EOF

# Policy pour SIEM
vault policy write -address=$VAULT_ADDR iot-siem-policy - <<'EOF'
# Politique pour les composants SIEM
path "pki_int/issue/iot-siem" {
  capabilities = ["create", "update"]
}
path "pki_int/ca/pem" {
  capabilities = ["read"]
}
path "pki/ca/pem" {
  capabilities = ["read"]
}
EOF

log "✅ Policies créées"

# ========================================
# ÉTAPE 7 : Création des Tokens d'accès
# ========================================
log "Création des tokens d'accès..."

vault token create \
  -address=$VAULT_ADDR \
  -policy=iot-services-policy \
  -display-name="iot-services-token" \
  -ttl=8760h \
  -renewable=true \
  -format=json \
  > /vault/init/token-services.json

vault token create \
  -address=$VAULT_ADDR \
  -policy=iot-devices-policy \
  -display-name="iot-devices-token" \
  -ttl=720h \
  -renewable=true \
  -format=json \
  > /vault/init/token-devices.json

log "✅ Tokens créés"

# ========================================
# ÉTAPE 8 : Émettre les premiers certificats
# ========================================
log "Émission des certificats pour les services..."

# Certificat Mosquitto MQTT Broker
vault write -address=$VAULT_ADDR \
  -format=json \
  pki_int/issue/iot-services \
  common_name="mosquitto.dmz.iot-pfe.local" \
  alt_names="mqtt.iot-pfe.local,localhost" \
  ip_sans="192.168.20.10,127.0.0.1" \
  ttl=720h \
  > /vault/init/cert-mosquitto.json

# Certificat CoAP Gateway
vault write -address=$VAULT_ADDR \
  -format=json \
  pki_int/issue/iot-services \
  common_name="coap.dmz.iot-pfe.local" \
  alt_names="coap.iot-pfe.local" \
  ip_sans="192.168.20.11,127.0.0.1" \
  ttl=720h \
  > /vault/init/cert-coap.json

# Certificat HTTP Gateway
vault write -address=$VAULT_ADDR \
  -format=json \
  pki_int/issue/iot-services \
  common_name="http.dmz.iot-pfe.local" \
  alt_names="api.iot-pfe.local" \
  ip_sans="192.168.20.12,127.0.0.1" \
  ttl=720h \
  > /vault/init/cert-http.json

log "✅ Certificats services émis"

# ========================================
# ÉTAPE 9 : Extraire les certificats
# ========================================
log "Extraction des certificats..."

extract_cert() {
  local json_file=$1
  local out_dir=$2
  local name=$3

  python3 -c "
import json, sys
with open('$json_file') as f:
    d = json.load(f)['data']
with open('$out_dir/$name.crt', 'w') as f:
    f.write(d['certificate'])
with open('$out_dir/$name.key', 'w') as f:
    f.write(d['private_key'])
with open('$out_dir/$name-chain.crt', 'w') as f:
    f.write(d['ca_chain'][0])
print('✅ Extrait: $name')
"
}

mkdir -p /vault/init/certs
extract_cert /vault/init/cert-mosquitto.json /vault/init/certs mosquitto
extract_cert /vault/init/cert-coap.json      /vault/init/certs coap-gateway
extract_cert /vault/init/cert-http.json      /vault/init/certs http-gateway

# Extraire la CA chain
vault read -address=$VAULT_ADDR -format=json pki/cert/ca \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['certificate'])" \
  > /vault/init/certs/root-ca.crt

vault read -address=$VAULT_ADDR -format=json pki_int/cert/ca \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['certificate'])" \
  > /vault/init/certs/intermediate-ca.crt

cat /vault/init/certs/root-ca.crt \
    /vault/init/certs/intermediate-ca.crt \
    > /vault/init/certs/ca-chain-full.crt

log "✅ CA chain extraite"
log "=== Initialisation PKI terminée avec succès ! ==="
log ""
log "RÉSUMÉ:"
log "  Root CA      : /vault/init/certs/root-ca.crt"
log "  Intermediate : /vault/init/certs/intermediate-ca.crt"
log "  CA Chain     : /vault/init/certs/ca-chain-full.crt"
log "  Certificats  : /vault/init/certs/"
log "  Tokens       : /vault/init/token-*.json"
log "  Init Keys    : /vault/init/init-keys.json"
log ""
log "⚠️  SÉCURITÉ : Ne commitez JAMAIS les fichiers .key et init-keys.json !"