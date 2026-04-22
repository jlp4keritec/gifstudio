# 🎬 GifStudio

> Outil interne de création, organisation et partage de GIFs animés.
> Inspiré de l'ergonomie de Photoshop / Premiere Pro.

**Statut** : Étape 0 — Socle technique en place ✅

---

## 📚 Documentation

- [`CONTEXT.md`](./CONTEXT.md) — Document de contexte complet du projet (vision, architecture, roadmap)

---

## 🛠️ Stack technique

| Couche | Technologie |
|--------|-------------|
| Frontend | Next.js 15 (App Router), Material-UI v6, TypeScript |
| Backend | Node.js 22, Express, Prisma |
| Base de données | PostgreSQL 16 |
| Auth | JWT + bcrypt (à venir Étape 1) |
| Monorepo | pnpm workspaces |
| Dev | Docker Compose (PostgreSQL) |

---

## 📂 Structure du projet

```
gifstudio/
├── apps/
│   ├── web/                    # Next.js (port 3000)
│   └── api/                    # Express API (port 4000)
├── packages/
│   └── shared/                 # Types & constantes partagés
├── docker-compose.yml          # PostgreSQL + pgAdmin
├── pnpm-workspace.yaml
└── CONTEXT.md
```

---

## 🚀 Démarrage rapide (Windows)

### 1. Prérequis

Installe ces outils **avant** de commencer :

| Outil | Version | Installation |
|-------|---------|--------------|
| **Node.js** | 22 LTS | https://nodejs.org |
| **pnpm** | 9+ | `npm install -g pnpm` |
| **Docker Desktop** | dernière | https://www.docker.com/products/docker-desktop |
| **Git** | dernière | https://git-scm.com |

Vérifie les versions :

```powershell
node --version     # v22.x.x
pnpm --version     # 9.x.x
docker --version   # Docker version 27.x
```

### 2. Installation

Dans le dossier du projet, ouvre **PowerShell** et exécute :

```powershell
# 1. Copier les variables d'environnement
Copy-Item .env.example .env
Copy-Item apps\api\.env.example apps\api\.env
Copy-Item apps\web\.env.example apps\web\.env

# 2. Installer les dépendances
pnpm install
```

### 3. Lancer PostgreSQL

Assure-toi que **Docker Desktop est démarré**, puis :

```powershell
pnpm db:up
```

Cela démarre :
- 🐘 **PostgreSQL** sur `localhost:5432` (user: `gifstudio`, password: `gifstudio_dev_pwd`)
- 🔧 **pgAdmin** sur http://localhost:5050 (admin@gifstudio.local / admin)

Attends ~5 secondes que la base soit prête.

### 4. Créer la base de données et les tables

```powershell
# Générer le client Prisma
pnpm --filter api prisma:generate

# Appliquer les migrations (première fois : création des tables)
pnpm db:migrate
```

Si c'est la toute première fois, Prisma te demandera un nom de migration — tape par exemple `init`.

### 5. Seeder la base (créer l'admin)

```powershell
pnpm db:seed
```

Ceci crée :
- 👤 Un **compte admin** avec les identifiants définis dans `.env` (par défaut `admin@gifstudio.local` / `Admin123`)
- 📁 Les **catégories par défaut** (Réactions, Mèmes, etc.)

⚠️ Le compte admin sera forcé de changer son mot de passe à la première connexion.

### 6. Lancer l'application en développement

```powershell
pnpm dev
```

Cela démarre en parallèle :
- 🎨 **Frontend** sur http://localhost:3000
- 🔌 **API** sur http://localhost:4000
- 🏥 Health check : http://localhost:4000/api/v1/health

Ouvre http://localhost:3000 dans ton navigateur — tu devrais voir la page de démo avec les 3 thèmes cliquables.

---

## 📜 Commandes utiles

### Commandes globales (à la racine)

```powershell
pnpm dev              # Lance web + api en parallèle
pnpm build            # Build tous les packages
pnpm typecheck        # Vérification TypeScript
pnpm lint             # Lint tous les packages

pnpm db:up            # Démarre PostgreSQL (Docker)
pnpm db:down          # Arrête PostgreSQL
pnpm db:logs          # Logs PostgreSQL
pnpm db:migrate       # Applique les migrations
pnpm db:seed          # Seed la base
pnpm db:studio        # Ouvre Prisma Studio (UI de la DB)
```

### Commandes spécifiques

```powershell
# API seulement
pnpm --filter api dev
pnpm --filter api prisma:studio

# Web seulement
pnpm --filter web dev
pnpm --filter web build
```

---

## 🎨 Thèmes disponibles

| Thème | Style | Couleur d'accent |
|-------|-------|------------------|
| **Dark** | Photoshop-like | Bleu `#2196F3` |
| **Medium** | Premiere-like | Orange `#FF9800` |
| **Light** | Moderne | Violet `#7C4DFF` |

Cliquer sur l'icône en haut à droite pour cycler. Préférence persistée en `localStorage`.

---

## 🗄️ Accès à la base de données

### Via pgAdmin (UI web)

1. Ouvre http://localhost:5050
2. Connecte-toi avec `admin@gifstudio.local` / `admin`
3. Ajoute un serveur :
   - **Host** : `postgres` (nom du container Docker)
   - **Port** : `5432`
   - **User** : `gifstudio`
   - **Password** : `gifstudio_dev_pwd`

### Via Prisma Studio

```powershell
pnpm db:studio
```

Ouvre http://localhost:5555

### Via CLI (psql)

```powershell
docker exec -it gifstudio-postgres psql -U gifstudio -d gifstudio
```

---

## 🧹 Réinitialiser la base (dev uniquement)

```powershell
pnpm --filter api prisma:reset
```

⚠️ **Supprime toutes les données** et réapplique les migrations + seed.

---

## 🐛 Troubleshooting

### "Cannot connect to Docker daemon"
→ Vérifie que **Docker Desktop est lancé**.

### "Port 5432 already in use"
→ Un autre PostgreSQL tourne déjà. Arrête-le ou change le port dans `docker-compose.yml`.

### "Invalid environment variables"
→ Vérifie que les fichiers `.env` ont bien été copiés depuis `.env.example` à la racine **et** dans `apps/api` et `apps/web`.

### Erreurs Prisma après modification du schéma
```powershell
pnpm --filter api prisma:generate
pnpm db:migrate
```

### Thèmes qui flashent au chargement
→ Normal au tout premier chargement (le thème est récupéré depuis `localStorage` après hydration). Les rechargements suivants sont instantanés.

---

## 🛣️ Roadmap

| Étape | Contenu | Statut |
|-------|---------|--------|
| **0** | Socle technique | ✅ **Fait** |
| **1** | Auth + gestion utilisateurs (admin) | 🔜 À venir |
| **2** | US#1 — Upload vidéo | ⏳ |
| **3** | US#2 — Découpage vidéo en GIF | ⏳ |
| **4** | US#3 — Éditeur (texte, filtres, recadrage, vitesse) | ⏳ |
| **5** | US#4 — Collections | ⏳ |
| **6** | US#6 — Page d'accueil / trending | ⏳ |
| **7** | US#5 — Partage (lien + embed) | ⏳ |
| **8** | Script PowerShell de déploiement VPS | ⏳ |

Voir [`CONTEXT.md`](./CONTEXT.md) pour le détail de chaque étape.

---

## 📄 Licence

Projet interne privé. Tous droits réservés.
