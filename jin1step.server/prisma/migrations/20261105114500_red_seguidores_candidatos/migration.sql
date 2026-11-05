-- CreateTable
CREATE TABLE IF NOT EXISTS "seguimientos_candidato" (
    "seguidor_id" TEXT NOT NULL,
    "seguido_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "seguimientos_candidato_pkey" PRIMARY KEY ("seguidor_id","seguido_id")
);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "seguimientos_candidato_seguido_id_idx" ON "seguimientos_candidato"("seguido_id");

-- AddForeignKey
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'seguimientos_candidato_seguidor_id_fkey'
    ) THEN
        ALTER TABLE "seguimientos_candidato" ADD CONSTRAINT "seguimientos_candidato_seguidor_id_fkey" FOREIGN KEY ("seguidor_id") REFERENCES "usuarios"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'seguimientos_candidato_seguido_id_fkey'
    ) THEN
        ALTER TABLE "seguimientos_candidato" ADD CONSTRAINT "seguimientos_candidato_seguido_id_fkey" FOREIGN KEY ("seguido_id") REFERENCES "usuarios"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
END $$;

