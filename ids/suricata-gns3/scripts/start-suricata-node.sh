#!/bin/sh
# =====================================================
# Suricata IDS — GNS3 node launcher
# Zone Analyse (VLAN 50) — 192.168.50.10
# Configure le réseau puis lance Suricata sur l'interface miroir
# PFE IoT Security TT
# =====================================================
set -eu

SURICATA_IFACE="${SURICATA_IFACE:-eth0}"
NODE_IP_CIDR="${NODE_IP_CIDR:-192.168.50.10/24}"
NODE_GATEWAY="${NODE_GATEWAY:-192.168.50.1}"
NETWORK_AUTO_CONFIG="${NETWORK_AUTO_CONFIG:-1}"
IFACE_WAIT_SECONDS="${IFACE_WAIT_SECONDS:-10}"
WAZUH_HOST="${WAZUH_HOST:-192.168.40.10}"

banner() {
  echo "============================================================"
  echo " Suricata IDS — PFE IoT Security TT"
  echo " Zone Analyse (VLAN 50)"
  echo " Interface miroir : ${SURICATA_IFACE}"
  echo " IP statique      : ${NODE_IP_CIDR}"
  echo " Certificat       : ml.iot-pfe.local (réutilisé du ml-engine)"
  echo "============================================================"
}

wait_for_interface() {
  attempt=1
  while [ "$attempt" -le "$IFACE_WAIT_SECONDS" ]; do
    if ip link show dev "$SURICATA_IFACE" >/dev/null 2>&1; then
      return 0
    fi
    echo "[net] Attente de l'interface ${SURICATA_IFACE} (${attempt}/${IFACE_WAIT_SECONDS})"
    sleep 1
    attempt=$((attempt + 1))
  done
  echo "[net] Interface ${SURICATA_IFACE} introuvable"
  return 1
}

configure_network() {
  wait_for_interface

  if [ "$NETWORK_AUTO_CONFIG" = "1" ]; then
    echo "[net] Application de la configuration IPv4 statique"
    ip addr flush dev "$SURICATA_IFACE" || true
    ip addr add "$NODE_IP_CIDR" dev "$SURICATA_IFACE"
    ip link set "$SURICATA_IFACE" up
    ip route replace default via "$NODE_GATEWAY" || true
  else
    echo "[net] NETWORK_AUTO_CONFIG=0, conservation de la config IP existante"
    ip link set "$SURICATA_IFACE" up
  fi

  # Mode promiscuous : indispensable pour recevoir le trafic miroir (port mirroring)
  echo "[net] Activation du mode promiscuous sur ${SURICATA_IFACE}"
  ip link set "$SURICATA_IFACE" promisc on || true

  echo "[net] État IPv4 :"
  ip -4 addr show dev "$SURICATA_IFACE" || true
}

check_certs() {
  echo "[pki] Vérification du certificat (identité du nœud) :"
  if [ -f /etc/suricata/certs/client.crt ]; then
    openssl x509 -in /etc/suricata/certs/client.crt -noout -subject 2>/dev/null \
      | sed 's/^/[pki] /' || echo "[pki] (openssl indisponible)"
  else
    echo "[pki] Aucun certificat client monté"
  fi
}

validate_config() {
  echo "[cfg] Test de la configuration et des règles..."
  if suricata -T -c /etc/suricata/suricata.yaml -v 2>&1 | tail -15; then
    echo "[cfg] Configuration valide."
  else
    echo "[cfg] ERREUR de configuration — voir ci-dessus."
    exit 1
  fi
}

banner
configure_network
check_certs
validate_config

echo ""
echo "[run] Démarrage de Suricata sur ${SURICATA_IFACE}"
echo "[run] Alertes -> /var/log/suricata/eve.json (ingéré par Wazuh ${WAZUH_HOST})"
echo "------------------------------------------------------------"

# Lancement en avant-plan (logs visibles dans la console GNS3)
exec suricata -c /etc/suricata/suricata.yaml -i "$SURICATA_IFACE" --set logging.outputs.0.console.enabled=yes
