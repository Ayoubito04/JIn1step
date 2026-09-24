//Cliente de Stripe, en un solo sitio para no repetir la construcción.
//
//No se instancia al importar el módulo: si lo hiciéramos, arrancar el
//servidor sin STRIPE_SECRET_KEY reventaría todo el backend aunque solo
//quisieras tocar CVs u ofertas.
import Stripe from 'stripe'
import { env } from '../config/env'
import { HttpError } from './http-error'

let cliente: Stripe | null = null

//503 y no 500: no es que el código falle, es que el servicio de pagos no
//está configurado en este entorno. El cliente puede reintentar más tarde.
export function stripe(): Stripe {
    if (!env.stripeSecretKey) {
        throw new HttpError(503, 'Los pagos no están configurados en este servidor')
    }

    //Se cachea para no crear un cliente nuevo por petición: Stripe mantiene
    //un pool de conexiones HTTP y reconstruirlo lo tira cada vez.
    cliente ??= new Stripe(env.stripeSecretKey)

    return cliente
}

//Traduce nuestro TipoPlan al id de precio de Stripe. El precio vive allí,
//no aquí: así se sube de 5 a 6 euros desde el dashboard sin tocar código
//ni desplegar.
export function precioDeStripe(tipoPlan: 'MENSUAL' | 'ANUAL'): string {
    const id = tipoPlan === 'ANUAL' ? env.stripePriceAnual : env.stripePriceMensual

    if (!id) {
        throw new HttpError(
            503,
            `Falta configurar el precio del plan ${tipoPlan} en Stripe`,
        )
    }

    return id
}

export function secretoWebhook(): string {
    if (!env.stripeWebhookSecret) {
        //Sin secreto no se puede verificar la firma, y aceptar webhooks sin
        //verificar sería dejar que cualquiera active suscripciones gratis.
        //Mejor rechazarlos todos que aceptarlos a ciegas.
        throw new HttpError(503, 'El webhook de pagos no está configurado')
    }

    return env.stripeWebhookSecret
}
