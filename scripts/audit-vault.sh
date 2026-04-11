#!/bin/bash
# ================================================
# PFE IoT Security TT — Audit complet Vault
# Étape 1 : Vérification état + API + réseau + PKI
# ================================================
# Usage (depuis pfe-toolbox) :
#   sh /scripts/audit-vault.sh [VAULT_URL]
# Défaut : http://192.168.30.10:8200
# ================================================

VAULT="${1:-http://192.168.30.10:8200}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass=0
fail=0
warn=0

ok()   { echo -e "  ${GREEN}✅ $1${NC}"; pass=$((pass+1)); }
err()  { echo -e "  ${RED}❌ $1${NC}";  fail=$((fail+1)); }
warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; warn=$((warn+1)); }
info() { echo -e "  ${BLUE}ℹ  $1${NC}"; }

banner() {
  echo ""
  echo -e "${BLUE}--------------------------------------------------${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}--------------------------------------------------${NC}"
}

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Audit Vault — PFE IoT Security TT            ${NC}"
echo -e "${BLUE}  Target : $VAULT                              ${NC}"
echo -e "${BLUE}================================================${NC}"

# ----------------------------------------
# 1. Réseau — ping + port
# ----------------------------------------
banner "1. Connectivité réseau vers PKI zone"

VAULT_HOST=$(echo "$VAULT" | sed 's|http://||' | cut -d: -f1)
VAULT_PORT=$(echo "$VAULT" | sed 's|http://||' | cut -d: -f2)

if ping -c 1 -W 2 "$VAULT_HOST" >/dev/null 2>&1; then
  ok "Ping $VAULT_HOST OK"
else
  err "Ping $VAULT_HOST KO — vérifier routage inter-zone"
fi

if nc -z -w2 "$VAULT_HOST" "$VAULT_PORT" 2>/dev/null; then
  ok "Port $VAULT_PORT ouvert sur $VAULT_HOST"
else
  err "Port $VAULT_PORT fermé sur $VAULT_HOST — Vault non démarré ?"
fi

# ----------------------------------------
# 2. API — /v1/sys/health
# ----------------------------------------
banner "2. API Vault — /v1/sys/health"

HEALTH=$(curl -sS -w "\n__HTTP_%{http_code}" "$VAULT/v1/sys/health" 2>/dev/null)
HTTP_CODE=$(echo "$HEALTH" | grep '__HTTP_' | sed 's/__HTTP_//')
BODY=$(echo "$HEALTH" | grep -v '__HTTP_')

info "HTTP status : $HTTP_CODE"
info "Réponse brute :"
echo "$BODY" | grep -v '^$' | sed 's/^/    /'

case "$HTTP_CODE" in
  200)
    ok "Vault initialized=true, sealed=false (active)"
    ;;
  429)
    warn "Vault initialized=true, sealed=false (standby)"
    ;;
  473)
    warn "Vault initialized=true, sealed=false (performance standby)"
    ;;
  501)
    err "Vault NOT initialized — lancer init-vault.sh"
    ;;
  503)
    err "Vault initialized=true mais SEALED — lancer unseal"
    ;;
  *)
    err "Réponse inattendue HTTP $HTTP_CODE"
    ;;
esac

INITIALIZED=$(echo "$BODY" | grep -o '"initialized":[^,}]*' | cut -d: -f2 | tr -d ' ')
SEALED=$(echo "$BODY"      | grep -o '"sealed":[^,}]*'      | cut -d: -f2 | tr -d ' ')

info "initialized: $INITIALIZED | sealed: $SEALED"

# ----------------------------------------
# 3. PKI — moteurs secrets
# ----------------------------------------
banner "3. PKI — état des moteurs secrets"

TOKEN_FILE=""
for f in /work/vault/root_token.txt /vault/init/root_token.env; do
  [ -f "$f" ] && TOKEN_FILE="$f" && break
done

if [ -z "$TOKEN_FILE" ]; then
  warn "Fichier root_token introuvable — tests PKI ignorés"
  warn "Cherché dans : /work/vault/root_token.txt, /vault/init/root_token.env"
else
  ROOT_TOKEN=$(grep -oP '(?<==)[^\s]+' "$TOKEN_FILE" 2>/dev/null | head -1)
  [ -z "$ROOT_TOKEN" ] && ROOT_TOKEN=$(cat "$TOKEN_FILE" | tr -d '[:space:]')
  info "Root token trouvé dans $TOKEN_FILE"

  MOUNTS=$(curl -sS -H "X-Vault-Token: $ROOT_TOKEN" "$VAULT/v1/sys/mounts" 2>/dev/null)

  for engine in pki pki_int; do
    if echo "$MOUNTS" | grep -q "\"$engine/\""; then
      ok "Moteur secret '$engine' activé"
    else
      err "Moteur secret '$engine' manquant — relancer bootstrap-pki-api.sh"
    fi
  done

  # Test émettre un certificat de test
  banner "4. PKI — Émission certificat test (iot-devices)"

  CERT_RESP=$(curl -sS -X POST \
    -H "X-Vault-Token: $ROOT_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"common_name":"audit-test.iot.iot-pfe.local","ttl":"1h"}' \
    "$VAULT/v1/pki_int/issue/iot-devices" 2>/dev/null)

  if echo "$CERT_RESP" | grep -q '"certificate"'; then
    ok "Certificat test émis avec succès via pki_int/issue/iot-devices"
    SERIAL=$(echo "$CERT_RESP" | grep -o '"serial_number":"[^"]*"' | cut -d'"' -f4)
    info "Serial : $SERIAL"
  else
    ERR_MSG=$(echo "$CERT_RESP" | grep -o '"errors":\[[^]]*\]' || echo "inconnu")
    err "Émission certificat échouée : $ERR_MSG"
  fi

  # Roles
  banner "5. PKI — Roles configurés"
  for role in iot-services iot-devices; do
    ROLE_RESP=$(curl -sS -o /dev/null -w "%{http_code}" \
      -H "X-Vault-Token: $ROOT_TOKEN" \
      "$VAULT/v1/pki_int/roles/$role" 2>/dev/null)
    if [ "$ROLE_RESP" = "200" ]; then
      ok "Rôle '$role' configuré"
    else
      err "Rôle '$role' manquant (HTTP $ROLE_RESP)"
    fi
  done
fi

# ----------------------------------------
# Résumé
# ----------------------------------------
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "  Résultats : ${GREEN}$pass PASS${NC} / ${RED}$fail FAIL${NC} / ${YELLOW}$warn WARN${NC}"
echo -e "${BLUE}================================================${NC}"

if [ "$fail" -eq 0 ]; then
  echo -e "  ${GREEN}🎉 Vault 100% opérationnel — passage à MQTT autorisé.${NC}"
else
  echo -e "  ${RED}⚠️  $fail problème(s) détecté(s) — corriger avant MQTT.${NC}"
fi
echo ""

exit "$fail"
