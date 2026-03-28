#!/bin/bash
# ================================================
# PFE IoT Security TT — Vérification chaîne PKI
# ================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CERTS_DIR="./pki/certificates"
VAULT_INIT="/var/lib/docker/volumes/pfe-vault-init-data/_data/certs"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Vérification PKI — PFE IoT Security TT       ${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

pass=0; fail=0

check_cert() {
  local name=$1
  local cert_file=$2

  if [ ! -f "$cert_file" ]; then
    echo -e "  ${RED}❌ $name — Fichier introuvable: $cert_file${NC}"
    ((fail++)); return
  fi

  # Vérifier validité
  expiry=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2)
  subject=$(openssl x509 -subject -noout -in "$cert_file" 2>/dev/null | cut -d= -f2-)
  issuer=$(openssl x509 -issuer -noout -in "$cert_file" 2>/dev/null | cut -d= -f2-)

  # Vérifier si expiré
  if openssl x509 -checkend 0 -noout -in "$cert_file" 2>/dev/null; then
    echo -e "  ${GREEN}✅ $name${NC}"
    echo -e "     Subject : $subject"
    echo -e "     Expiry  : $expiry"
    echo -e "     Issuer  : $issuer"
    ((pass++))
  else
    echo -e "  ${RED}❌ $name — EXPIRÉ !${NC}"
    ((fail++))
  fi
}

verify_chain() {
  local name=$1
  local cert=$2
  local ca_chain=$3

  result=$(openssl verify -CAfile "$ca_chain" "$cert" 2>&1)
  if echo "$result" | grep -q "OK"; then
    echo -e "  ${GREEN}✅ Chaîne valide : $name${NC}"
    ((pass++))
  else
    echo -e "  ${RED}❌ Chaîne invalide : $name${NC}"
    echo -e "     $result"
    ((fail++))
  fi
}

echo -e "${YELLOW}[1] Certificats CA${NC}"
check_cert "Root CA"           "$VAULT_INIT/root-ca.crt"
check_cert "Intermediate CA"   "$VAULT_INIT/intermediate-ca.crt"
echo ""

echo -e "${YELLOW}[2] Certificats Services${NC}"
check_cert "Mosquitto MQTT"    "$VAULT_INIT/mosquitto.crt"
check_cert "CoAP Gateway"      "$VAULT_INIT/coap-gateway.crt"
check_cert "HTTP Gateway"      "$VAULT_INIT/http-gateway.crt"
echo ""

echo -e "${YELLOW}[3] Vérification Chaîne de Confiance${NC}"
CA_CHAIN="$VAULT_INIT/ca-chain-full.crt"
verify_chain "Mosquitto MQTT"  "$VAULT_INIT/mosquitto.crt"    "$CA_CHAIN"
verify_chain "CoAP Gateway"    "$VAULT_INIT/coap-gateway.crt" "$CA_CHAIN"
verify_chain "HTTP Gateway"    "$VAULT_INIT/http-gateway.crt" "$CA_CHAIN"
echo ""

echo -e "${YELLOW}[4] Vault API Health Check${NC}"
VAULT_STATUS=$(curl -s http://localhost:8200/v1/sys/health | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    sealed = d.get('sealed', True)
    init = d.get('initialized', False)
    print(f'initialized={init}, sealed={sealed}')
except:
    print('error')
")
echo -e "  Vault status: $VAULT_STATUS"

if echo "$VAULT_STATUS" | grep -q "initialized=True, sealed=False"; then
  echo -e "  ${GREEN}✅ Vault opérationnel${NC}"
  ((pass++))
else
  echo -e "  ${RED}❌ Vault non disponible ou scellé${NC}"
  ((fail++))
fi
echo ""

echo -e "${BLUE}================================================${NC}"
echo -e "  Résultats : ${GREEN}$pass PASS${NC} / ${RED}$fail FAIL${NC}"
echo -e "${BLUE}================================================${NC}"