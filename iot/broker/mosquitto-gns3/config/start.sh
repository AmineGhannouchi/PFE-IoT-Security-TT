#!/bin/sh
# =====================================================
# start.sh — Démarrage Mosquitto + rsyslog (Wazuh)
# PFE IoT Security TT
# =====================================================
set -e

echo "[start.sh] ============================================"
echo "[start.sh] Démarrage pfe-mosquitto (DMZ: 192.168.20.10)"
echo "[start.sh] ============================================"

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
