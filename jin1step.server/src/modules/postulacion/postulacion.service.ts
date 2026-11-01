//Ahora nos tocará definir la lógica de este schema,que es la parte de negocio
import path from 'path'
import fs from 'fs/promises'
import { Prisma } from '@prisma/client'
import { prisma } from '../../lib/prisma'
import { HttpError } from '../../lib/http-error'
import { calcularMatch } from './matching.service'
import type {
    ActualizarPostulacionesInput,
    CrearPostulacionesInput,
} from './postulacion.schema'

const CARPETA_SUBIDAS = path.join(__dirname, '../../../uploads')

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
            empresa: {
                select: { id: true, nombre: true, sitioWeb: true },
            },
            requisitos: {
                select: {
                    obligatorio: true,
                    habilidad: { select: { id: true, nombre: true } },
                },
            },
        },
    },
} as const

//Estados que el reclutador NO ve: la candidatura aún no se ha enviado
//(PROPUESTA), se descartó (DESCARTADA) o el candidato la retiró (RETIRADA).
const ESTADOS_OCULTOS_AL_RECLUTADOR = ['PROPUESTA', 'DESCARTADA', 'RETIRADA'] as const

function visibleParaReclutador(estado: string) {
    return !(ESTADOS_OCULTOS_AL_RECLUTADOR as readonly string[]).includes(estado)
}

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
        select: {
            id: true,
            estado: true,
            _count: { select: { requisitos: true } },
        },
    })

    if (!oferta) {
        throw new HttpError(404, 'Oferta no encontrada')
    }

    if (oferta.estado !== 'ABIERTA') {
        throw new HttpError(409, 'Esta oferta ya no admite candidaturas')
    }

    if (oferta._count.requisitos === 0) {
        throw new HttpError(
            409,
            'Esta oferta todavía no tiene requisitos; la empresa debe completarlos antes de aceptar candidaturas',
        )
    }

    //La restricción @@unique de la BD cubre (cvId, ofertaId), pero no llega
    //hasta cv.usuarioId: sin esta comprobación, el candidato podría postularse
    //otra vez a la misma oferta subiendo un CV distinto.
    const yaPostulado = await prisma.postulacion.findFirst({
        where: {
            ofertaId: datos.ofertaId,
            cv: { usuarioId: candidatoId },
        },
        select: { id: true, estado: true },
    })

    if (yaPostulado) {
        //Una propuesta del autopiloto (o una descartada) no es una candidatura
        //enviada: si el candidato se postula a mano, toma el control y esa fila
        //se sustituye por la manual.
        if (yaPostulado.estado !== 'PROPUESTA' && yaPostulado.estado !== 'DESCARTADA') {
            throw new HttpError(409, 'Ya te has postulado a esta oferta')
        }
        await prisma.postulacion.delete({ where: { id: yaPostulado.id } })
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

    //Las retiradas por el candidato no se enseñan al reclutador.
    return prisma.postulacion.findMany({
        where: { ofertaId, estado: { notIn: [...ESTADOS_OCULTOS_AL_RECLUTADOR] } },
        orderBy: [{ matchScore: 'desc' }, { fechaPostulacion: 'asc' }],
        include: CON_CV_Y_OFERTA,
    })
}

//Solo el reclutador dueño de la oferta puede mover el estado.
export async function obtenerCvDePostulacion(
    reclutadorId: string,
    postulacionId: string,
) {
    const postulacion = await prisma.postulacion.findUnique({
        where: { id: postulacionId },
        select: {
            estado: true,
            cv: { select: { id: true, titulo: true, contenidoTexto: true } },
            oferta: { select: { reclutadorId: true } },
        },
    })

    if (
        !postulacion ||
        !visibleParaReclutador(postulacion.estado) ||
        postulacion.oferta.reclutadorId !== reclutadorId
    ) {
        throw new HttpError(404, 'Candidatura no encontrada')
    }

    return postulacion.cv
}

export async function descargarCvDePostulacion(
    reclutadorId: string,
    postulacionId: string,
) {
    const postulacion = await prisma.postulacion.findUnique({
        where: { id: postulacionId },
        select: {
            estado: true,
            cv: { select: { titulo: true, urlArchivo: true } },
            oferta: { select: { reclutadorId: true } },
        },
    })

    if (
        !postulacion ||
        !visibleParaReclutador(postulacion.estado) ||
        postulacion.oferta.reclutadorId !== reclutadorId
    ) {
        throw new HttpError(404, 'Candidatura no encontrada')
    }

    const nombreArchivo = path.basename(postulacion.cv.urlArchivo)
    try {
        const archivo = await fs.readFile(path.join(CARPETA_SUBIDAS, nombreArchivo))
        return { titulo: postulacion.cv.titulo, archivo }
    } catch (error) {
        if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
            throw new HttpError(404, 'El archivo del CV ya no está disponible')
        }
        throw error
    }
}

export async function actualizarEstadoPostulacion(
    reclutadorId: string,
    postulacionId: string,
    datos: ActualizarPostulacionesInput,
) {
    const postulacion = await prisma.postulacion.findUnique({
        where: { id: postulacionId },
        select: {
            id: true,
            estado: true,
            oferta: { select: { reclutadorId: true } },
        },
    })

    if (
        !postulacion ||
        !visibleParaReclutador(postulacion.estado) ||
        postulacion.oferta.reclutadorId !== reclutadorId
    ) {
        throw new HttpError(404, 'Postulación no encontrada')
    }

    return prisma.postulacion.update({
        where: { id: postulacionId },
        data: { estado: datos.estado },
        include: CON_CV_Y_OFERTA,
    })
}

//Candidato: decide sobre una propuesta del autopiloto. Solo se puede aprobar o
//descartar mientras está en PROPUESTA; el 404 es el mismo si no existe o es de
//otro, para no confirmar que el id existe.
async function propuestaDelCandidato(candidatoId: string, postulacionId: string) {
    const postulacion = await prisma.postulacion.findFirst({
        where: { id: postulacionId, cv: { usuarioId: candidatoId } },
        select: {
            id: true,
            estado: true,
            oferta: {
                select: { estado: true, _count: { select: { requisitos: true } } },
            },
        },
    })

    if (!postulacion) {
        throw new HttpError(404, 'Candidatura no encontrada')
    }
    if (postulacion.estado !== 'PROPUESTA') {
        throw new HttpError(409, 'Esta candidatura ya no es una propuesta pendiente')
    }
    return postulacion
}

//Aprobar = enviar. Se vuelve a comprobar la oferta: puede haberse cerrado
//desde que el autopiloto la propuso. Si ya no admite candidaturas, la propuesta
//se descarta en el acto para que no se quede colgada.
export async function aprobarPostulacion(candidatoId: string, postulacionId: string) {
    const postulacion = await propuestaDelCandidato(candidatoId, postulacionId)

    if (postulacion.oferta.estado !== 'ABIERTA' || postulacion.oferta._count.requisitos === 0) {
        await prisma.postulacion.updateMany({
            where: { id: postulacion.id, estado: 'PROPUESTA' },
            data: { estado: 'DESCARTADA' },
        })
        throw new HttpError(409, 'Esta oferta ya no admite candidaturas')
    }

    //El estado va en el where: si dos peticiones aprueban a la vez, solo una gana.
    const { count } = await prisma.postulacion.updateMany({
        where: { id: postulacion.id, estado: 'PROPUESTA' },
        data: { estado: 'ENVIADA' },
    })
    if (count === 0) {
        throw new HttpError(409, 'Esta candidatura ya no es una propuesta pendiente')
    }

    return prisma.postulacion.findUniqueOrThrow({
        where: { id: postulacion.id },
        include: CON_CV_Y_OFERTA,
    })
}

export async function descartarPostulacion(candidatoId: string, postulacionId: string) {
    const postulacion = await propuestaDelCandidato(candidatoId, postulacionId)

    await prisma.postulacion.updateMany({
        where: { id: postulacion.id, estado: 'PROPUESTA' },
        data: { estado: 'DESCARTADA' },
    })

    return prisma.postulacion.findUniqueOrThrow({
        where: { id: postulacion.id },
        include: CON_CV_Y_OFERTA,
    })
}

//El candidato retira su propia candidatura (manual o del autopiloto). No se
//borra: la fila RETIRADA es lo que impide que el autopiloto vuelva a postular
//a esa oferta, porque descarta las ofertas con cualquier postulación previa.
//Solo se puede retirar mientras la empresa no la haya revisado.
export async function retirarPostulacion(
    candidatoId: string,
    postulacionId: string,
) {
    const postulacion = await prisma.postulacion.findFirst({
        where: { id: postulacionId, cv: { usuarioId: candidatoId } },
        select: { id: true, estado: true },
    })

    //Mismo 404 si no existe o es de otro, para no confirmar que el id existe.
    if (!postulacion) {
        throw new HttpError(404, 'Candidatura no encontrada')
    }

    if (postulacion.estado === 'RETIRADA') {
        return prisma.postulacion.findUniqueOrThrow({
            where: { id: postulacion.id },
            include: CON_CV_Y_OFERTA,
        })
    }

    if (postulacion.estado !== 'PENDIENTE' && postulacion.estado !== 'ENVIADA') {
        throw new HttpError(
            409,
            'Solo puedes retirar candidaturas que la empresa aún no ha revisado',
        )
    }

    //updateMany con el estado en el where: si el reclutador la marca como vista
    //justo ahora, no la pisamos.
    const { count } = await prisma.postulacion.updateMany({
        where: {
            id: postulacion.id,
            estado: { in: ['PENDIENTE', 'ENVIADA'] },
        },
        data: { estado: 'RETIRADA' },
    })

    if (count === 0) {
        throw new HttpError(
            409,
            'Solo puedes retirar candidaturas que la empresa aún no ha revisado',
        )
    }

    return prisma.postulacion.findUniqueOrThrow({
        where: { id: postulacion.id },
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
