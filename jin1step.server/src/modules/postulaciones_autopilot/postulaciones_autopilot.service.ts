//Ejecuta el autopiloto: lee las preferencias, encuentra Ofertas ABIERTAS que
//encajan con el CV del usuario y crea las postulaciones. Este service SÍ postula.
//Las preferencias las guarda otro módulo (preferencias_autopilot).
//
//Cómo se eligen las ofertas: si hay IA configurada y el CV tiene texto, la IA
//lee el CV completo y valora las ofertas (palabras clave/ATS, seniority...).
//Si no hay IA o falla, se usa el match por habilidades (SQL) de siempre. En
//ambos casos las reglas (suscripción, consentimiento, puntuación mínima y
//tope diario) las aplica este archivo, nunca la IA.
import { prisma } from '../../lib/prisma'
import { HttpError } from '../../lib/http-error'
import { iaDisponible } from '../../lib/ia'
import { obtenerPreferencias } from '../preferencias_autopilot/preferencias_autopilot.service'
import { calcularMatch } from '../postulacion/matching.service'
import { TieneSuscripcionActiva } from '../suscripcion/suscripcion.service'
import {
    MAX_OFERTAS_IA,
    obtenerPerfilCv,
    preseleccionarPorPalabrasClave,
    redactarCartas,
    valorarOfertas,
} from './valoracion_ia.service'

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

type CvAutopilot = {
    id: string
    contenidoTexto: string | null
    perfilIa: unknown
    perfilIaHash: string | null
}

async function cargarCv(cvId: string, usuarioId: string) {
    //Reverificamos que el CV sigue existiendo y es del usuario: entre PATCH y
    //ejecutar podrían haber pasado semanas, y el usuario podría haberlo borrado.
    const cv = await prisma.cv.findFirst({
        where: { id: cvId, usuarioId },
        select: { id: true, contenidoTexto: true, perfilIa: true, perfilIaHash: true },
    })
    if (!cv) {
        throw new HttpError(404, 'El CV configurado ya no existe')
    }
    return cv
}

type OfertaCandidata = Awaited<ReturnType<typeof buscarCandidatas>>[number]

//Ofertas ABIERTAS a las que el usuario aún NO se ha postulado con NINGÚN
//CV suyo. `postulaciones: { none: { cv: { usuarioId } } }` cubre el caso
//de haber postulado desde otro CV — el @@unique(cvId, ofertaId) por sí
//solo no lo evitaría.
function buscarCandidatas(usuarioId: string) {
    return prisma.oferta.findMany({
        where: {
            estado: 'ABIERTA',
            postulaciones: { none: { cv: { usuarioId } } },
        },
        select: {
            id: true,
            titulo: true,
            descripcion: true,
            modalidad: true,
            empresa: { select: { nombre: true, ubicacion: true } },
            requisitos: {
                select: { obligatorio: true, habilidad: { select: { nombre: true } } },
            },
        },
    })
}

type Elegida = {
    oferta: OfertaCandidata
    //Match por habilidades (SQL). Es lo que se guarda en Postulacion.matchScore.
    matchScore: number
    //Solo cuando la IA valoró la oferta.
    puntuacionIa: number | null
    motivoIa: string | null
    cartaIa: string | null
    palabrasClaveCubiertas: string[]
    palabrasClaveFaltantes: string[]
}

type Seleccion = {
    elegidas: Elegida[]
    via: 'ia' | 'habilidades'
    //Cuántas ofertas se valoraron en la pasada (para el historial).
    evaluadas: number
    motivoVacio: 'sin_ofertas_disponibles' | 'sin_ofertas_sobre_score_minimo' | null
}

type Origen = 'MANUAL' | 'DIARIA'

//Lo que el servicio puede contestar cuando no crea nada.
type MotivoVacio =
    | 'limite_diario_alcanzado'
    | 'propuestas_pendientes'
    | 'sin_ofertas_disponibles'
    | 'sin_ofertas_sobre_score_minimo'

//Puntuación con la que se ordena y se muestra: la de la IA si existe.
const puntuacionFinal = (e: Elegida) => e.puntuacionIa ?? e.matchScore

async function seleccionarConIa(
    cv: CvAutopilot & { contenidoTexto: string },
    candidatas: OfertaCandidata[],
    matches: Map<string, number>,
    scoreMinimo: number,
    restante: number,
    conCartas: boolean,
): Promise<{ elegidas: Elegida[]; evaluadas: number }> {
    const perfil = await obtenerPerfilCv(cv)
    const paraIa = preseleccionarPorPalabrasClave(perfil, candidatas, MAX_OFERTAS_IA)
    const valoraciones = await valorarOfertas(cv.contenidoTexto, perfil, paraIa)

    const porId = new Map(paraIa.map((o) => [o.id, o]))
    const elegibles = valoraciones
        .filter((v) => v.puntuacion >= scoreMinimo)
        .sort((a, b) => b.puntuacion - a.puntuacion)
        .slice(0, restante)

    const cartas = conCartas
        ? await redactarCartas(
              cv.contenidoTexto,
              perfil,
              elegibles.map((v) => porId.get(v.ofertaId)!),
          )
        : new Map<string, string>()

    const elegidas = elegibles.map((v) => ({
        oferta: porId.get(v.ofertaId)!,
        matchScore: matches.get(v.ofertaId) ?? 0,
        puntuacionIa: v.puntuacion,
        motivoIa: v.motivo,
        cartaIa: cartas.get(v.ofertaId) ?? null,
        palabrasClaveCubiertas: v.palabrasClaveCubiertas,
        palabrasClaveFaltantes: v.palabrasClaveFaltantes,
    }))
    return { elegidas, evaluadas: valoraciones.length }
}

async function seleccionarOfertas(
    usuarioId: string,
    cv: CvAutopilot,
    scoreMinimo: number,
    restante: number,
    conCartas: boolean,
): Promise<Seleccion> {
    const candidatas = await buscarCandidatas(usuarioId)
    if (candidatas.length === 0) {
        return {
            elegidas: [],
            via: 'habilidades',
            evaluadas: 0,
            motivoVacio: 'sin_ofertas_disponibles',
        }
    }

    //calcularMatch es SQL sobre CvHabilidad/OfertaRequisito, no IA. Se calcula
    //siempre: es el match rating que se guarda y el plan B si la IA falla.
    const puntuadas = await Promise.all(
        candidatas.map(async (oferta) => ({
            oferta,
            match: await calcularMatch(cv.id, oferta.id),
        })),
    )
    const matches = new Map(puntuadas.map((p) => [p.oferta.id, p.match.puntuacion]))

    if (iaDisponible() && cv.contenidoTexto) {
        try {
            const { elegidas, evaluadas } = await seleccionarConIa(
                { ...cv, contenidoTexto: cv.contenidoTexto },
                candidatas,
                matches,
                scoreMinimo,
                restante,
                conCartas,
            )
            return {
                elegidas,
                via: 'ia',
                evaluadas,
                motivoVacio:
                    elegidas.length === 0 ? 'sin_ofertas_sobre_score_minimo' : null,
            }
        } catch (error) {
            //Un fallo de la IA (clave, cuota, timeout, JSON inválido) no debe
            //dejar al usuario sin pasada: se cae al match por habilidades.
            console.error('Fallo de la IA en el autopiloto, uso match por habilidades:', error)
        }
    }

    const elegidas: Elegida[] = puntuadas
        .filter(
            ({ match }) =>
                !match.sinRequisitos && match.puntuacion >= scoreMinimo,
        )
        .sort((a, b) => b.match.puntuacion - a.match.puntuacion)
        .slice(0, restante)
        .map(({ oferta, match }) => ({
            oferta,
            matchScore: match.puntuacion,
            puntuacionIa: null,
            motivoIa: null,
            cartaIa: null,
            palabrasClaveCubiertas: [],
            palabrasClaveFaltantes: [],
        }))

    return {
        elegidas,
        via: 'habilidades',
        evaluadas: candidatas.length,
        motivoVacio: elegidas.length === 0 ? 'sin_ofertas_sobre_score_minimo' : null,
    }
}

//Cuántas propuestas siguen esperando la decisión del candidato.
async function propuestasPendientes(usuarioId: string) {
    return prisma.postulacion.count({
        where: { estado: 'PROPUESTA', cv: { usuarioId } },
    })
}

//Deja constancia de la pasada en el historial. Un fallo al escribirlo no debe
//romper la pasada, que ya hizo su trabajo.
async function registrarEjecucion(datos: {
    usuarioId: string
    origen: Origen
    revisarAntes: boolean
    evaluadas: number
    creadas: number
    via: 'ia' | 'habilidades' | null
    motivo: MotivoVacio | null
}) {
    try {
        await prisma.ejecucionAutopilot.create({
            data: {
                usuarioId: datos.usuarioId,
                origen: datos.origen,
                modo: datos.revisarAntes ? 'REVISION' : 'AUTOMATICO',
                evaluadas: datos.evaluadas,
                propuestas: datos.revisarAntes ? datos.creadas : 0,
                enviadas: datos.revisarAntes ? 0 : datos.creadas,
                via: datos.via,
                motivo: datos.motivo,
            },
        })
    } catch (error) {
        console.error('No se pudo registrar la ejecución del autopiloto:', error)
    }
}

export async function ejecutarAutopilot(usuarioId: string, origen: Origen = 'MANUAL') {
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

    const cv = await cargarCv(preferencias.cvId, usuarioId)
    const revisarAntes = preferencias.revisarAntes
    const modo = revisarAntes ? ('REVISION' as const) : ('AUTOMATICO' as const)

    const vacia = async (motivo: MotivoVacio, restante: number) => {
        await registrarEjecucion({
            usuarioId,
            origen,
            revisarAntes,
            evaluadas: 0,
            creadas: 0,
            via: null,
            motivo,
        })
        return { creadas: 0, motivo, restante, modo }
    }

    const yaHechasHoy = await postulacionesIaDeHoy(cv.id)
    const restante = preferencias.maxPorDia - yaHechasHoy
    if (restante <= 0) {
        return vacia('limite_diario_alcanzado', 0)
    }

    //En modo revisión no se amontonan propuestas: si ya hay tantas sin revisar
    //como el máximo diario, se espera a que el candidato decida.
    if (revisarAntes && (await propuestasPendientes(usuarioId)) >= preferencias.maxPorDia) {
        return vacia('propuestas_pendientes', restante)
    }

    const { elegidas, via, evaluadas, motivoVacio } = await seleccionarOfertas(
        usuarioId,
        cv,
        preferencias.scoreMinimo,
        restante,
        true,
    )

    if (elegidas.length === 0) {
        const motivo = motivoVacio ?? 'sin_ofertas_sobre_score_minimo'
        await registrarEjecucion({
            usuarioId,
            origen,
            revisarAntes,
            evaluadas,
            creadas: 0,
            via,
            motivo,
        })
        return { creadas: 0, motivo, restante, modo }
    }

    //createMany con skipDuplicates es la red final contra carreras (dos
    //pasadas del cron solapadas). En modo revisión nacen como PROPUESTA: la
    //empresa no las ve hasta que el candidato las aprueba. En modo automático
    //salen directamente como ENVIADA.
    const resultado = await prisma.postulacion.createMany({
        data: elegidas.map((e) => ({
            cvId: cv.id,
            ofertaId: e.oferta.id,
            matchScore: e.matchScore,
            puntuacionIa: e.puntuacionIa,
            motivoIa: e.motivoIa,
            cartaIa: e.cartaIa,
            palabrasClaveCubiertas: e.palabrasClaveCubiertas,
            palabrasClaveFaltantes: e.palabrasClaveFaltantes,
            postuladoPorIa: true,
            estado: revisarAntes ? ('PROPUESTA' as const) : ('ENVIADA' as const),
        })),
        skipDuplicates: true,
    })

    await registrarEjecucion({
        usuarioId,
        origen,
        revisarAntes,
        evaluadas,
        creadas: resultado.count,
        via,
        motivo: null,
    })

    return {
        creadas: resultado.count,
        restante: restante - resultado.count,
        modo,
        via,
        elegidas: elegidas.map((e) => ({
            ofertaId: e.oferta.id,
            score: puntuacionFinal(e),
        })),
    }
}

//Las últimas pasadas del autopiloto del usuario, de la más reciente a la más
//antigua.
export async function obtenerHistorialAutopilot(usuarioId: string) {
    return prisma.ejecucionAutopilot.findMany({
        where: { usuarioId },
        orderBy: { fecha: 'desc' },
        take: 30,
        select: {
            id: true,
            fecha: true,
            origen: true,
            modo: true,
            evaluadas: true,
            propuestas: true,
            enviadas: true,
            via: true,
            motivo: true,
        },
    })
}

// Previsualización local: usa las mismas reglas de compatibilidad que la
// ejecución real, pero no escribe en la base de datos ni exige suscripción.
// No redacta cartas (cuestan una llamada más a la IA). Solo se monta en
// entornos distintos de producción.
export async function previsualizarAutopilot(usuarioId: string) {
    const preferencias = await obtenerPreferencias(usuarioId)
    if (!preferencias.cvId) {
        throw new HttpError(409, 'Asigna un CV para simular el autopiloto')
    }

    const cv = await cargarCv(preferencias.cvId, usuarioId)

    const yaHechasHoy = await postulacionesIaDeHoy(cv.id)
    const restante = preferencias.maxPorDia - yaHechasHoy
    if (restante <= 0) {
        return {
            ofertas: [],
            restantesHoy: 0,
            motivo: 'limite_diario_alcanzado' as const,
        }
    }

    const { elegidas, via, motivoVacio } = await seleccionarOfertas(
        usuarioId,
        cv,
        preferencias.scoreMinimo,
        restante,
        false,
    )

    return {
        ofertas: elegidas.map((e) => ({
            ofertaId: e.oferta.id,
            titulo: e.oferta.titulo,
            empresa: e.oferta.empresa.nombre,
            ubicacion: e.oferta.empresa.ubicacion,
            modalidad: e.oferta.modalidad,
            score: puntuacionFinal(e),
            matchScore: e.matchScore,
            motivoIa: e.motivoIa,
            palabrasClaveCubiertas: e.palabrasClaveCubiertas,
            palabrasClaveFaltantes: e.palabrasClaveFaltantes,
        })),
        restantesHoy: restante,
        via,
        motivo: motivoVacio,
    }
}

// Trabajo diario del servidor. Ejecuta únicamente preferencias activas con un
// CV asignado; ejecutarAutopilot vuelve a validar suscripción, CV y límites.
// El recorrido secuencial limita la carga sobre la base de datos.
export async function ejecutarAutopilotsActivos() {
    const preferencias = await prisma.preferenciasAutopilot.findMany({
        where: { activo: true, cvId: { not: null } },
        select: { usuarioId: true },
    })

    let candidaturasCreadas = 0
    let fallos = 0

    for (const { usuarioId } of preferencias) {
        try {
            const resultado = await ejecutarAutopilot(usuarioId, 'DIARIA')
            candidaturasCreadas += resultado.creadas
        } catch (error) {
            // Un usuario sin suscripción vigente o con datos obsoletos no debe
            // impedir que el resto de candidatos reciban su pasada diaria.
            fallos += 1
            console.error('No se pudo ejecutar una pasada del autopiloto:', error)
        }
    }

    return { usuariosProcesados: preferencias.length, candidaturasCreadas, fallos }
}
