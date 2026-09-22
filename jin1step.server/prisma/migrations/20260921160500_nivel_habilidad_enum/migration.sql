-- cv_habilidades.nivel deja de ser texto libre.
--
-- La columna era String? con un comentario que sugeria "basico" / "intermedio"
-- / "avanzado" en minusculas y con tilde, mientras habilidad.schema.ts imponia
-- BASICO / INTERMEDIO / AVANZADO en mayusculas. Dos formatos distintos para la
-- misma columna, y la unica garantia real vivia en Zod: el seed, una consulta
-- manual o un endpoint futuro podian escribir cualquier cosa y reventar los
-- filtros que comparan el nivel.
--
-- El USING normaliza por si acaso (acentos y mayusculas) antes de castear, para
-- que la migracion no falle si alguna fila trae el formato antiguo.
CREATE TYPE "NivelHabilidad" AS ENUM ('BASICO', 'INTERMEDIO', 'AVANZADO');

ALTER TABLE "cv_habilidades"
  ALTER COLUMN "nivel" TYPE "NivelHabilidad"
  USING (
    NULLIF(
      translate(upper("nivel"), 'ÁÉÍÓÚ', 'AEIOU'),
      ''
    )::"NivelHabilidad"
  );
