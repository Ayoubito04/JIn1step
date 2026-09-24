//Webhook de Stripe: el ÚNICO camino por el que una suscripción llega a ACTIVA.
//
//Va en su propio archivo y se monta aparte del resto de rutas por una razón
//técnica: constructEvent necesita el body CRUDO, byte a byte, para recalcular
//la firma. Si express.json() lo parsea antes, el cuerpo deja de coincidir con
//lo que Stripe firmó y TODOS los eventos se rechazan.
//
//Por eso este router se monta en app.ts ANTES del express.json() global.
import { Router, raw } from 'express'
import type { Request, Response } from 'express'
import type Stripe from 'stripe'
import { prisma } from '../../lib/prisma'
import { stripe, secretoWebhook } from '../../lib/stripe'
import { ActivarPorWebhook } from './suscripcion.service'

export const suscripcionWebhookRouter = Router()

//Estos eventos cierran el ciclo de vida de la suscripción. El resto que
//mande Stripe se acepta con 200 y se ignora: devolver error haría que Stripe
//reintentara indefinidamente algo que no nos interesa.
const EVENTOS = {
    PAGADO: 'checkout.session.completed',
    RENOVADO: 'invoice.paid',
    IMPAGO: 'invoice.payment_failed',
    CANCELADA: 'customer.subscription.deleted',
} as const

//Sin requireAuth a propósito: quien llama es Stripe, no un usuario con token.
//La autenticación aquí es la FIRMA criptográfica del evento, que es más
//fuerte que un JWT: nadie puede falsificarla sin el secreto del endpoint.
suscripcionWebhookRouter.post(
    '/',
    raw({ type: 'application/json' }),
    async (req: Request, res: Response): Promise<void> => {
        const firma = req.headers['stripe-signature']

        if (typeof firma !== 'string') {
            res.status(400).json({ error: 'Falta la cabecera stripe-signature' })
            return
        }

        let evento: Stripe.Event

        try {
            //req.body es un Buffer gracias al raw() de arriba. Si algún día
            //alguien mueve este router detrás del json(), aquí llegará un
            //objeto y la verificación fallará con "no signatures found".
            evento = stripe().webhooks.constructEvent(
                req.body as Buffer,
                firma,
                secretoWebhook(),
            )
        } catch (err) {
            //400 y no 500: el evento no es de Stripe o viene manipulado.
            //Stripe NO reintenta los 400, que es lo que queremos: reintentar
            //un evento falsificado no arreglaría nada.
            console.error('Webhook rechazado:', (err as Error).message)
            res.status(400).json({ error: 'Firma no válida' })
            return
        }

        //A partir de aquí el evento es auténtico.
        //
        //Se responde 200 pase lo que pase con nuestro procesado: Stripe solo
        //quiere saber que lo hemos recibido. Si devolviéramos 500 por un
        //fallo nuestro, Stripe reintentaría el mismo evento durante días.
        try {
            await procesarEvento(evento)
        } catch (err) {
            console.error(
                `Error procesando ${evento.type} (${evento.id}):`,
                (err as Error).message,
            )
        }

        res.status(200).json({ recibido: true })
    },
)

async function procesarEvento(evento: Stripe.Event): Promise<void> {
    switch (evento.type) {
        case EVENTOS.PAGADO: {
            const sesion = evento.data.object as Stripe.Checkout.Session

            //El id de NUESTRA suscripción viaja en metadata desde que se creó
            //la sesión de checkout. Sin esto no habría forma de saber a qué
            //fila de nuestra BD corresponde este pago.
            const suscripcionId = sesion.metadata?.['suscripcionId']

            if (!suscripcionId || typeof sesion.subscription !== 'string') {
                console.error('checkout.session.completed sin metadata o sin subscription')
                return
            }

            //La fecha de renovación real la tiene el objeto Subscription, no
            //la sesión de checkout, así que hay que pedirla.
            const suscripcionStripe = await stripe().subscriptions.retrieve(
                sesion.subscription,
            )

            await ActivarPorWebhook(
                suscripcionId,
                sesion.subscription,
                finDelPeriodo(suscripcionStripe),
            )
            return
        }

        case EVENTOS.RENOVADO: {
            const factura = evento.data.object as Stripe.Invoice
            const idExterno = idSuscripcionDeFactura(factura)

            if (!idExterno) return

            //Renovación mensual: se corre la fecha hacia delante. Si no se
            //hiciera, TieneSuscripcionActiva la daría por vencida al pasar
            //la fecha anterior aunque el usuario siga pagando.
            const suscripcionStripe = await stripe().subscriptions.retrieve(idExterno)

            await prisma.suscripcion.updateMany({
                where: { idExterno },
                data: {
                    estado: 'ACTIVA',
                    fechaRenovacion: finDelPeriodo(suscripcionStripe),
                },
            })
            return
        }

        case EVENTOS.IMPAGO: {
            const factura = evento.data.object as Stripe.Invoice
            const idExterno = idSuscripcionDeFactura(factura)

            if (!idExterno) return

            //VENCIDA y no CANCELADA: el usuario no ha pedido irse, es que la
            //tarjeta ha fallado. Stripe seguirá reintentando el cobro, y si
            //acaba entrando, invoice.paid la devolverá a ACTIVA.
            //
            //updateMany y no update porque el where no es la clave primaria.
            await prisma.suscripcion.updateMany({
                where: { idExterno },
                data: { estado: 'VENCIDA' },
            })
            return
        }

        case EVENTOS.CANCELADA: {
            const suscripcionStripe = evento.data.object as Stripe.Subscription

            await prisma.suscripcion.updateMany({
                where: { idExterno: suscripcionStripe.id },
                data: {
                    estado: 'CANCELADA',
                    fechaCancelacion: new Date(),
                },
            })
            return
        }

        default:
            //Stripe manda decenas de tipos de evento. Ignorar los que no nos
            //interesan es lo correcto, pero se deja traza para poder
            //diagnosticar si algún día falta uno.
            console.log('Evento de Stripe ignorado:', evento.type)
    }
}

//El campo current_period_end cambió de sitio entre versiones de la API de
//Stripe: antes colgaba de la suscripción y ahora vive en cada item. Se miran
//los dos para que la integración no se rompa al actualizar el SDK.
function finDelPeriodo(suscripcion: Stripe.Subscription): Date {
    const enSuscripcion = (suscripcion as unknown as { current_period_end?: number })
        .current_period_end
    const enItem = suscripcion.items?.data?.[0]?.current_period_end
    const segundos = enSuscripcion ?? enItem

    //Si Stripe no lo manda, un mes por delante es mejor que null: null haría
    //que el gate diera la suscripción por válida para siempre.
    if (!segundos) {
        return new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
    }

    //Stripe trabaja en segundos Unix; JavaScript en milisegundos.
    return new Date(segundos * 1000)
}

//El id de la suscripción dentro de una factura también ha ido cambiando de
//sitio. Se comprueban las dos formas conocidas.
function idSuscripcionDeFactura(factura: Stripe.Invoice): string | null {
    const directo = (factura as unknown as { subscription?: string | { id: string } })
        .subscription

    if (typeof directo === 'string') return directo
    if (directo && typeof directo === 'object') return directo.id

    const enLinea = factura.lines?.data?.[0] as unknown as
        | { subscription?: string | { id: string } }
        | undefined

    const anidado = enLinea?.subscription

    if (typeof anidado === 'string') return anidado
    if (anidado && typeof anidado === 'object') return anidado.id

    return null
}
