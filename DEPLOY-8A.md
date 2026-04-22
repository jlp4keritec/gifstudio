# Étape 8.A — Configuration Docker

## 📦 Fichiers livrés

| Fichier | Rôle |
|---------|------|
| `apps/api/Dockerfile` | Image API : Node 22 + Express + Prisma (multi-stage, ~150 Mo) |
| `apps/web/Dockerfile` | Image Web : Next.js 15 standalone (~120 Mo) |
| `apps/web/next.config.mjs` | Mis à jour avec `output: 'standalone'` (requis pour Docker) |
| `docker-compose.prod.yml` | Orchestration des 3 services (postgres + api + web) |
| `.env.production.example` | Template de configuration |
| `.dockerignore` | Exclusions du contexte de build |

## 🏗️ Architecture déployée

```
┌─────────────────────────────────────────────────┐
│        Nginx (host)                              │
│        gifstudio.toolspdf.net (HTTPS)            │
└────────────┬────────────────────┬───────────────┘
             │                    │
             │ /api/*             │ /*
             ↓                    ↓
   ┌─────────────────┐    ┌────────────────┐
   │  127.0.0.1:4002 │    │ 127.0.0.1:3002 │
   │  gifstudio-api  │    │ gifstudio-web  │
   │  Node 22 + Express   │ Next.js 15     │
   └────────┬────────┘    └────────────────┘
            │
            │ (réseau Docker)
            ↓
   ┌──────────────────┐
   │ gifstudio-       │
   │   postgres       │
   │ (volume nommé)   │
   └──────────────────┘
            
   Storage :
   /var/www/gifstudio/storage/  →  monté dans le conteneur API
```

## 🔌 Ports

| Service | Port host | Port conteneur | Visibilité |
|---------|-----------|----------------|------------|
| postgres | (aucun) | 5432 | Réseau Docker uniquement |
| api | 127.0.0.1:**4002** | 4000 | Localhost (derrière Nginx) |
| web | 127.0.0.1:**3002** | 3000 | Localhost (derrière Nginx) |

✅ Aucun port exposé publiquement → tout passe par Nginx.

## 🧪 Test en local Windows (optionnel)

Si tu veux tester les images en local avant de déployer sur le VPS :

```cmd
cd C:\gifstudio

REM 1. Crée un .env.production basique pour tester
copy .env.production.example .env.production
notepad .env.production

REM Mets PUBLIC_URL=http://localhost:3002 et STORAGE_PATH=./storage-test

REM 2. Build et démarre les conteneurs
docker compose -f docker-compose.prod.yml --env-file .env.production up --build

REM 3. Teste
REM   API : http://localhost:4002/api/v1/health
REM   Web : http://localhost:3002

REM 4. Pour arrêter
docker compose -f docker-compose.prod.yml down
```

⚠️ **Sur Windows**, mets `STORAGE_PATH` à un chemin Windows valide ou utilise un volume nommé Docker. Le mieux est de **passer directement à la 8.B** pour déployer sur le VPS sans tester en local.

## ✅ À placer dans le repo

Tous ces fichiers vont dans le **repo Git** (sauf `.env.production` qui ne doit JAMAIS être commité).

Vérifie que ton `.gitignore` à la racine contient bien :
```
.env
.env.*
!.env.example
!.env.production.example
storage/
```

## 🔜 Prochaine étape

**8.B — Scripts de déploiement** :
- `scripts/bootstrap-vps.ps1` (à lancer 1 fois)
- `scripts/deploy.ps1` (à lancer à chaque mise à jour)
