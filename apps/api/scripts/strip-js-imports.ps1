# ============================================================================
# Script de migration : retire les ".js" des imports relatifs TypeScript
# Necessaire apres bascule de NodeNext vers CommonJS
# ============================================================================

param(
    [string]$Root = "C:\gifstudio\apps\api\src"
)

Write-Host "Recherche des fichiers TypeScript dans $Root..." -ForegroundColor Cyan

$files = Get-ChildItem -Path $Root -Recurse -Include *.ts -File
Write-Host "  $($files.Count) fichier(s) trouve(s)" -ForegroundColor Gray

$modified = 0
foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    if (-not $content) { continue }

    # Match les imports relatifs avec .js : from './...js' ou from '../...js'
    # Pattern : (from\s+['"])(\.[^'"]+)(\.js)(['"]) -> $1$2$4
    $newContent = $content -replace "(from\s+['""])(\.[^'""]+?)\.js(['""])", '$1$2$3'

    if ($newContent -ne $content) {
        Set-Content -Path $file.FullName -Value $newContent -NoNewline -Encoding UTF8
        $modified++
        Write-Host "  [FIX] $($file.Name)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Termine : $modified fichier(s) modifie(s)" -ForegroundColor Cyan
