# syntax=docker/dockerfile:1.7
# ============================================================================
# Stage 1 : deps
# ============================================================================
FROM node:22-alpine AS deps

RUN apk add --no-cache libc6-compat python3 make g++ \
    && corepack enable \
    && corepack prepare pnpm@9.12.0 --activate

WORKDIR /app

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/api/package.json ./apps/api/
COPY packages/shared/package.json ./packages/shared/

RUN pnpm install --frozen-lockfile --filter "@gifstudio/shared..." --filter "api..."

# ============================================================================
# Stage 2 : builder
# ============================================================================
FROM node:22-alpine AS builder

RUN apk add --no-cache libc6-compat \
    && corepack enable \
    && corepack prepare pnpm@9.12.0 --activate

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/apps/api/node_modules ./apps/api/node_modules
COPY --from=deps /app/packages/shared/node_modules ./packages/shared/node_modules

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY packages/shared ./packages/shared
COPY apps/api ./apps/api

# Genere le Prisma Client
RUN cd apps/api && pnpm prisma generate

# Compile TypeScript -> JS (apps/api/dist contient apps/api/src + packages/shared/src)
RUN cd apps/api && pnpm build

# ============================================================================
# Stage 3 : runner
# ============================================================================
FROM node:22-alpine AS runner

RUN addgroup -S nodejs && adduser -S nodejs -G nodejs \
    && apk add --no-cache libc6-compat tini

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=4000

# Copie des modules de prod (le node_modules root contient prisma engines)
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/apps/api/node_modules ./apps/api/node_modules
COPY --from=builder --chown=nodejs:nodejs /app/packages/shared ./packages/shared

# Le dist contient maintenant apps/api/src + packages/shared/src
COPY --from=builder --chown=nodejs:nodejs /app/apps/api/dist ./apps/api/dist
COPY --from=builder --chown=nodejs:nodejs /app/apps/api/prisma ./apps/api/prisma
COPY --from=builder --chown=nodejs:nodejs /app/apps/api/package.json ./apps/api/

RUN mkdir -p /app/apps/api/storage/{videos,gifs,thumbnails,trash} \
    && chown -R nodejs:nodejs /app/apps/api/storage

USER nodejs

EXPOSE 4000

ENTRYPOINT ["/sbin/tini", "--"]

# Le binaire compile se trouve dans dist/apps/api/src/server.js (a cause du rootDir ../../)
CMD ["sh", "-c", "cd apps/api && npx prisma migrate deploy && node dist/apps/api/src/server.js"]
