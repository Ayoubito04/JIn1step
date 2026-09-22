//Ejecuta el autopiloto: lee las preferencias, encuentra Ofertas ABIERTAS que
//encajan con el CV del usuario y crea las postulaciones. Este service SÍ postula.
//Las preferencias las guarda otro módulo (preferencias_autopilot).
import { prisma } from '../../lib/prisma'
import { HttpError } from '../../lib/http-error'
import { obtenerPreferencias } from '../preferencias_autopilot/preferencias_autopilot.service'
import { calcularMatch } from '../postulacion/matching.service'
import { TieneSuscripcionActiva } from '../suscripcion/suscripcion.service'

//maxPorDia es un tope diario, no por sesión. Si el cron se ejecuta dos veces o
//el usuario dispara el endpoint manual varias veces, no debe pasarse. Contamos
//las postulaciones que la IA ya ha creado desde las 00:00 de HOY.
async function postulacionesIaDeHoy(cvId: string) {
    const inicioDia = new Date()
    inicioDia.setHours(0, 0, 0, 0)
    return prisma.postulacion.count({
        where: {
            cvId,
            postuladoPorIa: true,
            fechaPostulacion: { gte: inicioDia },
        },
    })
}

export async function ejecutarAutopilot(usuarioId: string) {
    //Gate de pago. Va ANTES que nada: sin suscripcion activa no se mira ni
    //las preferencias. 402 Payment Required es el codigo exacto para esto.
    if (!(await TieneSuscripcionActiva(usuarioId))) {
        throw new HttpError(
            402,
            'El autopiloto necesita una suscripcion activa',
        )
    }

    const preferencias = await obtenerPreferencias(usuarioId)

    //Un 409 y no un 400: la petición está bien formada, pero el estado actual
    //del recurso (preferencias) no permite ejecutarla.
    if (!preferencias.activo) {
        throw new HttpError(409, 'El autopiloto está desactivado')
    }
    if (!preferencias.cvId) {
        throw new HttpError(409, 'No has asignado un CV al autopiloto')
    }

    //Reverificamos que el CV sigue existiendo y es del usuario: entre PATCH y
    //ejecutar podrían haber pasado semanas, y el usuario podría haberlo borrado.
    const cv = await prisma.cv.findFirst({
        where: { id: preferencias.cvId, usuarioId },
        select: { id: true },
    })
    if (!cv) {
        throw new HttpError(404, 'El CV configurado ya no existe')
    }

    const yaHechasHoy = await postulacionesIaDeHoy(cv.id)
    const restante = preferencias.maxPorDia - yaHechasHoy
    if (restante <= 0) {
        return { creadas: 0, motivo: 'limite_diario_alcanzado' as const, restante: 0 }
    }

    //Ofertas ABIERTAS a las que el usuario aún NO se ha postulado con NINGÚN
    //CV suyo. `postulaciones: { none: { cv: { usuarioId } } }` cubre el caso
    //de haber postulado desde otro CV — el @@unique(cvId, ofertaId) por sí
    //solo no lo evitaría.
    const candidatas = await prisma.oferta.findMany({
        where: {
            estado: 'ABIERTA',
            postulaciones: { none: { cv: { usuarioId } } },
        },
        select: { id: true },
    })

    if (candidatas.length === 0) {
        return { creadas: 0, motivo: 'sin_ofertas_disponibles' as const, restante }
    }

    //calcularMatch es SQL sobre CvHabilidad/OfertaRequisito, no IA. Correr
    //Promise.all sobre las candidatas está bien para volúmenes normales; si
    //hubiera miles de ofertas, aquí es donde habría que prefiltrar.
    const puntuadas = await Promise.all(
        candidatas.map(async (o) => ({
            ofertaId: o.id,
            match: await calcularMatch(cv.id, o.id),
        })),
    )

    const elegibles = puntuadas
        .filter((p) => p.match.puntuacion >= preferencias.scoreMinimo)
        .sort((a, b) => b.match.puntuacion - a.match.puntuacion)
        .slice(0, restante)

    if (elegibles.length === 0) {
        return {
            creadas: 0,
            motivo: 'sin_ofertas_sobre_score_minimo' as const,
            restante,
        }
    }

    //createMany con skipDuplicates es la red final contra carreras (dos
    //pasadas del cron solapadas). El estado se pone a ENVIADA porque la IA
    //no puede dejar postulaciones a medias.
    const resultado = await prisma.postulacion.createMany({
        data: elegibles.map((e) => ({
            cvId: cv.id,
            ofertaId: e.ofertaId,
            matchScore: e.match.puntuacion,
            postuladoPorIa: true,
            estado: 'ENVIADA' as const,
        })),
        skipDuplicates: true,
    })

    return {
        creadas: resultado.count,
        restante: restante - resultado.count,
        elegidas: elegibles.map((e) => ({
            ofertaId: e.ofertaId,
            score: e.match.puntuacion,
        })),
    }
}
