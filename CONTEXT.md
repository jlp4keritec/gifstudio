# GifStudio — Document de Contexte Projet

> **Version** : 1.0
> **Date** : 22 avril 2026
> **Statut** : Validé — Prêt pour développement
> **Méthode** : BMAD (Backlog / Mockups / Architecture / Development)

---

## 📑 Sommaire

1. [Vision & Objectifs](#1-vision--objectifs)
2. [Public cible & contraintes](#2-public-cible--contraintes)
3. [Périmètre du MVP](#3-périmètre-du-mvp)
4. [User Stories priorisées](#4-user-stories-priorisées)
5. [Rôles & permissions](#5-rôles--permissions)
6. [Stack technique](#6-stack-technique)
7. [Architecture générale](#7-architecture-générale)
8. [Modèle de données](#8-modèle-de-données)
9. [Authentification & sécurité](#9-authentification--sécurité)
10. [Stockage des fichiers](#10-stockage-des-fichiers)
11. [Éditeur GIF](#11-éditeur-gif)
12. [Thèmes UI](#12-thèmes-ui)
13. [Structure du monorepo](#13-structure-du-monorepo)
14. [Environnement de développement](#14-environnement-de-développement)
15. [Déploiement](#15-déploiement)
16. [Conventions de code](#16-conventions-de-code)
17. [Roadmap de développement](#17-roadmap-de-développement)
18. [Glossaire](#18-glossaire)

---

## 1. Vision & Objectifs

### Vision
GifStudio est un **outil interne** de création, organisation et partage de GIFs animés, inspiré de l'ergonomie des logiciels professionnels (Photoshop, Premiere Pro). Les GIFs produits sont diffusables publiquement via des liens SEO-friendly, ce qui permet leur référencement par Google et leur intégration sur des sites externes.

### Objectifs principaux
- **Créer** des GIFs depuis des vidéos uploadées, avec un éditeur riche mais épuré.
- **Organiser** la production dans des collections thématiques.
- **Partager** les GIFs publiquement via URLs courtes et embed.
- **Découvrir** les GIFs populaires via une page d'accueil dédiée.

### Hors-scope (Phase 2 ou au-delà)
- Import YouTube/Vimeo
- Collaboration multi-utilisateurs sur collections
- Notifications temps réel
- IA (tagging automatique, suggestions)
- Monétisation

---

## 2. Public cible & contraintes

### Utilisateurs
- **Outil interne** : accès uniquement par comptes créés par un administrateur.
- Trois rôles : `admin`, `moderator`, `user`.

### Visiteurs externes (non connectés)
- Peuvent **consulter** les GIFs publics et les pages de découverte.
- **Ne peuvent pas** créer, éditer ou sauvegarder.

### Contraintes
- Upload vidéo max : **50 Mo**
- Durée GIF : **3 à 10 secondes**
- Formats vidéo acceptés : **MP4, MOV, WebM**
- Interface responsive desktop + mobile
- Mono-langue (français)
- Hébergement sur **VPS OVH Ubuntu** existant

---

## 3. Périmètre du MVP

Le MVP correspond à la **Phase 1** du document BMAD initial. Toutes les fonctionnalités de Phase 2 sont explicitement reportées.

| ID | User Story | Priorité | Statut |
|----|------------|----------|--------|
| US#1 | Uploader une vidéo | Haute | MVP |
| US#2 | Découper la vidéo en GIF | Haute | MVP |
| US#3 | Ajouter des effets (texte, filtres, recadrage) | Moyenne | MVP |
| US#4 | Sauvegarder dans une collection | Haute | MVP |
| US#5 | Partager via lien / embed | Haute | MVP |
| US#6 | Parcourir GIFs populaires / trending | Moyenne | MVP |
| US#7 | Import YouTube/Vimeo | Moyenne | **Phase 2** |
| US#8 | Collections collaboratives | Basse | **Phase 2** |
| US#9 | Notifications likes | Basse | **Phase 2** |
| US#10 | Modération admin | Haute | **Phase 2** |

---

## 4. User Stories priorisées

### Ordre de développement validé
```
US#1 → US#2 → US#3 → US#4 → US#6 → US#5
```

### Détails
- **US#1** : Upload drag & drop, validation côté client (format + taille), stockage temporaire de la source vidéo.
- **US#2** : Sélection de plage avec timeline à 2 poignées (3-10s), prévisualisation temps réel.
- **US#3** : 6 outils minimalistes (voir §11).
- **US#4** : Collections publiques/privées, CRUD, association N:N avec GIFs.
- **US#6** : Page d'accueil publique avec trending, catégories, recherche.
- **US#5** : URL courte `/g/{slug}`, page publique SEO, code embed iframe.

---

## 5. Rôles & permissions

| Rôle | Création compte | Créer GIF | Modérer | Créer admin |
|------|----------------|-----------|---------|-------------|
| **admin** | ✅ (tous rôles) | ✅ | ✅ | ✅ |
| **moderator** | ❌ | ✅ | ✅ | ❌ |
| **user** | ❌ | ✅ | ❌ | ❌ |
| **visiteur public** | ❌ | ❌ | ❌ | ❌ |

### Règles spécifiques
- L'inscription publique est **désactivée**.
- Un compte admin initial est créé via un **script de seed** au premier lancement (credentials dans `.env`).
- Le mot de passe par défaut de l'admin initial (`Admin123`) **doit obligatoirement être changé à la première connexion** (écran de changement forcé).

---

## 6. Stack technique

### Frontend
| Composant | Technologie | Version |
|-----------|-------------|---------|
| Framework | **Next.js** | 15.x (App Router) |
| UI | **Material-UI** (MUI) | v6 |
| Langage | **TypeScript** | 5.x |
| Éditeur vidéo | **FFmpeg.wasm** (côté client) | auto-hébergé |
| Canvas | **Konva.js** (texte/stickers) | dernière |
| État | React Context + hooks (pas de Redux) | — |

### Backend
| Composant | Technologie | Version |
|-----------|-------------|---------|
| Runtime | **Node.js** | 22 LTS |
| Framework | **Express** | 4.x |
| Langage | **TypeScript** | 5.x |
| ORM | **Prisma** | dernière |
| Auth | **JWT simple + bcrypt** | — |

### Base de données
- **PostgreSQL 16** (choix unique — exit MongoDB)
- Utilisation intensive de `JSONB` pour les métadonnées flexibles
- Index `GIN` pour la recherche par tags
- Recherche plein texte via `tsvector`

### Infrastructure
- **Dev** : Windows local + Docker Compose (PostgreSQL)
- **Prod** : VPS OVH Ubuntu (stockage disque local)
- **Reverse proxy** : Nginx (à configurer au déploiement)
- **Process manager** : PM2
- **Déploiement** : script PowerShell automatisé

### Outils transverses
- Gestionnaire de paquets : **pnpm** (workspaces)
- Linter : ESLint
- Formatter : Prettier
- Git : monorepo unique, compte GitHub existant

---

## 7. Architecture générale

```
┌────────────────────┐
│   Utilisateur /    │
│   Visiteur public  │
└──────────┬─────────┘
           │ HTTPS
           ▼
┌────────────────────┐
│   Nginx (VPS)      │
│   Reverse Proxy    │
└──────┬──────┬──────┘
       │      │
       ▼      ▼
┌───────────┐ ┌──────────────┐
│ Next.js   │ │ Express API  │
│ (port     │ │ (port 4000)  │
│  3000)    │ │              │
└───────────┘ └──────┬───────┘
                     │
         ┌───────────┼───────────┐
         ▼           ▼           ▼
   ┌──────────┐ ┌─────────┐ ┌──────────┐
   │PostgreSQL│ │ Disque  │ │ FFmpeg   │
   │          │ │ local   │ │ (client  │
   │          │ │(storage)│ │  WASM)   │
   └──────────┘ └─────────┘ └──────────┘
```

### Principes
- **Traitement vidéo côté client** (FFmpeg WASM) : économise la RAM/CPU serveur, scale mieux.
- **Backend stateless** : toute la logique d'auth via JWT.
- **Stockage disque** : géré par l'API via chemins contrôlés, servis via Nginx avec cache.

---

## 8. Modèle de données

### Tables principales (PostgreSQL)

#### `users`
| Champ | Type | Notes |
|-------|------|-------|
| id | UUID | PK |
| email | VARCHAR(255) | UNIQUE, NOT NULL |
| password_hash | VARCHAR(255) | bcrypt |
| role | ENUM('admin','moderator','user') | DEFAULT 'user' |
| must_change_password | BOOLEAN | DEFAULT false |
| created_at | TIMESTAMP | |
| updated_at | TIMESTAMP | |

#### `gifs`
| Champ | Type | Notes |
|-------|------|-------|
| id | UUID | PK |
| slug | VARCHAR(16) | UNIQUE, indexé, court pour SEO |
| title | VARCHAR(255) | |
| description | TEXT | optionnel |
| file_path | VARCHAR(500) | chemin disque |
| thumbnail_path | VARCHAR(500) | |
| width | INT | |
| height | INT | |
| duration_ms | INT | |
| fps | INT | |
| file_size | BIGINT | octets |
| views | INT | DEFAULT 0 |
| is_public | BOOLEAN | DEFAULT true |
| owner_id | UUID | FK → users |
| metadata | JSONB | filtres, vitesse, textes appliqués |
| tags | TEXT[] | GIN index |
| created_at | TIMESTAMP | |

#### `collections`
| Champ | Type | Notes |
|-------|------|-------|
| id | UUID | PK |
| name | VARCHAR(255) | |
| description | TEXT | |
| is_public | BOOLEAN | DEFAULT false |
| owner_id | UUID | FK → users |
| created_at | TIMESTAMP | |

#### `collection_gifs` (N:N)
| Champ | Type | Notes |
|-------|------|-------|
| collection_id | UUID | FK |
| gif_id | UUID | FK |
| added_at | TIMESTAMP | |
| PK composite | (collection_id, gif_id) | |

#### `categories`
| Champ | Type | Notes |
|-------|------|-------|
| id | UUID | PK |
| name | VARCHAR(100) | UNIQUE |
| slug | VARCHAR(100) | UNIQUE |

#### `gif_categories` (N:N)
| Champ | Type |
|-------|------|
| gif_id | UUID |
| category_id | UUID |

---

## 9. Authentification & sécurité

### JWT simple
- **1 seul token** (pas de refresh).
- **Durée** : 24h.
- **Signature** : HMAC-SHA256.
- **Secret** : `JWT_SECRET` dans `.env`.
- **Stockage côté client** : cookie HTTP-only, Secure, SameSite=Strict.

### Mots de passe
- **bcrypt** (cost factor 12).
- Exigences : min 8 caractères, au moins 1 majuscule + 1 chiffre (validation front + back).
- Changement forcé si `must_change_password = true`.

### Seed admin initial
```env
ADMIN_EMAIL=admin@gifstudio.local
ADMIN_PASSWORD=Admin123
```
Au premier lancement, un script crée le compte admin avec `must_change_password = true`.

### Protections
- **Helmet.js** (headers HTTP sécurisés)
- **CORS** restreint au domaine frontend
- **Rate limiting** sur `/auth/login` (5 tentatives / 15min / IP)
- **Validation Zod** sur tous les endpoints
- **Upload** : vérification MIME type + magic bytes + taille

---

## 10. Stockage des fichiers

### Arborescence VPS
```
/var/www/gifstudio/storage/
├── videos/        # Sources temporaires (avant archivage)
├── gifs/          # GIFs finaux servis publiquement
├── thumbnails/    # Miniatures JPG des GIFs
└── trash/         # Archivage des vidéos sources après génération
```

### Règles
- **Nommage** : UUID v4 (ex: `a3f5c9e1-...-b7d2.gif`)
- **Quota** : illimité (outil interne)
- **Archivage** : après génération du GIF, la vidéo source est **déplacée** dans `trash/` (pas supprimée).
- **Nettoyage** : cron hebdomadaire (à prévoir en Phase 2) pour purger `trash/` > 30 jours.

### Diffusion
- Les GIFs et thumbnails sont servis **par Nginx** (cache agressif `Cache-Control: public, max-age=31536000`).
- L'API ne sert jamais les fichiers directement (perf).

---

## 11. Éditeur GIF

### Layout fixe (style Photoshop / Premiere)
```
┌─────────────────────────────────────────────────┐
│ Topbar : Fichier | Édition | Export | Thème    │
├──────┬───────────────────────────────┬──────────┤
│      │                               │          │
│ Out- │      Canvas (preview)         │ Panneau  │
│ ils  │                               │ proprié- │
│      │                               │ tés      │
│      │                               │          │
├──────┴───────────────────────────────┴──────────┤
│           Timeline (sélection plage)            │
└─────────────────────────────────────────────────┘
```

### Outils MVP (6 uniquement)
| # | Outil | Détails |
|---|-------|---------|
| 1 | **Découpage** | Timeline 2 poignées, plage 3-10s |
| 2 | **Recadrage** | Libre + préréglés 1:1, 16:9, 9:16, 4:3 |
| 3 | **Texte** | 3-4 polices (Arial, Impact, Roboto, Courier), taille, couleur, position drag & drop, contour noir optionnel |
| 4 | **Filtres** | Normal, N&B, Sépia |
| 5 | **Vitesse** | 0.5x, 1x, 1.5x, 2x |
| 6 | **Export** | Résolution (240p/360p/480p/720p), FPS (10/15/24/30) |

### Technologie
- **FFmpeg.wasm** auto-hébergé, chargé en lazy-load à l'ouverture de l'éditeur.
- **Konva.js** pour le rendu canvas (texte, recadrage interactif).
- Prévisualisation temps réel à chaque changement de paramètre.

---

## 12. Thèmes UI

Trois thèmes disponibles, préférence persistée en `localStorage` + profil utilisateur.

| Thème | Fond primaire | Fond secondaire | Accent | Ambiance |
|-------|---------------|-----------------|--------|----------|
| **Dark** | `#1E1E1E` | `#2D2D2D` | Bleu `#2196F3` | Photoshop-like, immersif |
| **Medium** | `#3A3A3A` | `#4A4A4A` | Orange `#FF9800` | Premiere-like, chaleureux |
| **Light** | `#FAFAFA` | `#FFFFFF` | Violet `#7C4DFF` | Clair, moderne |

Toggle accessible depuis la topbar (menu utilisateur).

---

## 13. Structure du monorepo

```
gifstudio/
├── apps/
│   ├── web/                    # Next.js 15 (App Router)
│   │   ├── app/
│   │   ├── components/
│   │   ├── lib/
│   │   ├── theme/
│   │   ├── public/
│   │   └── package.json
│   └── api/                    # Express
│       ├── src/
│       │   ├── routes/
│       │   ├── controllers/
│       │   ├── middlewares/
│       │   ├── services/
│       │   └── server.ts
│       ├── prisma/
│       │   ├── schema.prisma
│       │   └── seed.ts
│       └── package.json
├── packages/
│   └── shared/                 # Types, constantes, DTOs partagés
│       ├── src/
│       └── package.json
├── docker-compose.yml          # PostgreSQL local
├── pnpm-workspace.yaml
├── package.json
├── tsconfig.base.json
├── .env.example
├── .gitignore
├── CONTEXT.md                  # ce document
└── README.md
```

### Gestionnaire : **pnpm workspaces**
- Plus rapide et économe en disque que npm/yarn.
- Gestion propre des dépendances cross-packages.

---

## 14. Environnement de développement

### Poste développeur
- **OS** : Windows
- **Node.js** : 22 LTS
- **pnpm** : dernière version
- **Docker Desktop** : pour PostgreSQL local
- **VS Code** recommandé (extensions : ESLint, Prettier, Prisma)

### Lancement
```powershell
# 1. Installation
pnpm install

# 2. Lancer PostgreSQL
docker compose up -d

# 3. Migrations + seed
pnpm --filter api prisma:migrate
pnpm --filter api prisma:seed

# 4. Dev (API + Web en parallèle)
pnpm dev
```

### Ports
| Service | Port |
|---------|------|
| Next.js | 3000 |
| Express API | 4000 |
| PostgreSQL | 5432 |
| pgAdmin (optionnel) | 5050 |

---

## 15. Déploiement

### Cible
- **VPS OVH** Ubuntu (version à préciser au moment du déploiement).
- **Nginx** en reverse proxy (à installer si absent).
- **PM2** pour gérer les process Node.
- **Let's Encrypt** pour SSL (à prévoir).

### Méthode
Script **PowerShell** automatisé (à développer en dernière étape) qui :
1. Build le frontend Next.js
2. Build le backend Express
3. Upload SCP vers le VPS
4. SSH : `pm2 restart`, Nginx reload, migrations DB

### Environnements
- Pas d'environnement staging au MVP.
- Direct : dev local → production VPS.

### Informations VPS (à collecter au moment du déploiement)
- Version Ubuntu exacte
- Specs (RAM, CPU, disque)
- Accès SSH
- Nginx/PM2/Docker déjà installés ?
- Ports disponibles
- Configuration SSL

---

## 16. Conventions de code

### TypeScript
- **Strict mode** activé partout.
- Pas de `any` (sauf exception justifiée en commentaire).
- Types partagés dans `packages/shared`.

### Nommage
- **Fichiers** : `kebab-case.ts` (ex: `user-controller.ts`)
- **Classes / types** : `PascalCase`
- **Variables / fonctions** : `camelCase`
- **Constantes** : `UPPER_SNAKE_CASE`
- **Composants React** : `PascalCase.tsx`

### Git
- Branche principale : `main`
- Branches de feature : `feature/us-XX-description`
- Commits conventionnels : `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`

### API
- REST
- Préfixe : `/api/v1/`
- Réponses JSON standardisées :
```json
{ "success": true, "data": {...} }
{ "success": false, "error": "MESSAGE", "code": "ERROR_CODE" }
```

---

## 17. Roadmap de développement

| Étape | Contenu | Livrable |
|-------|---------|----------|
| **0** | Socle technique | Monorepo initialisé, Docker, thèmes, config |
| **1** | Auth + gestion utilisateurs | Login, JWT, CRUD users admin, changement mdp forcé |
| **2** | US#1 — Upload vidéo | Drag & drop, validation, stockage temp |
| **3** | US#2 — Découpage GIF | Timeline, FFmpeg.wasm, génération GIF |
| **4** | US#3 — Éditeur complet | 6 outils + prévisualisation |
| **5** | US#4 — Collections | CRUD collections, associations |
| **6** | US#6 — Découverte | Page d'accueil, trending, catégories, recherche |
| **7** | US#5 — Partage & SEO | URL courte, page publique, embed |
| **8** | Déploiement | Script PowerShell, config VPS |

---

## 18. Glossaire

| Terme | Définition |
|-------|------------|
| **BMAD** | Méthode projet : Backlog / Mockups / Architecture / Development |
| **MVP** | Minimum Viable Product — version minimale mais fonctionnelle |
| **US** | User Story |
| **JWT** | JSON Web Token — mécanisme d'authentification stateless |
| **bcrypt** | Algorithme de hashage de mots de passe |
| **FFmpeg.wasm** | Version WebAssembly de FFmpeg exécutable dans le navigateur |
| **Konva.js** | Librairie de rendu 2D sur canvas HTML5 |
| **Prisma** | ORM TypeScript pour bases SQL |
| **JSONB** | Type PostgreSQL pour stocker du JSON indexable |
| **Slug** | Identifiant court lisible pour URL (ex: `abc123`) |
| **Embed** | Code HTML (iframe) pour intégrer un GIF sur un site tiers |
| **Trending** | GIFs populaires (tri par vues récentes) |

---

## 📝 Historique des décisions

| Date | Décision | Justification |
|------|----------|---------------|
| 2026-04-22 | Full PostgreSQL (exit MongoDB) | Simplicité infra, JSONB suffit pour les besoins flexibles |
| 2026-04-22 | JWT simple (pas de refresh) | Outil interne, complexité non justifiée |
| 2026-04-22 | FFmpeg côté client (WASM) | Économie ressources serveur, scale naturel |
| 2026-04-22 | Stockage disque local (pas S3) | VPS existant, outil interne, pas besoin CDN |
| 2026-04-22 | Archivage vidéos sources (pas suppression) | Sécurité / récupération éventuelle |
| 2026-04-22 | Ordre US#6 avant US#5 | Base de données de GIFs à parcourir nécessaire pour tester le partage |

---

*Document maintenu par l'équipe projet. Toute modification doit être validée et reportée dans l'historique.*
