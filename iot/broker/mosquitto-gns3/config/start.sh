#!/bin/sh
# =====================================================
# start.sh — Démarrage Mosquitto + rsyslog (Wazuh)
# PFE IoT Security TT
# =====================================================
set -e

echo "[start.sh] ============================================"
echo "[start.sh] Démarrage pfe-mosquitto (DMZ: 192.168.20.10)"
echo "[start.sh] ============================================"

# Configuration IP — Zone DMZ
ip addr flush dev eth0 2>/dev/null || true
ip addr add 192.168.20.10/24 dev eth0 2>/dev/null || true
ip link set eth0 up 2>/dev/null || true
ip route add default via 192.168.20.1 2>/dev/null || true
echo "[start.sh] IP configurée : 192.168.20.10/24 — GW 192.168.20.1"

# Créer les répertoires nécessaires
mkdir -p /mosquitto/log /mosquitto/data /var/spool/rsyslog

# Corriger les permissions
chown -R mosquitto:mosquitto /mosquitto/log /mosquitto/data 2>/dev/null || true

# Démarrer rsyslog en arrière-plan
rsyslogd
sleep 1
echo "[start.sh] rsyslog OK — Forwarding logs vers Wazuh 192.168.40.10:514"

# Démarrer Mosquitto en premier plan (processus principal du container)
echo "[start.sh] Démarrage Mosquitto sur port 8883 (mTLS/TLS1.3)..."
exec /usr/sbin/mosquitto -c /mosquitto/config/mosquitto.conf
