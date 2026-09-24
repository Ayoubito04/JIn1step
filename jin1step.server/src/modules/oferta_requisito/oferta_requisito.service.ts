//Lógica de los requisitos de una oferta.
//
//Es la pieza que hacía falta para que el matching signifique algo: sin
//requisitos, calcularMatch devuelve 100 a todo el mundo (ver el comentario de
//matching.service.ts sobre ofertas sin requisitos), así que el autopiloto se
//postularía a cualquier oferta creada desde la API.
import { Prisma } from '@prisma/client'
import { prisma } from '../../lib/prisma'
import { HttpError } from '../../lib/http-error'
import type {
    ActualizarRequisitoInput,
    AnadirRequisitoInput,
    ReemplazarRequisitosInput,
} from './oferta_requisito.schema'

const CON_HABILIDAD = {
    ofertaId: true,
    habilidadId: true,
    obligatorio: true,
    habilidad: { select: { id: true, nombre: true } },
} as const

//Comprueba que la oferta existe Y es del reclutador. Mismo 404 en los dos
//casos: un 403 confirmaría que esa oferta existe y es de alguien.
async function ofertaDelReclutador(reclutadorId: string, ofertaId: string) {
    const oferta = await prisma.oferta.findUnique({
        where: { id: ofertaId },
        select: { id: true, reclutadorId: true },
    })

    if (!oferta || oferta.reclutadorId !== reclutadorId) {
        throw new HttpError(404, 'Oferta no encontrada')
    }

    return oferta
}

//Lectura pública: el candidato necesita ver qué le piden ANTES de postularse.
//No lleva comprobación de dueño a propósito, pero sí de existencia, para no
//devolver una lista vacía indistinguible de "esa oferta no existe".
export async function listarRequisitos(ofertaId: string) {
    const oferta = await prisma.oferta.findUnique({
        where: { id: ofertaId },
        select: { id: true },
    })

    if (!oferta) {
        throw new HttpError(404, 'Oferta no encontrada')
    }

    return prisma.ofertaRequisito.findMany({
        where: { ofertaId },
        select: CON_HABILIDAD,
        //Las obligatorias primero: es el orden en que le interesan al
        //candidato, que quiere saber ya si le falta algo imprescindible.
        orderBy: [{ obligatorio: 'desc' }, { habilidad: { nombre: 'asc' } }],
    })
}

export async function anadirRequisito(
    reclutadorId: string,
    ofertaId: string,
    datos: AnadirRequisitoInput,
) {
    await ofertaDelReclutador(reclutadorId, ofertaId)

    //La habilidad tiene que existir en el catálogo. Sin esto, un habilidadId
    //inventado daría un P2003 de clave foránea que sale como 500.
    const habilidad = await prisma.habilidad.findUnique({
        where: { id: datos.habilidadId },
        select: { id: true },
    })

    if (!habilidad) {
        throw new HttpError(404, 'Habilidad no encontrada')
    }

    try {
        return await prisma.ofertaRequisito.create({
            data: {
                ofertaId,
                habilidadId: datos.habilidadId,
                obligatorio: datos.obligatorio,
            },
            select: CON_HABILIDAD,
        })
    } catch (err) {
        //P2002 = el @@id([ofertaId, habilidadId]). Ya estaba pedida esa
        //habilidad; para cambiarle el peso está el PATCH.
        if (
            err instanceof Prisma.PrismaClientKnownRequestError &&
            err.code === 'P2002'
        ) {
            throw new HttpError(409, 'Esa habilidad ya es requisito de la oferta')
        }
        throw err
    }
}

export async function actualizarRequisito(
    reclutadorId: string,
    ofertaId: string,
    habilidadId: string,
    datos: ActualizarRequisitoInput,
) {
    await ofertaDelReclutador(reclutadorId, ofertaId)

    try {
        return await prisma.ofertaRequisito.update({
            where: { ofertaId_habilidadId: { ofertaId, habilidadId } },
            data: { obligatorio: datos.obligatorio },
            select: CON_HABILIDAD,
        })
    } catch (err) {
        //P2025 = no existe esa fila. La oferta ya se ha comprobado que es
        //suya, así que el 404 se refiere al requisito.
        if (
            err instanceof Prisma.PrismaClientKnownRequestError &&
            err.code === 'P2025'
        ) {
            throw new HttpError(404, 'Ese requisito no está en la oferta')
        }
        throw err
    }
}

export async function quitarRequisito(
    reclutadorId: string,
    ofertaId: string,
    habilidadId: string,
) {
    await ofertaDelReclutador(reclutadorId, ofertaId)

    try {
        await prisma.ofertaRequisito.delete({
            where: { ofertaId_habilidadId: { ofertaId, habilidadId } },
        })
    } catch (err) {
        if (
            err instanceof Prisma.PrismaClientKnownRequestError &&
            err.code === 'P2025'
        ) {
            throw new HttpError(404, 'Ese requisito no está en la oferta')
        }
        throw err
    }
}

//Reemplaza TODOS los requisitos de golpe. Es lo que necesita el formulario de
//edición: el reclutador marca las habilidades que quiere y manda el conjunto
//final, sin tener que calcular qué ha añadido y qué ha quitado.
//
//Va en una transacción porque el borrado y el alta tienen que ser atómicos:
//si fallara a medias, la oferta se quedaría sin requisitos y calcularMatch
//empezaría a devolver 100 a todo el mundo.
export async function reemplazarRequisitos(
    reclutadorId: string,
    ofertaId: string,
    datos: ReemplazarRequisitosInput,
) {
    await ofertaDelReclutador(reclutadorId, ofertaId)

    //Todas las habilidades tienen que existir. Se comprueban de una sola
    //consulta en vez de una por requisito.
    const ids = datos.requisitos.map((r) => r.habilidadId)
    const encontradas = await prisma.habilidad.count({
        where: { id: { in: ids } },
    })

    if (encontradas !== ids.length) {
        throw new HttpError(404, 'Alguna de las habilidades no existe')
    }

    await prisma.$transaction([
        prisma.ofertaRequisito.deleteMany({ where: { ofertaId } }),
        prisma.ofertaRequisito.createMany({
            data: datos.requisitos.map((r) => ({
                ofertaId,
                habilidadId: r.habilidadId,
                obligatorio: r.obligatorio,
            })),
        }),
    ])

    return listarRequisitos(ofertaId)
}
