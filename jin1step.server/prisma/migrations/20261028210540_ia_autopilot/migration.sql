-- AlterTable
ALTER TABLE "cvs" ADD COLUMN     "perfil_ia" JSONB,
ADD COLUMN     "perfil_ia_hash" TEXT;

-- AlterTable
ALTER TABLE "postulaciones" ADD COLUMN     "carta_ia" TEXT,
ADD COLUMN     "motivo_ia" TEXT,
ADD COLUMN     "puntuacion_ia" DOUBLE PRECISION;
