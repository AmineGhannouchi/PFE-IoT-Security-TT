#!/bin/bash
# ================================================
# PFE IoT Security TT — Rotation des certificats
# ================================================

VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-$(cat /vault/init/token-services.json | python3 -c "import sys,json; print(json.load(sys.stdin)['auth']['client_token'])")}"
CERTS_DIR="./pki/certificates/services"
LOG_FILE="./journal/rotation-$(date +%Y%m%d).log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE; }

log "=== Début rotation certificats ==="

rotate_cert() {
  local service=$1
  local cn=$2
  local ip=$3
  local role=$4

  log "Rotation certificat: $service ($cn)"

  # Émettre nouveau certificat
  result=$(vault write \
    -address=$VAULT_ADDR \
    -format=json \
    pki_int/issue/$role \
    common_name="$cn" \
    ip_sans="$ip,127.0.0.1" \
    ttl=720h)

  if [ $? -eq 0 ]; then
    # Sauvegarder avec timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    echo "$result" | python3 -c "
import sys, json
d = json.load(sys.stdin)['data']
open('$CERTS_DIR/${service}_${timestamp}.crt', 'w').write(d['certificate'])
open('$CERTS_DIR/${service}_${timestamp}.key', 'w').write(d['private_key'])
# Lien symbolique vers le dernier
import os
for ext in ['crt', 'key']:
    link = '$CERTS_DIR/${service}.' + ext
    if os.path.islink(link): os.remove(link)
    os.symlink('${service}_${timestamp}.' + ext, link)
print('✅ Certificat rotaté: $service')
"
    log "✅ $service — rotation réussie"
  else
    log "❌ $service — échec rotation !"
    return 1
  fi
}

# Rotation de tous les certificats services
rotate_cert "mosquitto"    "mosquitto.dmz.iot-pfe.local" "192.168.20.10" "iot-services"
rotate_cert "coap-gateway" "coap.dmz.iot-pfe.local"      "192.168.20.11" "iot-services"
rotate_cert "http-gateway" "http.dmz.iot-pfe.local"      "192.168.20.12" "iot-services"

# Rotation CRL
log "Rotation CRL..."
vault write -address=$VAULT_ADDR pki_int/crl/rotate
vault write -address=$VAULT_ADDR pki/crl/rotate
log "✅ CRL mise à jour"

log "=== Rotation terminée ==="