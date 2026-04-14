# compile.ps1 - Compiles the LaTeX PFE report to PDF
# Usage: .\compile.ps1 [-Clean] [-Quick]
param([switch]$Clean, [switch]$Quick)

$ErrorActionPreference = "Continue"
$RapportDir = $PSScriptRoot
$MainFile = "rapport"

Push-Location $RapportDir
Write-Host "=== LaTeX PFE Report Compilation ===" -ForegroundColor Cyan

$UseLatexmk = [bool](Get-Command "latexmk" -ErrorAction SilentlyContinue)
if (-not $UseLatexmk -and -not (Get-Command "pdflatex" -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Neither latexmk nor pdflatex found. Install MiKTeX or TeX Live." -ForegroundColor Red
    Pop-Location; exit 1
}
Write-Host "[+] LaTeX found (latexmk=$UseLatexmk)" -ForegroundColor Green

# Collect figures
$collect = Join-Path $RapportDir "collect-resources.ps1"
if (Test-Path $collect) { & $collect }

if ($Clean) {
    Write-Host "[*] Cleaning auxiliary files..." -ForegroundColor Cyan
    @("*.aux","*.log","*.bbl","*.bcf","*.blg","*.toc","*.lof","*.lot",
      "*.out","*.run.xml","*.fls","*.fdb_latexmk","*.synctex.gz") |
        ForEach-Object { Get-ChildItem $RapportDir -Filter $_ | Remove-Item -Force }
}

$start = Get-Date
Write-Host "[*] Compiling..." -ForegroundColor Cyan

if ($UseLatexmk -and -not $Quick) {
    & latexmk -pdf -pdflatex="pdflatex -interaction=nonstopmode -shell-escape %O %S" "$MainFile.tex"
} else {
    Write-Host "  Pass 1/4: pdflatex..." -ForegroundColor Gray
    & pdflatex -interaction=nonstopmode -shell-escape "$MainFile.tex" > $null
    Write-Host "  Pass 2/4: biber..." -ForegroundColor Gray
    & biber $MainFile > $null
    Write-Host "  Pass 3/4: pdflatex..." -ForegroundColor Gray
    & pdflatex -interaction=nonstopmode -shell-escape "$MainFile.tex" > $null
    Write-Host "  Pass 4/4: pdflatex (final)..." -ForegroundColor Gray
    & pdflatex -interaction=nonstopmode -shell-escape "$MainFile.tex" > $null
}

$elapsed = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
$pdf = Join-Path $RapportDir "$MainFile.pdf"

if (Test-Path $pdf) {
    $size = [math]::Round((Get-Item $pdf).Length / 1MB, 2)
    Write-Host "`n=== SUCCESS: $MainFile.pdf ($size MB) in $elapsed s ===" -ForegroundColor Green
    Start-Process $pdf
} else {
    Write-Host "`n=== FAILED after $elapsed s ===" -ForegroundColor Red
    Write-Host "Check $MainFile.log for errors:" -ForegroundColor Yellow
    $log = Join-Path $RapportDir "$MainFile.log"
    if (Test-Path $log) { Get-Content $log -Tail 30 }
}
Pop-Location
