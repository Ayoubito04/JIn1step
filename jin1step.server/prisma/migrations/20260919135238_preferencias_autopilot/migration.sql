-- CreateTable
CREATE TABLE "preferencias_autopilot" (
    "usuario_id" TEXT NOT NULL,
    "activo" BOOLEAN NOT NULL DEFAULT false,
    "cv_id" TEXT,
    "score_minimo" DOUBLE PRECISION NOT NULL DEFAULT 70,
    "max_por_dia" INTEGER NOT NULL DEFAULT 5,
    "activado_en" TIMESTAMP(3),
    "revocado_en" TIMESTAMP(3),

    CONSTRAINT "preferencias_autopilot_pkey" PRIMARY KEY ("usuario_id")
);

-- AddForeignKey
ALTER TABLE "preferencias_autopilot" ADD CONSTRAINT "preferencias_autopilot_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "preferencias_autopilot" ADD CONSTRAINT "preferencias_autopilot_cv_id_fkey" FOREIGN KEY ("cv_id") REFERENCES "cvs"("id") ON DELETE SET NULL ON UPDATE CASCADE;
