#!/bin/bash
# ================================================
# PFE IoT Security TT — Vérification environnement
# ================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  PFE IoT Security TT — Check Environnement    ${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

check_cmd() {
  local name=$1
  local cmd=$2
  local expected=$3
  if command -v $cmd &> /dev/null; then
    version=$(eval $cmd 2>&1 | head -1)
    echo -e "  ${GREEN}✅ $name${NC} — $version"
  else
    echo -e "  ${RED}❌ $name — NON INSTALLÉ${NC}"
  fi
}

check_docker_network() {
  local name=$1
  if docker network ls | grep -q $name; then
    echo -e "  ${GREEN}✅ Réseau Docker : $name${NC}"
  else
    echo -e "  ${RED}❌ Réseau Docker manquant : $name${NC}"
  fi
}

echo -e "${YELLOW}[1] Outils système${NC}"
check_cmd "Git" "git" "git version"
check_cmd "Python3" "python3" "Python 3"
check_cmd "pip3" "pip3" "pip"
check_cmd "OpenSSL" "openssl" "OpenSSL"
check_cmd "curl" "curl" "curl"
check_cmd "jq" "jq" "jq"
check_cmd "tree" "tree" "tree"
echo ""

echo -e "${YELLOW}[2] Docker${NC}"
check_cmd "Docker" "docker" "Docker version"
check_cmd "Docker Compose" "docker" "docker compose version"
if docker info &> /dev/null; then
  echo -e "  ${GREEN}✅ Docker daemon — En cours d'exécution${NC}"
else
  echo -e "  ${RED}❌ Docker daemon — Arrêté${NC}"
fi
echo ""

echo -e "${YELLOW}[3] Réseaux Docker${NC}"
check_docker_network "pfe-iot-network"
check_docker_network "pfe-dmz-network"
check_docker_network "pfe-pki-network"
check_docker_network "pfe-siem-network"
check_docker_network "pfe-analyse-network"
echo ""

echo -e "${YELLOW}[4] Python — Packages PFE${NC}"
packages=("paho-mqtt" "aiocoap" "pandas" "sklearn" "cryptography" "hvac" "jupyter")
for pkg in "${packages[@]}"; do
  if python3 -c "import ${pkg//-/_}" 2>/dev/null || python3 -c "import $pkg" 2>/dev/null; then
    echo -e "  ${GREEN}✅ Python: $pkg${NC}"
  else
    echo -e "  ${YELLOW}⚠️  Python: $pkg — Non installé (activer .venv ?)${NC}"
  fi
done
echo ""

echo -e "${YELLOW}[5] Structure du projet${NC}"
dirs=("architecture" "infrastructure" "pki" "iot" "security" "siem" "ml" "tests" "scripts" "results" "documentation" "journal")
for dir in "${dirs[@]}"; do
  if [ -d "$dir" ]; then
    echo -e "  ${GREEN}✅ Dossier: $dir/${NC}"
  else
    echo -e "  ${RED}❌ Dossier manquant: $dir/${NC}"
  fi
done
echo ""

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Vérification terminée${NC}"
echo -e "${BLUE}================================================${NC}"