import { Prisma } from '@prisma/client'
import { prisma } from '../../lib/prisma'
import { HttpError } from '../../lib/http-error'
import type {
    CancelarSuscripcionInput,
    IniciarSuscripcionInput,
    TipoPlanInput,
} from './suscripcion.schema'

// Precio de cada plan, en céntimos y decidido por el SERVIDOR.
// El cliente elige el plan; lo que cuesta no lo negocia.
// ANUAL = 10 meses: dos meses de regalo por pagar por adelantado.
const PRECIOS_CENTIMOS: Record<TipoPlanInput, number> = {
    MENSUAL: 500,
    ANUAL: 5000,
}

// Objeto directo para usarlo en el "select" de Prisma (sin corchetes de array).
// Los nombres son los del modelo en camelCase: el @map("tipo_plan") solo
// afecta a cómo se llama la columna en Postgres, no a la API de TypeScript.
export const CamposPublicos = {
    id: true,
    tipoPlan: true,
    estado: true,
    proveedorPago: true,
    precioCentimos: true,
    fechaInicio: true,
    fechaRenovacion: true,
    fechaCancelacion: true,
} as const

export const CrearSuscripcion = async (
    idUsuario: string,
    datos: IniciarSuscripcionInput,
) => {
    const usuarioExiste = await prisma.usuario.findUnique({
        where: { id: idUsuario },
        select: { id: true },
    })

    if (!usuarioExiste) {
        throw new HttpError(404, 'El usuario no existe')
    }

    // Si ya tiene una ACTIVA no tiene sentido arrancar otra alta. El índice
    // parcial de la BD lo impediría igualmente, pero así el mensaje es claro
    // en vez de un 500 por violación de constraint.
    const yaActiva = await prisma.suscripcion.findFirst({
        where: { usuarioId: idUsuario, estado: 'ACTIVA' },
        select: { id: true },
    })

    if (yaActiva) {
        throw new HttpError(409, 'Ya tienes una suscripción activa')
    }

    try {
        return await prisma.suscripcion.create({
            data: {
                usuarioId: idUsuario,
                tipoPlan: datos.tipoPlan,
                proveedorPago: datos.proveedorPago,

                // El precio sale del mapa del servidor, NO del body. Si
                // viniera del cliente se pagaría 1 céntimo al mes.
                precioCentimos: PRECIOS_CENTIMOS[datos.tipoPlan],

                // estado se deja al @default(PENDIENTE_PAGO) del modelo.
                // Solo el webhook firmado de la pasarela puede ponerlo en
                // ACTIVA, nunca esta función ni el cliente.

                // idExterno se queda a null: todavía no hemos hablado con la
                // pasarela, así que aún no existe el subscription id.
                // fechaRenovacion la manda la pasarela al confirmar el cobro.
            },
            select: CamposPublicos,
        })
    } catch (err) {
        // P2002 = índice único. Cubre la carrera de dos peticiones simultáneas
        // que pasen la comprobación de arriba antes de que ninguna inserte.
        if (
            err instanceof Prisma.PrismaClientKnownRequestError &&
            err.code === 'P2002'
        ) {
            throw new HttpError(409, 'Ya tienes una suscripción activa')
        }
        throw err
    }
}

// La suscripción ACTIVA del usuario, o null si no tiene.
// El índice parcial suscripciones_una_activa_por_usuario garantiza que como
// mucho hay una, así que findFirst no es ambiguo.
export const ObtenerSuscripcionActiva = async (idUsuario: string) => {
    return prisma.suscripcion.findFirst({
        where: { usuarioId: idUsuario, estado: 'ACTIVA' },
        select: CamposPublicos,
    })
}

// Gate del autopiloto. Devuelve true solo si hay una ACTIVA y además no se le
// ha pasado la fecha de renovación: si Stripe dejó de cobrar y el webhook de
// impago no llegó, la fila puede seguir en ACTIVA siendo ya papel mojado.
export const TieneSuscripcionActiva = async (idUsuario: string) => {
    const activa = await prisma.suscripcion.findFirst({
        where: {
            usuarioId: idUsuario,
            estado: 'ACTIVA',
            // null = todavía no ha habido primera renovación, se da por buena.
            OR: [{ fechaRenovacion: null }, { fechaRenovacion: { gte: new Date() } }],
        },
        select: { id: true },
    })
    return activa !== null
}

// Historial completo, lo más reciente primero. Un usuario acumula filas con el
// tiempo (alta, cancelación, alta nueva...) y le sirve para ver sus facturas.
export const ListarMisSuscripciones = async (idUsuario: string) => {
    return prisma.suscripcion.findMany({
        where: { usuarioId: idUsuario },
        select: CamposPublicos,
        orderBy: { fechaInicio: 'desc' },
    })
}

// Cancela la suscripción ACTIVA del usuario del token. No recibe id a
// propósito: aceptarlo permitiría cancelar la de otro.
//
// alFinalDelPeriodo=true (lo normal y lo que espera la ley de consumo de la
// UE) deja el estado en ACTIVA y solo anota la fecha: el usuario conserva el
// servicio hasta que termine lo que ya pagó, y es el webhook de la pasarela
// quien la pasará a CANCELADA cuando venza de verdad.
//
// false corta ya: pasa a CANCELADA y el gate deja de dejarle pasar.
export const CancelarSuscripcion = async (
    idUsuario: string,
    datos: CancelarSuscripcionInput,
) => {
    const activa = await prisma.suscripcion.findFirst({
        where: { usuarioId: idUsuario, estado: 'ACTIVA' },
        select: { id: true },
    })

    if (!activa) {
        throw new HttpError(404, 'No tienes ninguna suscripción activa')
    }

    return prisma.suscripcion.update({
        where: { id: activa.id },
        data: {
            fechaCancelacion: new Date(),
            ...(datos.alFinalDelPeriodo ? {} : { estado: 'CANCELADA' as const }),
        },
        select: CamposPublicos,
    })
}

// La llama el WEBHOOK, nunca un endpoint del usuario, y solo después de haber
// verificado la firma de la pasarela. Es el único sitio donde una suscripción
// pasa a ACTIVA.
//
// Es idempotente: los webhooks llegan duplicados y desordenados por diseño, y
// el @unique de idExterno hace que el mismo evento reintentado no cree una
// segunda fila. Si ya estaba ACTIVA, se devuelve tal cual sin tocar nada.
export const ActivarPorWebhook = async (
    idSuscripcion: string,
    idExterno: string,
    fechaRenovacion: Date,
) => {
    const suscripcion = await prisma.suscripcion.findUnique({
        where: { id: idSuscripcion },
        select: { id: true, estado: true },
    })

    if (!suscripcion) {
        throw new HttpError(404, 'Suscripción no encontrada')
    }

    if (suscripcion.estado === 'ACTIVA') {
        return prisma.suscripcion.findUniqueOrThrow({
            where: { id: idSuscripcion },
            select: CamposPublicos,
        })
    }

    try {
        return await prisma.suscripcion.update({
            where: { id: idSuscripcion },
            data: { estado: 'ACTIVA', idExterno, fechaRenovacion },
            select: CamposPublicos,
        })
    } catch (err) {
        if (
            err instanceof Prisma.PrismaClientKnownRequestError &&
            err.code === 'P2002'
        ) {
            throw new HttpError(409, 'Este pago ya estaba registrado')
        }
        throw err
    }
}
