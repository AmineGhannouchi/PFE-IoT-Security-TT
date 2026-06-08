#!/bin/bash
# =====================================================
# build-all.sh — Builder toutes les images Docker
# PFE IoT Security TT
# À exécuter sur Ubuntu depuis la racine du projet
# =====================================================
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
echo "============================================"
echo " PFE IoT Security TT — Build Docker Images"
echo " Racine : $PROJECT_ROOT"
echo "============================================"

# 1. pfe-mosquitto (Zone DMZ)
echo ""
echo "[1/4] Building pfe-mosquitto..."
docker build -t pfe-mosquitto "$PROJECT_ROOT/iot/broker/mosquitto-gns3"
echo "      OK pfe-mosquitto"

# 2. pfe-wazuh (Zone SIEM)
echo ""
echo "[2/4] Building pfe-wazuh..."
docker build -t pfe-wazuh "$PROJECT_ROOT/siem/wazuh-gns3"
echo "      OK pfe-wazuh"

# 3. pfe-ml-engine (Zone Analyse)
echo ""
echo "[3/4] Building pfe-ml-engine..."
docker build -t pfe-ml-engine "$PROJECT_ROOT/ml/docker/pfe-ml-engine"
echo "      OK pfe-ml-engine"

# 4. pfe-fleet-sim (Zone IoT)
echo ""
echo "[4/4] Building pfe-fleet-sim..."
docker build -t pfe-fleet-sim "$PROJECT_ROOT/iot/device-sim/fleet-sim"
echo "      OK pfe-fleet-sim"

echo ""
echo "============================================"
echo " Toutes les images buildées avec succès !"
echo "============================================"
docker images | grep pfe
