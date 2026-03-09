#!/bin/bash
# =============================================================
# Script d'initialisation du projet PFE IoT Security
# Auteur : Amine Ghannouchi
# Date   : 2026-03-09
# =============================================================

set -e

echo "🚀 Initialisation du projet PFE-IoT-Security-TT..."

# Créer la structure complète de dossiers
DIRS=(
  "architecture/diagrams"
  "architecture/plantuml"
  "architecture/topology"
  "infrastructure/docker"
  "infrastructure/ansible"
  "infrastructure/vm"
  "pki/vault"
  "pki/certificates"
  "pki/scripts"
  "iot/devices"
  "iot/gateway"
  "iot/broker"
  "security/suricata"
  "security/zeek"
  "security/tls"
  "siem/wazuh"
  "siem/opensearch"
  "datasets"
  "ml/notebooks"
  "ml/models"
  "tests/performance"
  "tests/attacks"
  "tests/scenarios"
  "scripts"
  "results"
  "documentation/rapport"
  "documentation/annexes"
  "journal"
)

for dir in "${DIRS[@]}"; do
  mkdir -p "$dir"
  touch "$dir/.gitkeep"
  echo "✅ Créé : $dir"
done

echo ""
echo "✅ Structure du projet initialisée avec succès !"
echo "📁 Dossiers créés : ${#DIRS[@]}"
