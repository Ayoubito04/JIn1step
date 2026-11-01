-- AlterEnum
ALTER TYPE "EstadoPostulacion" ADD VALUE 'PROPUESTA';
ALTER TYPE "EstadoPostulacion" ADD VALUE 'DESCARTADA';

-- CreateEnum
CREATE TYPE "OrigenEjecucion" AS ENUM ('MANUAL', 'DIARIA');

-- CreateEnum
CREATE TYPE "ModoAutopilot" AS ENUM ('REVISION', 'AUTOMATICO');

-- AlterTable
ALTER TABLE "postulaciones" ADD COLUMN     "palabras_clave_cubiertas" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "palabras_clave_faltantes" TEXT[] DEFAULT ARRAY[]::TEXT[];

-- AlterTable
ALTER TABLE "preferencias_autopilot" ADD COLUMN     "revisar_antes" BOOLEAN NOT NULL DEFAULT true;

-- CreateTable
CREATE TABLE "ejecuciones_autopilot" (
    "id" TEXT NOT NULL,
    "usuario_id" TEXT NOT NULL,
    "fecha" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "origen" "OrigenEjecucion" NOT NULL,
    "modo" "ModoAutopilot" NOT NULL,
    "evaluadas" INTEGER NOT NULL,
    "propuestas" INTEGER NOT NULL,
    "enviadas" INTEGER NOT NULL,
    "via" TEXT,
    "motivo" TEXT,

    CONSTRAINT "ejecuciones_autopilot_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ejecuciones_autopilot_usuario_id_fecha_idx" ON "ejecuciones_autopilot"("usuario_id", "fecha" DESC);

-- AddForeignKey
ALTER TABLE "ejecuciones_autopilot" ADD CONSTRAINT "ejecuciones_autopilot_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE ON UPDATE CASCADE;
