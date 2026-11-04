-- AlterTable
ALTER TABLE "candidatos_perfil"
ADD COLUMN IF NOT EXISTS "expectativa_salarial" INTEGER,
ADD COLUMN IF NOT EXISTS "banner" TEXT;

-- AlterTable
ALTER TABLE "ofertas"
ADD COLUMN IF NOT EXISTS "salario" TEXT;

