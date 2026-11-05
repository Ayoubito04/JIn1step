-- AlterTable
ALTER TABLE "usuarios" ADD COLUMN IF NOT EXISTS "linkedin_id" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX IF NOT EXISTS "usuarios_linkedin_id_key" ON "usuarios"("linkedin_id");

