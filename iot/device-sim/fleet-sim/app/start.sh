#!/bin/sh
# =====================================================
# start.sh — Fleet Simulator (Zone IoT : 192.168.10.10)
# PFE IoT Security TT
# =====================================================

echo "[start.sh] ============================================"
echo "[start.sh] Démarrage pfe-fleet-sim (IoT: 192.168.10.10)"
echo "[start.sh] ============================================"

# Configuration IP — Zone IoT
ip addr add 192.168.10.10/24 dev eth0 2>/dev/null || true
ip route add default via 192.168.10.1 2>/dev/null || true
echo "[start.sh] IP configurée : 192.168.10.10/24 — GW 192.168.10.1"

# Lancer le simulateur
exec python /app/fleet_sim.py --csv /app/dataset/iot_communication_security_dataset_sample.csv
