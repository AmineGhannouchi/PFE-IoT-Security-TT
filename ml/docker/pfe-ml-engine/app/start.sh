#!/bin/sh
# =====================================================
# start.sh — ML Engine (Zone Analyse : 192.168.50.12)
# PFE IoT Security TT
# =====================================================

echo "[start.sh] ============================================"
echo "[start.sh] Démarrage pfe-ml-engine (Analyse: 192.168.50.12)"
echo "[start.sh] ============================================"

# Configuration IP — Zone Analyse
ip addr add 192.168.50.12/24 dev eth0 2>/dev/null || true
ip route add default via 192.168.50.1 2>/dev/null || true
echo "[start.sh] IP configurée : 192.168.50.12/24 — GW 192.168.50.1"

# Démarrer le moteur ML
exec python /app/ml_engine.py
