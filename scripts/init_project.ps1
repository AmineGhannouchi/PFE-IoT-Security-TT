# =============================================================
# Script d'initialisation du projet PFE IoT Security (Windows)
# Auteur : Amine Ghannouchi
# Date   : 2026-03-09
# =============================================================

Write-Host "🚀 Initialisation du projet PFE-IoT-Security-TT..." -ForegroundColor Cyan

$dirs = @(
    "architecture/diagrams",
    "architecture/plantuml",
    "architecture/topology",
    "infrastructure/docker",
    "infrastructure/ansible",
    "infrastructure/vm",
    "pki/vault",
    "pki/certificates",
    "pki/scripts",
    "iot/devices",
    "iot/gateway",
    "iot/broker",
    "security/suricata",
    "security/zeek",
    "security/tls",
    "siem/wazuh",
    "siem/opensearch",
    "datasets",
    "ml/notebooks",
    "ml/models",
    "tests/performance",
    "tests/attacks",
    "tests/scenarios",
    "scripts",
    "results",
    "documentation/rapport",
    "documentation/annexes",
    "journal"
)

foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    New-Item -ItemType File -Path "$dir/.gitkeep" -Force | Out-Null
    Write-Host "✅ Créé : $dir" -ForegroundColor Green
}

Write-Host ""
Write-Host "✅ Structure initialisée ! $($dirs.Count) dossiers créés." -ForegroundColor Cyan
