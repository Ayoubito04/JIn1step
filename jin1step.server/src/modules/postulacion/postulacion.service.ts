//Ahora nos tocará definir la lógica de este schema,que es la parte de negocio
import { Prisma } from '@prisma/client'
import { prisma } from '../../lib/prisma'
import { HttpError } from '../../lib/http-error'
import { calcularMatch } from './matching.service'
import type {
    ActualizarPostulacionesInput,
    CrearPostulacionesInput,
} from './postulacion.schema'

//Lo que se enseña de cada postulación. Como en ofertas, es un select explícito
//para no devolver la fila entera de Usuario (passwordHash incluido).
const CON_CV_Y_OFERTA = {
    cv: {
        select: {
            id: true,
            titulo: true,
            usuario: { select: { id: true, nombre: true, apellidos: true } },
        },
    },
    oferta: {
        select: {
            id: true,
            titulo: true,
            modalidad: true,
            estado: true,
            reclutadorId: true,
            empresa: { select: { id: true, nombre: true } },
        },
    },
} as const

//Comprueba que el CV es de quien dice serlo. Se usa el mismo 404 que si no
//existiera: un 403 confirmaría que ese id existe y es de otro.
async function cvDelCandidato(candidatoId: string, cvId: string) {
    const cv = await prisma.cv.findUnique({
        where: { id: cvId },
        select: { id: true, usuarioId: true },
    })

    if (!cv || cv.usuarioId !== candidatoId) {
        throw new HttpError(404, 'CV no encontrado')
    }

    return cv
}

export async function crearPostulacion(
    candidatoId: string,
    datos: CrearPostulacionesInput,
    postuladoPorIa = false,
) {
    const cv = await cvDelCandidato(candidatoId, datos.cvId)

    const oferta = await prisma.oferta.findUnique({
        where: { id: datos.ofertaId },
        select: { id: true, estado: true },
    })

    if (!oferta) {
        throw new HttpError(404, 'Oferta no encontrada')
    }

    if (oferta.estado !== 'ABIERTA') {
        throw new HttpError(409, 'Esta oferta ya no admite candidaturas')
    }

    //La restricción @@unique de la BD cubre (cvId, ofertaId), pero no llega
    //hasta cv.usuarioId: sin esta comprobación, el candidato podría postularse
    //otra vez a la misma oferta subiendo un CV distinto.
    const yaPostulado = await prisma.postulacion.findFirst({
        where: {
            ofertaId: datos.ofertaId,
            cv: { usuarioId: candidatoId },
        },
        select: { id: true },
    })

    if (yaPostulado) {
        throw new HttpError(409, 'Ya te has postulado a esta oferta')
    }

    //El score se calcula aquí, nunca llega del cliente
    const match = await calcularMatch(cv.id, oferta.id)

    try {
        const postulacion = await prisma.postulacion.create({
            data: {
                cvId: cv.id,
                ofertaId: oferta.id,
                matchScore: match.puntuacion,
                postuladoPorIa,
            },
            include: CON_CV_Y_OFERTA,
        })

        return { ...postulacion, detalleMatch: match }
    } catch (err) {
        //P2002 = violación de índice único. Solo se llega aquí si dos peticiones
        //entran a la vez y ambas pasan la comprobación de arriba antes de que
        //ninguna haya insertado. La BD resuelve la carrera.
        if (
            err instanceof Prisma.PrismaClientKnownRequestError &&
            err.code === 'P2002'
        ) {
            throw new HttpError(409, 'Ya te has postulado a esta oferta')
        }

        throw err
    }
}

//Las postulaciones del candidato.
export async function listarPostulacionesDeCandidato(candidatoId: string) {
    return prisma.postulacion.findMany({
        where: { cv: { usuarioId: candidatoId } },
        orderBy: { fechaPostulacion: 'desc' },
        include: CON_CV_Y_OFERTA,
    })
}

//Las postulaciones que ha recibido una oferta. Ordenadas por matchScore: es el
//orden en el que le interesa mirarlas al reclutador.
export async function listarPostulacionesDeOferta(
    reclutadorId: string,
    ofertaId: string,
) {
    const oferta = await prisma.oferta.findUnique({
        where: { id: ofertaId },
        select: { id: true, reclutadorId: true },
    })

    if (!oferta || oferta.reclutadorId !== reclutadorId) {
        throw new HttpError(404, 'Oferta no encontrada')
    }

    return prisma.postulacion.findMany({
        where: { ofertaId },
        orderBy: [{ matchScore: 'desc' }, { fechaPostulacion: 'asc' }],
        include: CON_CV_Y_OFERTA,
    })
}

//Solo el reclutador dueño de la oferta puede mover el estado.
export async function actualizarEstadoPostulacion(
    reclutadorId: string,
    postulacionId: string,
    datos: ActualizarPostulacionesInput,
) {
    const postulacion = await prisma.postulacion.findUnique({
        where: { id: postulacionId },
        select: { id: true, oferta: { select: { reclutadorId: true } } },
    })

    if (!postulacion || postulacion.oferta.reclutadorId !== reclutadorId) {
        throw new HttpError(404, 'Postulación no encontrada')
    }

    return prisma.postulacion.update({
        where: { id: postulacionId },
        data: { estado: datos.estado },
        include: CON_CV_Y_OFERTA,
    })
}

//Simula el match sin crear nada: el candidato ve qué le falta antes de decidir.
export async function simularMatch(
    candidatoId: string,
    cvId: string,
    ofertaId: string,
) {
    const cv = await cvDelCandidato(candidatoId, cvId)

    const oferta = await prisma.oferta.findUnique({
        where: { id: ofertaId },
        select: { id: true },
    })

    if (!oferta) {
        throw new HttpError(404, 'Oferta no encontrada')
    }

    return calcularMatch(cv.id, oferta.id)
}
