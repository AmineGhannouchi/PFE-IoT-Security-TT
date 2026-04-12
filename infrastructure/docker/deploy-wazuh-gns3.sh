#!/bin/bash
# ============================================================
# PFE IoT Security TT — Déploiement Wazuh sur GNS3 VM
# Exécuter depuis la GNS3 VM en SSH ou console
# Chemin projet : /home/gns3/PFE-IoT-Security-TT
# ============================================================
set -e

REPO_PATH="/home/gns3/PFE-IoT-Security-TT"
DOCKER_DIR="$REPO_PATH/infrastructure/docker"
CERTS_DIR="$DOCKER_DIR/wazuh-certs"

echo "============================================="
echo " PFE IoT — Déploiement Wazuh SIEM (GNS3 VM)"
echo "============================================="

# ----------------------------------------------------------
# 1. Récupérer les derniers fichiers depuis GitHub
# ----------------------------------------------------------
echo ""
echo "[1/5] Git pull..."
cd "$REPO_PATH"

# ----------------------------------------------------------
# 2. vm.max_map_count (obligatoire pour OpenSearch)
# ----------------------------------------------------------
echo ""
echo "[2/5] Configuration kernel (vm.max_map_count)..."
sudo sysctl -w vm.max_map_count=262144

# Rendre permanent au reboot
if ! grep -q "vm.max_map_count" /etc/sysctl.conf 2>/dev/null; then
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
    echo "     -> Ajouté dans /etc/sysctl.conf (persistant)"
fi

# ----------------------------------------------------------
# 3. Régénérer les certificats Wazuh (ne sont pas dans git)
# ----------------------------------------------------------
echo ""
echo "[3/5] Génération des certificats Wazuh internes..."
cd "$DOCKER_DIR"

# Nettoyer les anciens certs s'ils existent
rm -f "$CERTS_DIR"/*.pem "$CERTS_DIR"/*.key 2>/dev/null || true

docker run --rm \
    -v "${CERTS_DIR}:/certificates" \
    -v "${CERTS_DIR}/config.yml:/config/certs.yml" \
    wazuh/wazuh-certs-generator:0.0.2 \
    /entrypoint.sh

echo "     -> Certificats générés dans $CERTS_DIR"
ls -la "$CERTS_DIR"/*.pem 2>/dev/null | awk '{print "        " $NF}'

# ----------------------------------------------------------
# 4. Vérifier que tous les fichiers de config sont présents
# ----------------------------------------------------------
echo ""
echo "[4/5] Vérification des fichiers de configuration..."

REQUIRED_FILES=(
    "wazuh-config/wazuh_manager.conf"
    "wazuh-config/wazuh.indexer.yml"
    "wazuh-config/internal_users.yml"
    "wazuh-config/opensearch_dashboards.yml"
    "wazuh-config/rules/local_rules.xml"
    "wazuh-certs/root-ca.pem"
    "wazuh-certs/wazuh.indexer.pem"
    "wazuh-certs/wazuh.indexer-key.pem"
    "wazuh-certs/wazuh.dashboard.pem"
    "wazuh-certs/wazuh.dashboard-key.pem"
    "wazuh-certs/admin.pem"
    "wazuh-certs/admin-key.pem"
)

ALL_OK=true
for f in "${REQUIRED_FILES[@]}"; do
    if [ -f "$DOCKER_DIR/$f" ]; then
        echo "     [✓] $f"
    else
        echo "     [✗] MANQUANT : $f"
        ALL_OK=false
    fi
done

if [ "$ALL_OK" = false ]; then
    echo ""
    echo "ERREUR : Des fichiers sont manquants. Arrêt."
    exit 1
fi

# ----------------------------------------------------------
# 5. Démarrer la stack Wazuh
# ----------------------------------------------------------
echo ""
echo "[5/5] Démarrage de la stack Wazuh..."
cd "$DOCKER_DIR"

docker compose -f docker-compose.wazuh.yml pull
docker compose -f docker-compose.wazuh.yml up -d

echo ""
echo "============================================="
echo " Stack Wazuh démarrée !"
echo "============================================="
echo ""
echo " Dashboard : https://$(hostname -I | awk '{print $1}'):443"
echo " Login     : admin / SecretPassword1!"
echo ""
echo " Suivre les logs :"
echo "   docker compose -f $DOCKER_DIR/docker-compose.wazuh.yml logs -f wazuh.manager"
echo ""
echo " Vérifier l'état :"
echo "   docker compose -f $DOCKER_DIR/docker-compose.wazuh.yml ps"
