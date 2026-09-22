-- id_externo pasa a ser opcional.
--
-- El modelo declara estado @default(PENDIENTE_PAGO), es decir, que la fila
-- nace antes de que el cobro se confirme. Pero Stripe no devuelve el
-- subscription id hasta que el pago se completa, asi que con id_externo NOT
-- NULL ese estado inicial era imposible de insertar: el modelo se contradecia
-- a si mismo. Ahora la fila nace sin id y el webhook lo rellena.
ALTER TABLE "suscripciones" ALTER COLUMN "id_externo" DROP NOT NULL;

-- Unico sobre id_externo.
--
-- La migracion 20260921142001 ya explicaba que los webhooks de Stripe llegan
-- duplicados y desordenados por diseno, pero su indice parcial solo cubre el
-- estado ACTIVA. Este corta el duplicado en su origen: el mismo evento
-- reintentado no puede crear una segunda fila, este en el estado que este.
--
-- En Postgres un indice unico admite varios NULL, asi que las altas todavia
-- sin pagar (id_externo NULL) no se estorban entre si.
CREATE UNIQUE INDEX "suscripciones_id_externo_key" ON "suscripciones" ("id_externo");

-- precio_centimos se queda sin DEFAULT.
--
-- El DEFAULT 500 es de la migracion inicial, anterior al enum TipoPlan. Desde
-- que existe el plan ANUAL es una trampa: un INSERT que se dejara el campo
-- guardaba 5,00 EUR por un ano entero sin que nada se quejara. El precio lo
-- fija el servidor segun tipoPlan (PRECIOS_CENTIMOS en suscripcion.service.ts),
-- y sin default un olvido revienta en el INSERT en vez de cobrar de menos.
ALTER TABLE "suscripciones" ALTER COLUMN "precio_centimos" DROP DEFAULT;
