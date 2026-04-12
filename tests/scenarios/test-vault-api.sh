#!/bin/bash
# ================================================
# PFE IoT Security TT — Tests automatisés API Vault
# ================================================
# Usage : bash tests/scenarios/test-vault-api.sh [VAULT_URL]
# ================================================

VAULT="${1:-http://192.168.30.10:8200}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass=0
fail=0

ok()  { echo -e "  ${GREEN}✅ PASS${NC} — $1"; pass=$((pass+1)); }
err() { echo -e "  ${RED}❌ FAIL${NC} — $1"; fail=$((fail+1)); }

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Tests API Vault — PFE IoT Security TT        ${NC}"
echo -e "${BLUE}  Target : $VAULT                              ${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# ----------------------------------------
# Test 1 : Health endpoint reachable
# ----------------------------------------
echo -e "${YELLOW}[1] Health check${NC}"

HEALTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$VAULT/v1/sys/health")
if [ "$HEALTH_CODE" = "200" ] || [ "$HEALTH_CODE" = "429" ] || [ "$HEALTH_CODE" = "473" ]; then
  ok "/v1/sys/health accessible (HTTP $HEALTH_CODE)"
else
  err "/v1/sys/health inaccessible (HTTP $HEALTH_CODE) — Vault down ou non initialisé"
fi

# ----------------------------------------
# Test 2 : Vault initialized
# ----------------------------------------
echo ""
echo -e "${YELLOW}[2] État Vault${NC}"

INIT_STATUS=$(curl -s "$VAULT/v1/sys/init")
INITIALIZED=$(echo "$INIT_STATUS" | grep -o '"initialized":[^,}]*' | cut -d: -f2 | tr -d ' ')

if [ "$INITIALIZED" = "true" ]; then
  ok "Vault initialized=true"
else
  err "Vault initialized=false — lancer init-vault.sh"
fi

HEALTH_BODY=$(curl -s "$VAULT/v1/sys/health")
SEALED=$(echo "$HEALTH_BODY" | grep -o '"sealed":[^,}]*' | cut -d: -f2 | tr -d ' ')

if [ "$SEALED" = "false" ]; then
  ok "Vault sealed=false"
else
  err "Vault sealed=true — effectuer l'unseal (3 clés)"
fi

# ----------------------------------------
# Test 3 : PKI engines (avec token)
# ----------------------------------------
echo ""
echo -e "${YELLOW}[3] Moteurs PKI${NC}"

TOKEN_FILE=""
for f in /work/vault/root_token.txt /vault/init/root_token.env; do
  [ -f "$f" ] && TOKEN_FILE="$f" && break
done

if [ -z "$TOKEN_FILE" ]; then
  echo -e "  ${YELLOW}⚠️  root_token introuvable — tests PKI ignorés${NC}"
else
  ROOT_TOKEN=$(grep -oP '(?<<=)[^\s]+' "$TOKEN_FILE" 2>/dev/null | head -1)
  [ -z "$ROOT_TOKEN" ] && ROOT_TOKEN=$(cat "$TOKEN_FILE" | tr -d '[:space:]')

  MOUNTS=$(curl -s -H "X-Vault-Token: $ROOT_TOKEN" "$VAULT/v1/sys/mounts")

  if echo "$MOUNTS" | grep -q '"pki/"'; then
    ok "PKI root engine activé"
  else
    err "PKI root engine manquant"
  fi

  if echo "$MOUNTS" | grep -q '"pki_int/"'; then
    ok "PKI intermediate engine activé"
  else
    err "PKI intermediate engine manquant"
  fi

  # ----------------------------------------
  # Test 4 : Roles
  # ----------------------------------------
  echo ""
  echo -e "${YELLOW}[4] Rôles PKI${NC}"

  for role in iot-services iot-devices; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" \
      -H "X-Vault-Token: $ROOT_TOKEN" \
      "$VAULT/v1/pki_int/roles/$role")
    if [ "$CODE" = "200" ]; then
      ok "Rôle '$role' présent"
    else
      err "Rôle '$role' manquant (HTTP $CODE)"
    fi
  done

  # ----------------------------------------
  # Test 5 : Émettre un certificat
  # ----------------------------------------
  echo ""
  echo -e "${YELLOW}[5] Émission certificat${NC}"

  CERT=$(curl -s -X POST \
    -H "X-Vault-Token: $ROOT_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"common_name":"test-api.iot.iot-pfe.local","ttl":"1h"}' \
    "$VAULT/v1/pki_int/issue/iot-devices")

  if echo "$CERT" | grep -q '"certificate"'; then
    ok "Certificat émis avec succès"
  else
    ERRS=$(echo "$CERT" | grep -o '"errors":\[[^]]*\]' || echo "réponse inattendue")
    err "Échec émission certificat : $ERRS"
  fi
fi

# ----------------------------------------
# Résultats
# ----------------------------------------
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "  Résultats : ${GREEN}$pass PASS${NC} / ${RED}$fail FAIL${NC}"
echo -e "${BLUE}================================================${NC}"

if [ "$fail" -eq 0 ]; then
  echo -e "  ${GREEN}🎉 Vault 100% OK — PKI opérationnelle.${NC}"
else
  echo -e "  ${RED}⚠️  $fail test(s) échoué(s)${NC}"
fi
echo ""

exit "$fail"
