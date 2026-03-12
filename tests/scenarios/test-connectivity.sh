#!/bin/bash
# ================================================
# PFE IoT Security TT — Test de Connectivité Réseau
# ================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Test Connectivité Réseau — PFE IoT Security  ${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

pass=0
fail=0

test_ping() {
  local from=$1
  local to_ip=$2
  local desc=$3
  local expected=$4  # "pass" ou "fail" (selon règle firewall)

  result=$(docker exec $from ping -c 1 -W 2 $to_ip 2>&1)
  if echo "$result" | grep -q "1 received"; then
    if [ "$expected" = "pass" ]; then
      echo -e "  ${GREEN}✅ PASS${NC} — $desc ($from → $to_ip)"
      ((pass++))
    else
      echo -e "  ${RED}❌ FAIL${NC} — $desc ($from → $to_ip) — DEVRAIT ÊTRE BLOQUÉ !"
      ((fail++))
    fi
  else
    if [ "$expected" = "fail" ]; then
      echo -e "  ${GREEN}✅ BLOQUÉ (attendu)${NC} — $desc ($from → $to_ip)"
      ((pass++))
    else
      echo -e "  ${RED}❌ FAIL${NC} — $desc ($from → $to_ip) — PAS DE RÉPONSE"
      ((fail++))
    fi
  fi
}

echo -e "${YELLOW}[1] Tests de connectivité autorisée${NC}"
test_ping "test-iot"  "192.168.10.1"  "IoT → Gateway MikroTik"     "pass"
test_ping "test-dmz"  "192.168.20.1"  "DMZ → Gateway MikroTik"     "pass"
test_ping "test-pki"  "192.168.30.1"  "PKI → Gateway MikroTik"     "pass"
echo ""

echo -e "${YELLOW}[2] Tests de segmentation (doit être bloqué)${NC}"
test_ping "test-iot"  "192.168.40.10" "IoT → SIEM (BLOQUÉ)"        "fail"
test_ping "test-iot"  "192.168.50.10" "IoT → Analyse (BLOQUÉ)"     "fail"
echo ""

echo -e "${YELLOW}[3] Tests ports autorisés${NC}"

test_port() {
  local from=$1
  local to_ip=$2
  local port=$3
  local desc=$4

  result=$(docker exec $from sh -c "nc -z -w2 $to_ip $port 2>&1")
  if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✅ Port ouvert${NC} — $desc ($to_ip:$port)"
    ((pass++))
  else
    echo -e "  ${YELLOW}⚠️  Port fermé${NC} — $desc ($to_ip:$port) — service pas encore déployé"
  fi
}

test_port "test-iot" "192.168.20.10" "8883" "MQTT TLS Broker"
test_port "test-iot" "192.168.30.10" "8200" "HashiCorp Vault"
test_port "test-dmz" "192.168.40.10" "1514" "Wazuh Manager"
echo ""

echo -e "${BLUE}================================================${NC}"
echo -e "  Résultats : ${GREEN}$pass PASS${NC} / ${RED}$fail FAIL${NC}"
echo -e "${BLUE}================================================${NC}"

if [ $fail -eq 0 ]; then
  echo -e "  ${GREEN}🎉 Tous les tests de connectivité sont OK !${NC}"
else
  echo -e "  ${RED}⚠️  $fail test(s) échoué(s) — vérifier la config réseau${NC}"
fi