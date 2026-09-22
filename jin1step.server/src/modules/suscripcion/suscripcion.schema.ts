//Validación de lo que llega por el body al gestionar una suscripción.
//
//Este schema es corto A PROPÓSITO. En el modelo Suscripcion casi ningún campo
//puede venir del cliente, porque el estado real de una suscripción lo tiene la
//pasarela de pago, no nuestra base de datos:
//
//  - estado            lo decide el webhook de la pasarela. Si se aceptara del
//                      body, cualquiera mandaría {"estado":"ACTIVA"} y tendría
//                      el autopiloto gratis. Es el fallo más caro posible aquí.
//  - idExterno         lo devuelve Stripe al crear la suscripción.
//  - precioCentimos    lo fija el servidor según tipoPlan. NUNCA del cliente:
//                      si no, se paga 1 céntimo al mes.
//  - usuarioId         sale del token, nunca del body.
//  - fechaInicio       la pone la BD con @default(now()).
//  - fechaRenovacion   y fechaCancelacion las manda la pasarela.
//
//Mismo criterio que ya se aplica en postulacion.schema.ts con matchScore.
import { z } from 'zod'

//Los valores de los enums de Prisma se escriben a mano en vez de importarlos
//porque este schema define el CONTRATO HTTP, y no debería cambiar solo porque
//alguien añada un valor en Prisma sin tener la integración lista todavía.
export const proveedorPagoSchema = z.enum(['STRIPE', 'GOOGLE_PLAY', 'APP_STORE'])

//tipoPlan SÍ es una elección legítima del cliente: es lo único que el usuario
//decide de verdad al contratar. Lo que NO decide es cuánto cuesta cada plan;
//el servidor traduce tipoPlan -> precio (ver PRECIOS_CENTIMOS en el service).
//
//Ya persistido: la migración 20260921142001 añadió la columna tipo_plan y el
//enum TipoPlan. El service lo usa para dos cosas: elegir el price_id que se
//manda a Stripe y guardar qué plan contrató el usuario.
export const tipoPlanSchema = z.enum(['MENSUAL', 'ANUAL'])

//.strict() y no el strip por defecto de Zod.
//
//Con el comportamiento normal, un body {"estado":"ACTIVA"} pasa la validación
//y el campo se descarta en silencio: seguro, pero invisible. En un endpoint de
//pago interesa lo contrario: que un intento de inyectar precioCentimos o
//estado devuelva 400 y quede registrado, en vez de parecer una petición
//correcta. También caza erratas del frontend ("provedorPago") que con strip
//se tragarían sin avisar y acabarían cobrando el plan por defecto.
export const iniciarSuscripcionSchema = z
    .object({
        tipoPlan: tipoPlanSchema.default('MENSUAL'),

        //Por defecto STRIPE: es el proveedor de la web. Las apps móviles
        //mandarán GOOGLE_PLAY o APP_STORE, porque sus tiendas obligan a
        //cobrar por su propio sistema de compras in-app.
        proveedorPago: proveedorPagoSchema.default('STRIPE'),

        //Clave de idempotencia opcional que genera el cliente (un uuid) y
        //repite si tiene que reintentar. Sin esto, un usuario con mala
        //conexión que pulsa "Pagar" dos veces acaba con dos suscripciones y
        //dos cobros. Se pasa tal cual a Stripe como Idempotency-Key.
        claveIdempotencia: z.uuid('claveIdempotencia debe ser un uuid').optional(),
    })
    .strict()
    //Todos los campos de arriba son default u optional, así que el caso normal
    //("contrátame el plan por defecto") es un POST sin body. En Express 5 eso
    //deja req.body en undefined —Express 4 lo dejaba en {}— y validateBody se
    //lo pasa tal cual a safeParse, que respondería 400 a la petición más
    //corriente de todas.
    //
    //Tiene que ser .prefault() y no .default(): default devuelve ese {} sin
    //parsearlo, así que tipoPlan y proveedorPago se quedarían vacíos. prefault
    //mete el {} POR el parseo, y los defaults de dentro sí se aplican.
    .prefault({})

//Cancelar no lleva id: la suscripción a cancelar es la ACTIVA del usuario del
//token. Aceptar un id por body permitiría cancelar la de otro.
//
//El motivo es opcional y solo sirve para analítica interna; no afecta a
//ninguna decisión del servidor, así que se limita para que no se use como
//campo de texto libre donde meter cualquier cosa.
export const cancelarSuscripcionSchema = z
    .object({
        motivo: z
            .string()
            .trim()
            .min(1, 'El motivo no puede estar vacío')
            .max(300, 'El motivo no puede superar los 300 caracteres')
            .optional(),

        //Cancelar al final del periodo ya pagado (true, lo normal y lo que
        //esperan las leyes de consumo de la UE) o cortar de inmediato
        //perdiendo los días restantes (false). Es decisión del usuario, así
        //que sí puede venir del cliente.
        alFinalDelPeriodo: z.boolean().default(true),
    })
    .strict()
    //Mismo motivo que en iniciarSuscripcionSchema: "cancelar sin dar motivo"
    //es una petición sin body, y sin esto alFinalDelPeriodo nunca llegaría a
    //valer true, que es justo el comportamiento que esperan las leyes de
    //consumo.
    .prefault({})

//NO hay schema para el webhook a propósito.
//
//Un webhook no se valida por forma, se valida por FIRMA: hay que comprobar
//con stripe.webhooks.constructEvent() que el evento viene firmado con el
//secreto del endpoint. Un schema de Zod aceptaría igual de bien un POST
//falsificado desde cualquier sitio con la forma correcta.
//
//Además, constructEvent necesita el body CRUDO (Buffer). Si express.json()
//lo parsea antes, la firma deja de cuadrar y todos los eventos se rechazan.
//Por eso la ruta del webhook se monta con express.raw() ANTES del json().

//Los dos llevan sufijo Input a propósito: sin él se llamarían igual que los
//ProveedorPago y TipoPlan que genera @prisma/client, y el service va a
//importar de los dos sitios (como ya hacen empresa, habilidad y postulacion).
//Dos tipos homónimos e idénticos hoy dejan de avisar el día que alguien añade
//un valor en Prisma, que es justo la divergencia que el comentario de los
//enums de arriba quiere poder detectar.
export type ProveedorPagoInput = z.infer<typeof proveedorPagoSchema>
export type TipoPlanInput = z.infer<typeof tipoPlanSchema>
export type IniciarSuscripcionInput = z.infer<typeof iniciarSuscripcionSchema>
export type CancelarSuscripcionInput = z.infer<typeof cancelarSuscripcionSchema>
