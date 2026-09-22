-- CreateEnum
CREATE TYPE "TipoPlan" AS ENUM ('MENSUAL', 'ANUAL');

-- AlterTable
ALTER TABLE "suscripciones" ADD COLUMN     "tipo_plan" "TipoPlan" NOT NULL DEFAULT 'MENSUAL';

-- CreateIndex (manual: Prisma no soporta indices parciales en el schema)
-- Cumple lo que promete el comentario del modelo Suscripcion: un usuario solo
-- puede tener UNA suscripcion ACTIVA a la vez. El historico (CANCELADA,
-- VENCIDA, PENDIENTE_PAGO) puede tener tantas filas como haga falta.
--
-- Es imprescindible porque los webhooks de Stripe llegan duplicados y
-- desordenados por diseno: sin esta red, un reintento crea una segunda fila
-- ACTIVA y el usuario acaba con dos cobros. Misma idea que el
-- @@unique(cvId, ofertaId) de postulaciones frente al autopiloto.
CREATE UNIQUE INDEX "suscripciones_una_activa_por_usuario"
  ON "suscripciones" ("usuario_id")
  WHERE "estado" = 'ACTIVA';
