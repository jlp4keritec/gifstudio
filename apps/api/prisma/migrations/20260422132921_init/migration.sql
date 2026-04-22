-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('admin', 'moderator', 'user');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "email" VARCHAR(255) NOT NULL,
    "password_hash" VARCHAR(255) NOT NULL,
    "role" "UserRole" NOT NULL DEFAULT 'user',
    "must_change_password" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "gifs" (
    "id" UUID NOT NULL,
    "slug" VARCHAR(16) NOT NULL,
    "title" VARCHAR(255) NOT NULL,
    "description" TEXT,
    "file_path" VARCHAR(500) NOT NULL,
    "thumbnail_path" VARCHAR(500) NOT NULL,
    "width" INTEGER NOT NULL,
    "height" INTEGER NOT NULL,
    "duration_ms" INTEGER NOT NULL,
    "fps" INTEGER NOT NULL,
    "file_size" BIGINT NOT NULL,
    "views" INTEGER NOT NULL DEFAULT 0,
    "is_public" BOOLEAN NOT NULL DEFAULT true,
    "owner_id" UUID NOT NULL,
    "tags" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "metadata" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "gifs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "collections" (
    "id" UUID NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "description" TEXT,
    "is_public" BOOLEAN NOT NULL DEFAULT false,
    "owner_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "collections_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "collection_gifs" (
    "collection_id" UUID NOT NULL,
    "gif_id" UUID NOT NULL,
    "added_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "collection_gifs_pkey" PRIMARY KEY ("collection_id","gif_id")
);

-- CreateTable
CREATE TABLE "categories" (
    "id" UUID NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "slug" VARCHAR(100) NOT NULL,

    CONSTRAINT "categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "gif_categories" (
    "gif_id" UUID NOT NULL,
    "category_id" UUID NOT NULL,

    CONSTRAINT "gif_categories_pkey" PRIMARY KEY ("gif_id","category_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "gifs_slug_key" ON "gifs"("slug");

-- CreateIndex
CREATE INDEX "gifs_slug_idx" ON "gifs"("slug");

-- CreateIndex
CREATE INDEX "gifs_is_public_created_at_idx" ON "gifs"("is_public", "created_at" DESC);

-- CreateIndex
CREATE INDEX "gifs_tags_idx" ON "gifs" USING GIN ("tags");

-- CreateIndex
CREATE UNIQUE INDEX "categories_name_key" ON "categories"("name");

-- CreateIndex
CREATE UNIQUE INDEX "categories_slug_key" ON "categories"("slug");

-- AddForeignKey
ALTER TABLE "gifs" ADD CONSTRAINT "gifs_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "collections" ADD CONSTRAINT "collections_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "collection_gifs" ADD CONSTRAINT "collection_gifs_collection_id_fkey" FOREIGN KEY ("collection_id") REFERENCES "collections"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "collection_gifs" ADD CONSTRAINT "collection_gifs_gif_id_fkey" FOREIGN KEY ("gif_id") REFERENCES "gifs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "gif_categories" ADD CONSTRAINT "gif_categories_gif_id_fkey" FOREIGN KEY ("gif_id") REFERENCES "gifs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "gif_categories" ADD CONSTRAINT "gif_categories_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE CASCADE ON UPDATE CASCADE;
