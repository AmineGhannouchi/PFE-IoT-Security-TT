# collect-resources.ps1 - Copies figures into documentation/rapport/figures/
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$FiguresDir = Join-Path $PSScriptRoot "figures"

Write-Host "=== Collecting LaTeX report resources ===" -ForegroundColor Cyan
Write-Host "Destination: $FiguresDir" -ForegroundColor Yellow

if (-not (Test-Path $FiguresDir)) {
    New-Item -ItemType Directory -Path $FiguresDir -Force | Out-Null
}

$MLSource = Join-Path $RepoRoot "results\analysis\ml"
$MLFigures = @(
    "eda_classes_distribution.png","eda_correlation_heatmap.png","eda_boxplots_by_attack.png",
    "iso_forest_confusion_matrix.png","iso_forest_scores_distribution.png",
    "rf_confusion_roc.png","rf_feature_importance.png","rf_multiclass_confusion.png","models_comparison.png"
)
Write-Host "`n--- ML Figures ---" -ForegroundColor Magenta
foreach ($fig in $MLFigures) {
    $src = Join-Path $MLSource $fig
    $dst = Join-Path $FiguresDir $fig
    if (Test-Path $src) { Copy-Item $src $dst -Force; Write-Host "  [+] $fig" -ForegroundColor Green }
    else { Write-Host "  [!] MISSING: $fig" -ForegroundColor Red }
}

$PerfSource = Join-Path $RepoRoot "results\analysis\performance"
$PerfFigures = @(
    "perf_connection_latency.png","perf_rtt_messages.png","perf_throughput.png",
    "perf_protocols_comparison.png","perf_tls_handshake.png"
)
Write-Host "`n--- Performance Figures ---" -ForegroundColor Magenta
foreach ($fig in $PerfFigures) {
    $src = Join-Path $PerfSource $fig
    $dst = Join-Path $FiguresDir $fig
    if (Test-Path $src) { Copy-Item $src $dst -Force; Write-Host "  [+] $fig" -ForegroundColor Green }
    else { Write-Host "  [!] MISSING: $fig" -ForegroundColor Red }
}

$ManualFigures = @(
    @{Name="logo-fst.png"; Hint="Download from fst.utm.tn"},
    @{Name="logo-tt.png"; Hint="Download from tunisietelecom.tn"},
    @{Name="architecture-generale.png"; Hint="Compile PlantUML 01-architecture-generale.puml"},
    @{Name="gns3-topology.png"; Hint="Screenshot from GNS3 topology view"},
    @{Name="vault-pki-hierarchy.png"; Hint="PlantUML or draw.io diagram of PKI hierarchy"},
    @{Name="wazuh-dashboard.png"; Hint="Screenshot from https://192.168.30.128"},
    @{Name="suricata-alerts.png"; Hint="Screenshot from Wazuh, filter: rule.groups: suricata"}
)
Write-Host "`n--- Manual Figures (provide these yourself) ---" -ForegroundColor Yellow
foreach ($fig in $ManualFigures) {
    $dst = Join-Path $FiguresDir $fig.Name
    if (Test-Path $dst) { Write-Host "  [+] $($fig.Name) - already present" -ForegroundColor Green }
    else { Write-Host "  [!] MISSING: $($fig.Name) -> $($fig.Hint)" -ForegroundColor Red }
}

$AllFigures = $MLFigures + $PerfFigures + ($ManualFigures | ForEach-Object { $_.Name })
$PresentCount = ($AllFigures | Where-Object { Test-Path (Join-Path $FiguresDir $_) }).Count
Write-Host "`n=== Done: $PresentCount / $($AllFigures.Count) figures present ===" -ForegroundColor Cyan
