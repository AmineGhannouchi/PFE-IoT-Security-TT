param(
    [switch]$Clean,
    [switch]$Quick,
    [switch]$NoDiagrams
)

$ErrorActionPreference = 'Continue'
$rapport2 = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path "$rapport2\..\.."

Write-Host '================================================' -ForegroundColor Cyan
Write-Host '  Compilation rapport2 -- PFE IoT Security TT'    -ForegroundColor Cyan
Write-Host '================================================' -ForegroundColor Cyan
Write-Host "Repertoire : $rapport2"
Write-Host ''

# -- Nettoyage --
if ($Clean) {
    Write-Host '[CLEAN] Suppression des fichiers auxiliaires...' -ForegroundColor Yellow
    $extensions = @('*.aux','*.bbl','*.bcf','*.blg','*.fdb_latexmk',
                    '*.fls','*.log','*.out','*.run.xml','*.synctex.gz',
                    '*.toc','*.lof','*.lot','*.nav','*.snm','*.vrb')
    foreach ($ext in $extensions) {
        Get-ChildItem -Path $rapport2 -Filter $ext -ErrorAction SilentlyContinue |
            Remove-Item -Force
    }
    Write-Host '[CLEAN] Done.' -ForegroundColor Green
}

# -- Etape 1 : PlantUML --
if (-not $NoDiagrams) {
    $plantumlJar = Join-Path $projectRoot 'plantuml.jar'
    $diagramsDir = Join-Path $rapport2 'diagrams'

    if (-not (Test-Path $plantumlJar)) {
        Write-Host '[WARN] plantuml.jar introuvable a la racine du projet.' -ForegroundColor Yellow
        Write-Host '       Telecharger depuis https://plantuml.com/download' -ForegroundColor Yellow
    } else {
        $pumlFiles = Get-ChildItem -Path $diagramsDir -Filter '*.puml' -ErrorAction SilentlyContinue
        if ($pumlFiles.Count -gt 0) {
            Write-Host "[PLANTUML] Generation de $($pumlFiles.Count) diagrammes..." -ForegroundColor Cyan

            $javaFound = $null -ne (Get-Command 'java' -ErrorAction SilentlyContinue)
            if (-not $javaFound) {
                Write-Host '[ERREUR] Java non trouve. Installer JDK/JRE pour PlantUML.' -ForegroundColor Red
                exit 1
            }

            $errors = 0
            foreach ($puml in $pumlFiles) {
                Write-Host "  $($puml.Name)..." -ForegroundColor Gray
                java -jar $plantumlJar -tpng -o $diagramsDir $puml.FullName 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { $errors++ }
            }
            $pngCount = (Get-ChildItem -Path $diagramsDir -Filter '*.png' -ErrorAction SilentlyContinue).Count
            if ($errors -eq 0) {
                Write-Host "[PLANTUML] $pngCount diagrammes generes." -ForegroundColor Green
            } else {
                Write-Host "[PLANTUML] $errors erreur(s). $pngCount PNG generes." -ForegroundColor Yellow
            }
        } else {
            Write-Host '[PLANTUML] Aucun fichier .puml trouve.' -ForegroundColor Yellow
        }
    }
    Write-Host ''
}

# -- Etape 2 : Copier les figures depuis rapport1 --
$figSrc = Join-Path $projectRoot 'documentation\rapport\figures'
$figDst = Join-Path $rapport2 'figures'

if (Test-Path $figSrc) {
    if (-not (Test-Path $figDst)) {
        New-Item -ItemType Directory -Path $figDst -Force | Out-Null
    }

    $figures = Get-ChildItem -Path $figSrc -Filter '*.png' -ErrorAction SilentlyContinue
    if ($figures.Count -gt 0) {
        Write-Host "[FIGURES] Copie de $($figures.Count) figures depuis rapport1..." -ForegroundColor Cyan
        foreach ($fig in $figures) {
            Copy-Item -Path $fig.FullName -Destination $figDst -Force
        }
        Write-Host "[FIGURES] $($figures.Count) figures copiees." -ForegroundColor Green
    }
} else {
    Write-Host "[WARN] Repertoire figures rapport1 introuvable: $figSrc" -ForegroundColor Yellow
}
Write-Host ''

# -- Etape 3 : Compilation LaTeX --
Push-Location $rapport2

$texFile = 'rapport.tex'
if (-not (Test-Path $texFile)) {
    Write-Host "[ERREUR] $texFile introuvable dans $rapport2" -ForegroundColor Red
    Pop-Location
    exit 1
}

$usePerl = $null -ne (Get-Command 'perl' -ErrorAction SilentlyContinue)
$useLatexmk = $usePerl -and ($null -ne (Get-Command 'latexmk' -ErrorAction SilentlyContinue))
$usePdflatex = $null -ne (Get-Command 'pdflatex' -ErrorAction SilentlyContinue)
$useBiber = $null -ne (Get-Command 'biber' -ErrorAction SilentlyContinue)

if ($useLatexmk -and -not $Quick) {
    Write-Host '[LATEX] Compilation avec latexmk...' -ForegroundColor Cyan
    & latexmk -pdf -interaction=nonstopmode -shell-escape $texFile
} elseif ($usePdflatex) {
    if ($Quick) {
        Write-Host '[LATEX] Compilation rapide (1 passe)...' -ForegroundColor Cyan
        & pdflatex -interaction=nonstopmode -shell-escape $texFile
    } else {
        Write-Host '[LATEX] Compilation complete (4 passes)...' -ForegroundColor Cyan

        Write-Host '  Passe 1/4 : pdflatex...' -ForegroundColor Gray
        & pdflatex -interaction=nonstopmode -shell-escape $texFile | Out-Null

        if ($useBiber) {
            Write-Host '  Passe 2/4 : biber...' -ForegroundColor Gray
            & biber 'rapport' 2>&1 | Out-Null
        } else {
            Write-Host '  [WARN] biber non trouve -- bibliographie non generee' -ForegroundColor Yellow
        }

        Write-Host '  Passe 3/4 : pdflatex...' -ForegroundColor Gray
        & pdflatex -interaction=nonstopmode -shell-escape $texFile | Out-Null

        Write-Host '  Passe 4/4 : pdflatex...' -ForegroundColor Gray
        & pdflatex -interaction=nonstopmode -shell-escape $texFile | Out-Null
    }
} else {
    Write-Host '[ERREUR] Ni latexmk ni pdflatex trouves. Installer TeX Live ou MiKTeX.' -ForegroundColor Red
    Pop-Location
    exit 1
}

# -- Verification du resultat --
$pdfFile = 'rapport.pdf'
if (Test-Path $pdfFile) {
    $pdfSize = [math]::Round((Get-Item $pdfFile).Length / 1MB, 2)
    Write-Host ''
    Write-Host '================================================' -ForegroundColor Green
    Write-Host '  Compilation reussie' -ForegroundColor Green
    Write-Host "  PDF : $pdfFile [$pdfSize Mo]" -ForegroundColor Green
    Write-Host '================================================' -ForegroundColor Green
    Write-Host 'Ouverture du PDF...' -ForegroundColor Gray
    Start-Process $pdfFile
} else {
    Write-Host ''
    Write-Host '================================================' -ForegroundColor Red
    Write-Host '  ECHEC de la compilation' -ForegroundColor Red
    Write-Host '  Verifier le fichier rapport.log pour les erreurs.' -ForegroundColor Red
    Write-Host '================================================' -ForegroundColor Red

    if (Test-Path 'rapport.log') {
        Write-Host ''
        Write-Host 'Dernieres erreurs du log :' -ForegroundColor Yellow
        Get-Content 'rapport.log' | Select-String '^!' | Select-Object -Last 10
    }
}

Pop-Location
