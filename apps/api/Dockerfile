# syntax=docker/dockerfile:1.7
# ============================================================================
# Stage 1 : deps - install des dépendances avec pnpm
# ============================================================================
FROM node:22-alpine AS deps

# Outils nécessaires : pnpm, build tools pour modules natifs (sharp, bcrypt)
RUN apk add --no-cache libc6-compat python3 make g++ \
    && corepack enable \
    && corepack prepare pnpm@9.12.0 --activate

WORKDIR /app

# Copie minimale pour optimiser le cache Docker
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/api/package.json ./apps/api/
COPY packages/shared/package.json ./packages/shared/

RUN pnpm install --frozen-lockfile --filter "@gifstudio/shared..." --filter "api..."

# ============================================================================
# Stage 2 : builder - génère Prisma + compile TypeScript
# ============================================================================
FROM node:22-alpine AS builder

RUN apk add --no-cache libc6-compat \
    && corepack enable \
    && corepack prepare pnpm@9.12.0 --activate

WORKDIR /app

# Récupère les node_modules du stage deps
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/apps/api/node_modules ./apps/api/node_modules
COPY --from=deps /app/packages/shared/node_modules ./packages/shared/node_modules

# Copie les sources nécessaires
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml tsconfig.base.json ./
COPY packages/shared ./packages/shared
COPY apps/api ./apps/api

# Génère le Prisma Client
RUN cd apps/api && pnpm prisma generate

# Compile TypeScript -> JS (apps/api/dist)
RUN pnpm --filter api build

# ============================================================================
# Stage 3 : runner - image finale légère
# ============================================================================
FROM node:22-alpine AS runner

# Utilisateur non-root pour la sécurité
RUN addgroup -S nodejs && adduser -S nodejs -G nodejs \
    && apk add --no-cache libc6-compat tini

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=4000

# Copie les node_modules de production uniquement (depuis builder)
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/packages/shared ./packages/shared
COPY --from=builder --chown=nodejs:nodejs /app/apps/api/node_modules ./apps/api/node_modules
COPY --from=builder --chown=nodejs:nodejs /app/apps/api/dist ./apps/api/dist
COPY --from=builder --chown=nodejs:nodejs /app/apps/api/prisma ./apps/api/prisma
COPY --from=builder --chown=nodejs:nodejs /app/apps/api/package.json ./apps/api/

# Le storage sera monté en volume depuis l'hôte
RUN mkdir -p /app/apps/api/storage/{videos,gifs,thumbnails,trash} \
    && chown -R nodejs:nodejs /app/apps/api/storage

USER nodejs

EXPOSE 4000

# tini = init system minimal (gère bien les signaux SIGTERM)
ENTRYPOINT ["/sbin/tini", "--"]

# Au démarrage : applique les migrations Prisma (idempotent), puis lance le serveur
CMD ["sh", "-c", "cd apps/api && npx prisma migrate deploy && node dist/server.js"]
