#!/bin/sh
# ============================================================
# PFE IoT Security TT — Déploiement Wazuh dans GNS3
# À exécuter sur le HOST Docker de GNS3 (VM Linux)
# ============================================================

set -e

DEPLOY_DIR="/opt/pfe/wazuh"
SIEM_NET="pfe-siem-network"

echo "============================================"
echo " PFE IoT Security TT - Wazuh SIEM Deploy"
echo "============================================"

# ---- 1) Prérequis vm.max_map_count (obligatoire pour OpenSearch) ----
echo ""
echo "[1/6] Configuration vm.max_map_count..."
CURRENT=$(sysctl -n vm.max_map_count)
if [ "$CURRENT" -lt "262144" ]; then
  sysctl -w vm.max_map_count=262144
  echo "vm.max_map_count=262144" >> /etc/sysctl.conf
  echo "    ==> Mis à jour : $CURRENT -> 262144"
else
  echo "    ==> Déjà OK : $CURRENT"
fi

# ---- 2) Créer le réseau Docker SIEM si absent ----
echo ""
echo "[2/6] Vérification du réseau $SIEM_NET..."
if ! docker network ls --format '{{.Name}}' | grep -q "^${SIEM_NET}$"; then
  docker network create \
    --driver bridge \
    --subnet 192.168.40.0/24 \
    --gateway 192.168.40.1 \
    --opt com.docker.network.bridge.name=br-siem \
    "$SIEM_NET"
  echo "    ==> Réseau $SIEM_NET créé (192.168.40.0/24)"
else
  echo "    ==> Réseau $SIEM_NET déjà présent"
fi

# ---- 3) Préparer les dossiers ----
echo ""
echo "[3/6] Création des dossiers de déploiement..."
mkdir -p "$DEPLOY_DIR"
mkdir -p /opt/pfe/results/suricata

echo "    ==> $DEPLOY_DIR"
echo "    ==> /opt/pfe/results/suricata"

# ---- 4) Copier les fichiers du projet (depuis /tmp/pfe-deploy) ----
echo ""
echo "[4/6] Copie des fichiers de configuration..."
if [ -d /tmp/pfe-deploy ]; then
  cp -r /tmp/pfe-deploy/wazuh-certs    "$DEPLOY_DIR/"
  cp -r /tmp/pfe-deploy/wazuh-config   "$DEPLOY_DIR/"
  cp    /tmp/pfe-deploy/docker-compose.wazuh.yml "$DEPLOY_DIR/"
  # Corriger le chemin du compose (chemins relatifs → absolus)
  sed -i "s|./wazuh-certs|$DEPLOY_DIR/wazuh-certs|g" "$DEPLOY_DIR/docker-compose.wazuh.yml"
  sed -i "s|./wazuh-config|$DEPLOY_DIR/wazuh-config|g" "$DEPLOY_DIR/docker-compose.wazuh.yml"
  echo "    ==> Fichiers copiés depuis /tmp/pfe-deploy"
else
  echo "    [WARN] /tmp/pfe-deploy absent — assure-toi d'avoir copié les fichiers via SCP"
fi

# ---- 5) Copier eve.json Suricata si disponible ----
echo ""
echo "[5/6] Copie du fichier Suricata eve.json..."
if [ -f /tmp/pfe-deploy/eve.json ]; then
  cp /tmp/pfe-deploy/eve.json /opt/pfe/results/suricata/eve.json
  echo "    ==> eve.json copié"
else
  # Créer un fichier vide pour que Wazuh démarre sans erreur
  echo '{}' > /opt/pfe/results/suricata/eve.json
  echo "    [INFO] eve.json vide créé (à remplacer par le vrai fichier)"
fi

# ---- 6) Démarrer Wazuh ----
echo ""
echo "[6/6] Démarrage de la stack Wazuh..."
cd "$DEPLOY_DIR"

docker compose -f docker-compose.wazuh.yml pull
docker compose -f docker-compose.wazuh.yml up -d

echo ""
echo "============================================"
echo " Stack Wazuh démarrée !"
echo " Dashboard : https://192.168.40.30"
echo " Login     : admin / SecretPassword1!"
echo " API       : https://192.168.40.10:55000"
echo "============================================"
echo ""
echo "Suivi des logs :"
echo "  docker compose -f $DEPLOY_DIR/docker-compose.wazuh.yml logs -f wazuh.manager"
