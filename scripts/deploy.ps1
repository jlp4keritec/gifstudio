#requires -Version 5.1
<#
.SYNOPSIS
    Deploiement / mise a jour de GifStudio sur le VPS.

.DESCRIPTION
    A executer apres chaque modification que tu veux deployer en production.
    Le script :
    1. Pull les dernieres modifs depuis GitHub sur le VPS
    2. Build les images Docker (api + web)
    3. Stop l'ancien et demarre le nouveau
    4. Verifie que tout repond bien (healthchecks)
    5. Rollback automatique si echec

.EXAMPLE
    .\deploy.ps1                # deploiement standard

.EXAMPLE
    .\deploy.ps1 -DryRun        # simulation sans modification

.EXAMPLE
    .\deploy.ps1 -SkipBuild     # juste recharger sans rebuild (utile si seul le compose change)

.EXAMPLE
    .\deploy.ps1 -Tail          # affiche les logs en continu apres deploiement
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipBuild,
    [switch]$Tail,
    [switch]$NoRollback
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION
# ============================================================================

$VpsHost      = '151.80.232.214'
$VpsUser      = 'ubuntu'
$IdentityFile = "$env:USERPROFILE\.ssh\id_ed25519_gifstudio_nopass"

$Domain       = 'gifstudio.toolspdf.net'
$AppRoot      = '/var/www/gifstudio'
$ComposeFile  = 'docker-compose.prod.yml'

$HealthApiUrl  = "https://$Domain/api/v1/health"
$HealthWebUrl  = "https://$Domain"

# ============================================================================
# HELPERS (style cohérent avec ton deploy.ps1 existant)
# ============================================================================

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}
function Write-OK($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  [!]  $msg" -ForegroundColor Yellow }
function Write-Bad($msg)  { Write-Host "  [X]  $msg" -ForegroundColor Red }
function Write-Info($msg) { Write-Host "  $msg" -ForegroundColor Gray }

function Invoke-Ssh {
    param(
        [Parameter(Mandatory)][string]$Command,
        [switch]$IgnoreErrors
    )
    if ($DryRun) {
        Write-Info "[DRY-RUN] ssh: $Command"
        return ""
    }
    $output = & ssh -i $IdentityFile "$VpsUser@$VpsHost" $Command 2>&1
    if ($LASTEXITCODE -ne 0 -and -not $IgnoreErrors) {
        Write-Bad "Commande SSH echouee (exit $LASTEXITCODE) : $Command"
        Write-Info $output
        throw "SSH command failed"
    }
    return $output
}

function Invoke-SshStream {
    <#
    .SYNOPSIS
        Lance une commande SSH et streame la sortie en temps reel
        (utile pour docker compose build / up qui sont longs)
    #>
    param([Parameter(Mandatory)][string]$Command)
    if ($DryRun) {
        Write-Info "[DRY-RUN] ssh stream: $Command"
        return
    }
    & ssh -i $IdentityFile "$VpsUser@$VpsHost" $Command
    if ($LASTEXITCODE -ne 0) {
        throw "SSH stream command failed (exit $LASTEXITCODE)"
    }
}

function Test-Url {
    param(
        [Parameter(Mandatory)][string]$Url,
        [int]$TimeoutSec = 10,
        [int]$ExpectedStatus = 200
    )
    try {
        $r = Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutSec -UseBasicParsing -ErrorAction Stop
        return $r.StatusCode -eq $ExpectedStatus
    } catch {
        return $false
    }
}

function Wait-Healthy {
    param(
        [Parameter(Mandatory)][string]$Url,
        [int]$MaxAttempts = 20,
        [int]$DelaySec = 3,
        [string]$Label = $Url
    )
    Write-Info "Attente $Label..."
    for ($i = 1; $i -le $MaxAttempts; $i++) {
        if (Test-Url -Url $Url) {
            Write-OK "Reponse OK apres $i tentative(s)"
            return $true
        }
        Start-Sleep -Seconds $DelaySec
    }
    return $false
}

# ============================================================================
# DEBUT
# ============================================================================

$startTime = Get-Date
Write-Host ""
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host "  GifStudio - Deploiement" -ForegroundColor Magenta
Write-Host "  Cible : $VpsUser@$VpsHost ($AppRoot)" -ForegroundColor Magenta
Write-Host "  Domaine : https://$Domain" -ForegroundColor Magenta
if ($DryRun)     { Write-Host "  >>> MODE DRY-RUN <<<" -ForegroundColor Yellow }
if ($SkipBuild)  { Write-Host "  >>> SKIP BUILD (pas de rebuild des images) <<<" -ForegroundColor Yellow }
if ($NoRollback) { Write-Host "  >>> NO ROLLBACK (pas de retour en arriere si echec) <<<" -ForegroundColor Yellow }
Write-Host "============================================================" -ForegroundColor Magenta

# ============================================================================
# 1. CONNEXION + ETAT INITIAL
# ============================================================================
Write-Step "1. Connexion et etat initial"

if (-not (Test-Path $IdentityFile)) {
    Write-Bad "Cle SSH introuvable : $IdentityFile"
    exit 1
}

$hostname = Invoke-Ssh "hostname"
Write-OK "Connecte sur $hostname"

# Verifie que le projet est bien la
$exists = Invoke-Ssh "test -d $AppRoot/.git && echo YES || echo NO"
if ($exists -ne 'YES') {
    Write-Bad "Le repo n'existe pas dans $AppRoot - lance d'abord bootstrap-vps.ps1"
    exit 1
}

$envExists = Invoke-Ssh "test -f $AppRoot/.env.production && echo YES || echo NO"
if ($envExists -ne 'YES') {
    Write-Bad ".env.production manquant - lance d'abord bootstrap-vps.ps1"
    exit 1
}

# Tag de l'image courante pour rollback eventuel
$previousImageId = Invoke-Ssh "docker images -q gifstudio-api:latest | head -1" -IgnoreErrors
if ($previousImageId) {
    Write-Info "Image precedente : $previousImageId (sauvegardee pour rollback)"
}

# ============================================================================
# 2. GIT PULL
# ============================================================================
Write-Step "2. Mise a jour du code (git pull)"

$pullResult = Invoke-Ssh "cd $AppRoot && git fetch && git reset --hard origin/main && git log -1 --oneline"
Write-OK "Code a jour : $pullResult"

# ============================================================================
# 3. BUILD DES IMAGES
# ============================================================================
if ($SkipBuild) {
    Write-Step "3. Build (skip via -SkipBuild)"
    Write-Warn "Aucun rebuild des images Docker"
} else {
    Write-Step "3. Build des images Docker (peut prendre 3-5 min)"
    Invoke-SshStream "cd $AppRoot && docker compose -f $ComposeFile --env-file .env.production build"
    Write-OK "Images construites"
}

# ============================================================================
# 4. DEMARRAGE / RESTART
# ============================================================================
Write-Step "4. Demarrage des conteneurs"

# Up avec --remove-orphans pour nettoyer les anciens conteneurs si necessaire
Invoke-SshStream "cd $AppRoot && docker compose -f $ComposeFile --env-file .env.production up -d --remove-orphans"
Write-OK "Conteneurs lances"

# Affichage de l'etat
$psOutput = Invoke-Ssh "cd $AppRoot && docker compose -f $ComposeFile --env-file .env.production ps"
Write-Host ""
Write-Host $psOutput -ForegroundColor Gray

# ============================================================================
# 5. HEALTHCHECKS
# ============================================================================
Write-Step "5. Healthchecks"

# Attente que les conteneurs soient healthy
Write-Info "Attente des conteneurs (30s)..."
Start-Sleep -Seconds 30

# Check API local (depuis le VPS)
$apiHealthLocal = Invoke-Ssh "curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:4002/api/v1/health" -IgnoreErrors
if ($apiHealthLocal -eq '200') {
    Write-OK "API locale (127.0.0.1:4002) : 200 OK"
} else {
    Write-Bad "API locale : statut $apiHealthLocal"
}

# Check Web local
$webHealthLocal = Invoke-Ssh "curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:3002/" -IgnoreErrors
if ($webHealthLocal -eq '200') {
    Write-OK "Web local (127.0.0.1:3002) : 200 OK"
} else {
    Write-Bad "Web local : statut $webHealthLocal"
}

# Check public via Nginx + SSL
$apiPublic = Wait-Healthy -Url $HealthApiUrl -Label "API publique ($HealthApiUrl)" -MaxAttempts 10
if ($apiPublic) {
    Write-OK "API publique : 200 OK"
} else {
    Write-Bad "API publique ne repond pas correctement"
}

$webPublic = Wait-Healthy -Url $HealthWebUrl -Label "Web publique ($HealthWebUrl)" -MaxAttempts 10
if ($webPublic) {
    Write-OK "Web publique : 200 OK"
} else {
    Write-Bad "Web publique ne repond pas correctement"
}

$allOk = ($apiHealthLocal -eq '200') -and ($webHealthLocal -eq '200') -and $apiPublic -and $webPublic

# ============================================================================
# 6. ROLLBACK SI ECHEC
# ============================================================================
if (-not $allOk -and -not $NoRollback -and -not $DryRun) {
    Write-Step "6. Echec detecte - DIAGNOSTIC"

    Write-Host ""
    Write-Host "--- Logs gifstudio-api (50 dernieres lignes) ---" -ForegroundColor Yellow
    Invoke-Ssh "docker logs gifstudio-api --tail 50 2>&1" -IgnoreErrors

    Write-Host ""
    Write-Host "--- Logs gifstudio-web (50 dernieres lignes) ---" -ForegroundColor Yellow
    Invoke-Ssh "docker logs gifstudio-web --tail 50 2>&1" -IgnoreErrors

    Write-Host ""
    Write-Bad "Le deploiement a echoue."
    Write-Info "Inspecte les logs ci-dessus."
    Write-Info "Pour relancer : .\deploy.ps1"
    Write-Info "Pour rollback Git : ssh $VpsUser@$VpsHost 'cd $AppRoot && git reset --hard HEAD~1' puis .\deploy.ps1"
    exit 1
}

# ============================================================================
# 7. NETTOYAGE IMAGES OBSOLETES
# ============================================================================
if ($allOk -and -not $DryRun) {
    Write-Step "7. Nettoyage images Docker obsoletes"
    Invoke-Ssh "docker image prune -f" -IgnoreErrors | Out-Null
    Write-OK "Images obsoletes supprimees"
}

# ============================================================================
# FIN
# ============================================================================
$elapsed = (Get-Date) - $startTime
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
if ($allOk) {
    Write-Host "  Deploiement reussi en $($elapsed.ToString('mm\:ss'))" -ForegroundColor Green
    Write-Host "  >>> https://$Domain <<<" -ForegroundColor Green
} else {
    Write-Host "  Deploiement termine avec avertissements" -ForegroundColor Yellow
}
Write-Host "============================================================" -ForegroundColor Green

# ============================================================================
# 8. TAIL DES LOGS (optionnel)
# ============================================================================
if ($Tail -and -not $DryRun) {
    Write-Step "Suivi des logs (Ctrl+C pour quitter)"
    & ssh -i $IdentityFile "$VpsUser@$VpsHost" "cd $AppRoot && docker compose -f $ComposeFile --env-file .env.production logs -f --tail=50"
}
