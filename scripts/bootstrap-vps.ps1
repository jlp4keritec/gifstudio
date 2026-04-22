#requires -Version 5.1
<#
.SYNOPSIS
    Bootstrap initial du VPS pour GifStudio.

.DESCRIPTION
    À exécuter UNE SEULE FOIS pour préparer le VPS :
    - Vérifie les prérequis (Docker, Docker Compose, Nginx, Certbot)
    - Clone le repo GitHub dans /var/www/gifstudio
    - Crée les dossiers de storage
    - Génère un .env.production avec des secrets aléatoires
    - Vérifie que le DNS pointe bien sur le VPS
    - Installe Certbot si besoin et obtient un certificat SSL Let's Encrypt
    - Configure Nginx avec le reverse proxy

.EXAMPLE
    .\bootstrap-vps.ps1

.EXAMPLE
    .\bootstrap-vps.ps1 -DryRun

.EXAMPLE
    .\bootstrap-vps.ps1 -SkipSSL    # utile si DNS pas encore propagé
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipSSL,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION
# ============================================================================

$VpsHost          = '151.80.232.214'
$VpsUser          = 'ubuntu'
$IdentityFile     = "$env:USERPROFILE\.ssh\id_ed25519_gifstudio_nopass"

$Domain           = 'gifstudio.toolspdf.net'
$RepoUrl          = 'https://github.com/jlp4keritec/gifstudio.git'
$AppRoot          = '/var/www/gifstudio'
$StorageRoot      = "$AppRoot/storage"
$AdminEmail       = "admin@$Domain"
$LetsEncryptEmail = 'jlp@keritec.fr'   # ⚠️  ADAPTE avec ton email

# ============================================================================
# HELPERS (style cohérent avec ton deploy.ps1 existant)
# ============================================================================

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}
function Write-OK($msg) {
    Write-Host "  [OK] $msg" -ForegroundColor Green
}
function Write-Warn($msg) {
    Write-Host "  [!]  $msg" -ForegroundColor Yellow
}
function Write-Bad($msg) {
    Write-Host "  [X]  $msg" -ForegroundColor Red
}
function Write-Info($msg) {
    Write-Host "  $msg" -ForegroundColor Gray
}

function Invoke-Ssh {
    param(
        [Parameter(Mandatory)][string]$Command,
        [switch]$Sudo
    )

    $finalCmd = if ($Sudo) { "sudo bash -c `"$Command`"" } else { $Command }

    if ($DryRun) {
        Write-Info "[DRY-RUN] ssh: $finalCmd"
        return ""
    }

    $output = & ssh -i $IdentityFile -o StrictHostKeyChecking=accept-new "$VpsUser@$VpsHost" $finalCmd 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Bad "Commande SSH echouee : $Command"
        Write-Info $output
        throw "SSH command failed (exit $LASTEXITCODE)"
    }
    return $output
}

function Invoke-Scp {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Dest
    )
    if ($DryRun) {
        Write-Info "[DRY-RUN] scp: $Source -> $VpsUser@${VpsHost}:$Dest"
        return
    }
    & scp -i $IdentityFile $Source "${VpsUser}@${VpsHost}:$Dest"
    if ($LASTEXITCODE -ne 0) { throw "SCP failed" }
}

function New-RandomPassword {
    param([int]$Length = 32)
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789'
    $bytes = [byte[]]::new($Length)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $sb = [System.Text.StringBuilder]::new()
    foreach ($b in $bytes) { [void]$sb.Append($chars[$b % $chars.Length]) }
    return $sb.ToString()
}

# ============================================================================
# DEBUT
# ============================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host "  GifStudio - Bootstrap VPS" -ForegroundColor Magenta
Write-Host "  Cible : $VpsUser@$VpsHost" -ForegroundColor Magenta
Write-Host "  Domaine : $Domain" -ForegroundColor Magenta
if ($DryRun) {
    Write-Host "  >>> MODE DRY-RUN (aucune modification reelle) <<<" -ForegroundColor Yellow
}
Write-Host "============================================================" -ForegroundColor Magenta

# ============================================================================
# 1. CONNEXION SSH
# ============================================================================
Write-Step "1. Verification connexion SSH"

if (-not (Test-Path $IdentityFile)) {
    Write-Bad "Cle SSH introuvable : $IdentityFile"
    exit 1
}

$hostname = Invoke-Ssh "hostname && whoami"
Write-OK "Connecte : $hostname"

# ============================================================================
# 2. PREREQUIS LOGICIELS
# ============================================================================
Write-Step "2. Verification des prerequis sur le VPS"

# Docker
$dockerVersion = Invoke-Ssh "docker --version 2>/dev/null || echo MISSING"
if ($dockerVersion -match 'Docker version') {
    Write-OK "Docker : $dockerVersion"
} else {
    Write-Bad "Docker non installe"
    throw "Docker requis"
}

# Docker Compose v2 (plugin)
$composeVersion = Invoke-Ssh "docker compose version 2>/dev/null || echo MISSING"
if ($composeVersion -match 'version v?2\.' -or $composeVersion -match 'Docker Compose version') {
    Write-OK "Docker Compose : $composeVersion"
} else {
    Write-Warn "Docker Compose plugin manquant - tentative d'installation"
    Invoke-Ssh "DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-plugin" -Sudo
    Write-OK "Docker Compose installe"
}

# Nginx
$nginxStatus = Invoke-Ssh "systemctl is-active nginx 2>/dev/null || echo INACTIVE"
if ($nginxStatus -eq 'active') {
    Write-OK "Nginx : actif"
} else {
    Write-Bad "Nginx non actif"
    throw "Nginx requis (deja installe d'apres l'audit)"
}

# Git
$gitVersion = Invoke-Ssh "git --version 2>/dev/null || echo MISSING"
if ($gitVersion -match 'git version') {
    Write-OK "Git : $gitVersion"
} else {
    Write-Warn "Git manquant - installation..."
    Invoke-Ssh "DEBIAN_FRONTEND=noninteractive apt-get install -y git" -Sudo
    Write-OK "Git installe"
}

# ============================================================================
# 3. VERIFICATION DNS
# ============================================================================
Write-Step "3. Verification DNS du domaine $Domain"

$dnsResult = & nslookup $Domain 2>&1 | Out-String
if ($dnsResult -match $VpsHost) {
    Write-OK "DNS OK : $Domain pointe vers $VpsHost"
} else {
    Write-Warn "DNS pas encore propage ou mal configure"
    Write-Info "Configure une entree A chez ton registrar :"
    Write-Info "  $Domain  ->  $VpsHost"
    Write-Info ""
    Write-Info "Verifie aussi avec : nslookup $Domain"
    if (-not $Force -and -not $SkipSSL) {
        Write-Warn "Continue quand meme ? (Ctrl+C pour annuler, Entree pour continuer)"
        if (-not $DryRun) { [void](Read-Host) }
    }
}

# ============================================================================
# 4. CREATION ARBORESCENCE
# ============================================================================
Write-Step "4. Preparation des dossiers sur le VPS"

Invoke-Ssh "mkdir -p $AppRoot && chown ${VpsUser}:${VpsUser} $AppRoot" -Sudo
Write-OK "Dossier app cree : $AppRoot"

Invoke-Ssh "mkdir -p $StorageRoot/videos $StorageRoot/gifs $StorageRoot/thumbnails $StorageRoot/trash"
Write-OK "Storage cree : $StorageRoot/{videos,gifs,thumbnails,trash}"

# ============================================================================
# 5. CLONE DU REPO
# ============================================================================
Write-Step "5. Clonage du repo GitHub"

$repoExists = Invoke-Ssh "test -d $AppRoot/.git && echo YES || echo NO"
if ($repoExists -eq 'YES') {
    if ($Force) {
        Write-Warn "Repo existant detecte, suppression (mode -Force)"
        Invoke-Ssh "rm -rf $AppRoot/.git $AppRoot/apps $AppRoot/packages $AppRoot/*.json $AppRoot/*.yaml $AppRoot/*.yml 2>/dev/null || true"
        Invoke-Ssh "cd $AppRoot && git clone $RepoUrl ."
        Write-OK "Repo clone : $RepoUrl"
    } else {
        Write-OK "Repo deja present, pas de clone (utilise -Force pour reinitialiser)"
    }
} else {
    Invoke-Ssh "cd $AppRoot && git clone $RepoUrl ."
    Write-OK "Repo clone : $RepoUrl"
}

# ============================================================================
# 6. GENERATION .env.production
# ============================================================================
Write-Step "6. Generation du fichier .env.production"

$envExists = Invoke-Ssh "test -f $AppRoot/.env.production && echo YES || echo NO"
if ($envExists -eq 'YES' -and -not $Force) {
    Write-OK ".env.production existe deja, conserve (utilise -Force pour regenerer)"
} else {
    Write-Info "Generation des secrets aleatoires..."
    $postgresPassword = New-RandomPassword 24
    $jwtSecret        = New-RandomPassword 48
    $adminPassword    = New-RandomPassword 16

    $envContent = @"
# ============================================================================
# GifStudio - Configuration de production
# Genere automatiquement par bootstrap-vps.ps1 le $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# NE PAS COMMITER ce fichier
# ============================================================================

PUBLIC_URL=https://$Domain

POSTGRES_USER=gifstudio
POSTGRES_PASSWORD=$postgresPassword
POSTGRES_DB=gifstudio

JWT_SECRET=$jwtSecret

ADMIN_EMAIL=$AdminEmail
ADMIN_PASSWORD=$adminPassword
FORCE_PASSWORD_CHANGE=true

STORAGE_PATH=$StorageRoot
"@

    # Ecriture via heredoc SSH (evite les problemes de quoting)
    $tempFile = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tempFile -Value $envContent -NoNewline -Encoding UTF8
    Invoke-Scp -Source $tempFile -Dest "$AppRoot/.env.production"
    Remove-Item $tempFile -Force

    Invoke-Ssh "chmod 600 $AppRoot/.env.production"
    Write-OK ".env.production cree avec secrets aleatoires"
    Write-Host ""
    Write-Host "  >>> IMPORTANT - NOTE CES IDENTIFIANTS <<<" -ForegroundColor Yellow
    Write-Host "  Admin email    : $AdminEmail" -ForegroundColor Yellow
    Write-Host "  Admin password : $adminPassword" -ForegroundColor Yellow
    Write-Host "  (mot de passe a changer au premier login)" -ForegroundColor Yellow
    Write-Host ""
}

# ============================================================================
# 7. CONFIGURATION NGINX
# ============================================================================
Write-Step "7. Configuration Nginx"

$nginxConfExists = Invoke-Ssh "test -f /etc/nginx/sites-available/gifstudio && echo YES || echo NO"
if ($nginxConfExists -eq 'YES' -and -not $Force) {
    Write-OK "Conf Nginx existe deja, conservee (utilise -Force pour regenerer)"
} else {
    # Conf HTTP only au depart - Certbot ajoutera SSL apres
    $nginxConf = @"
# GifStudio - $Domain
# Genere par bootstrap-vps.ps1

server {
    listen 80;
    listen [::]:80;
    server_name $Domain;

    # Pour Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # API : reverse proxy vers le conteneur API (port 4002)
    location /api/ {
        proxy_pass http://127.0.0.1:4002;
        proxy_http_version 1.1;
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;

        # Upload videos jusqu'a 60Mo (50Mo + marge)
        client_max_body_size 60M;

        # Timeouts longs pour upload
        proxy_connect_timeout 90s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    # Storage : sert directement les fichiers (videos, gifs, thumbnails)
    location /storage/ {
        proxy_pass http://127.0.0.1:4002;
        proxy_http_version 1.1;
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;

        # Cache long pour les assets statiques
        expires 7d;
        add_header Cache-Control "public, max-age=604800, immutable";
    }

    # Frontend Next.js (toutes les autres routes)
    location / {
        proxy_pass http://127.0.0.1:3002;
        proxy_http_version 1.1;
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
        proxy_set_header Upgrade `$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Logs dedies
    access_log /var/log/nginx/gifstudio-access.log;
    error_log  /var/log/nginx/gifstudio-error.log;
}
"@

    $tempConf = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tempConf -Value $nginxConf -NoNewline -Encoding UTF8
    Invoke-Scp -Source $tempConf -Dest "/tmp/gifstudio-nginx.conf"
    Remove-Item $tempConf -Force

    Invoke-Ssh "mv /tmp/gifstudio-nginx.conf /etc/nginx/sites-available/gifstudio" -Sudo
    Invoke-Ssh "ln -sf /etc/nginx/sites-available/gifstudio /etc/nginx/sites-enabled/gifstudio" -Sudo
    Invoke-Ssh "nginx -t" -Sudo
    Invoke-Ssh "systemctl reload nginx" -Sudo
    Write-OK "Nginx configure et recharge"
}

# ============================================================================
# 8. CERTIFICAT SSL Let's Encrypt
# ============================================================================
Write-Step "8. Certificat SSL Let's Encrypt"

if ($SkipSSL) {
    Write-Warn "SSL ignore (option -SkipSSL)"
    Write-Info "Pour ajouter SSL plus tard :"
    Write-Info "  ssh $VpsUser@$VpsHost"
    Write-Info "  sudo certbot --nginx -d $Domain --email $LetsEncryptEmail --agree-tos --no-eff-email"
} else {
    $certbotExists = Invoke-Ssh "which certbot 2>/dev/null || echo MISSING"
    if ($certbotExists -eq 'MISSING') {
        Write-Info "Installation Certbot..."
        Invoke-Ssh "DEBIAN_FRONTEND=noninteractive apt-get install -y certbot python3-certbot-nginx" -Sudo
        Write-OK "Certbot installe"
    }

    $certExists = Invoke-Ssh "test -f /etc/letsencrypt/live/$Domain/fullchain.pem && echo YES || echo NO"
    if ($certExists -eq 'YES') {
        Write-OK "Certificat SSL deja present pour $Domain"
    } else {
        Write-Info "Demande d'un certificat Let's Encrypt..."
        Write-Info "(necessite que le DNS pointe deja sur ce VPS)"
        try {
            Invoke-Ssh "certbot --nginx -d $Domain --email $LetsEncryptEmail --agree-tos --no-eff-email --redirect --non-interactive" -Sudo
            Write-OK "Certificat SSL obtenu et configure"
        } catch {
            Write-Warn "Impossible d'obtenir le certificat SSL"
            Write-Info "Causes possibles :"
            Write-Info "  - DNS pas encore propage (attendre 5-10 min puis retester)"
            Write-Info "  - Port 80 bloque par firewall"
            Write-Info "Relance bootstrap-vps.ps1 plus tard, ou execute manuellement :"
            Write-Info "  sudo certbot --nginx -d $Domain --email $LetsEncryptEmail --agree-tos --no-eff-email"
        }
    }
}

# ============================================================================
# FIN
# ============================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Bootstrap termine !" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Prochaines etapes :"
Write-Host "  1. Verifie le .env.production : ssh $VpsUser@$VpsHost cat $AppRoot/.env.production"
Write-Host "  2. Lance le deploiement : .\deploy.ps1"
Write-Host ""
