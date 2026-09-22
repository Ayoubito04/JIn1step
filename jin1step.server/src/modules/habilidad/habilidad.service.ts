//Lógica de habilidades por CV: ajustes MANUALES sobre la detección
//automática que ya hace extraccion.service.ts al subir un CV.
//El catálogo Habilidad se toca en modo lectura únicamente.
import { Prisma } from '@prisma/client'
import { prisma } from '../../lib/prisma'
import { HttpError } from '../../lib/http-error'
import type {
    ActualizarNivelInput,
    AsignarHabilidadInput,
} from './habilidad.schema'

//Verifica que el CV existe Y pertenece al usuario. Devolver 404 y no 403
//cuando es de otro evita filtrar la existencia del id (mismo patrón que en
//postulacion.service.ts).
async function cvDelCandidato(usuarioId: string, cvId: string) {
    const cv = await prisma.cv.findFirst({
        where: { id: cvId, usuarioId },
        select: { id: true },
    })

    if (!cv) {
        throw new HttpError(404, 'CV no encontrado')
    }

    return cv
}

//Catálogo global. Se usa desde el frontend para pintar un dropdown y desde
//los reclutadores para crear requisitos. Sin auth añade valor cero, así que
//protegemos igual desde routes.
export async function listarCatalogo() {
    return prisma.habilidad.findMany({
        select: { id: true, nombre: true },
        orderBy: { nombre: 'asc' },
    })
}

export async function listarHabilidadesDeCv(usuarioId: string, cvId: string) {
    await cvDelCandidato(usuarioId, cvId)

    return prisma.cvHabilidad.findMany({
        where: { cvId },
        include: { habilidad: { select: { id: true, nombre: true } } },
        orderBy: { habilidad: { nombre: 'asc' } },
    })
}

//Enlaza una habilidad del catálogo con el CV. No acepta "nombre" libre a
//propósito: obligar a que venga habilidadId impide que un candidato cree
//"TypeScrit" (con typo) en la tabla compartida.
export async function asignarHabilidadACv(
    usuarioId: string,
    cvId: string,
    datos: AsignarHabilidadInput,
) {
    await cvDelCandidato(usuarioId, cvId)

    const habilidad = await prisma.habilidad.findUnique({
        where: { id: datos.habilidadId },
        select: { id: true },
    })

    if (!habilidad) {
        throw new HttpError(404, 'Habilidad no encontrada')
    }

    try {
        return await prisma.cvHabilidad.create({
            data: {
                cvId,
                habilidadId: habilidad.id,
                nivel: datos.nivel ?? null,
            },
            include: { habilidad: { select: { id: true, nombre: true } } },
        })
    } catch (err) {
        //P2002 = ya existe la pareja (cvId, habilidadId). Se traduce a 409
        //en vez de dejar salir un 500. Idempotencia se maneja aquí; si el
        //cliente quiere sobreescribir el nivel, tiene el PATCH.
        if (
            err instanceof Prisma.PrismaClientKnownRequestError &&
            err.code === 'P2002'
        ) {
            throw new HttpError(409, 'Esta habilidad ya está asignada al CV')
        }
        throw err
    }
}

export async function actualizarNivelHabilidad(
    usuarioId: string,
    cvId: string,
    habilidadId: string,
    datos: ActualizarNivelInput,
) {
    await cvDelCandidato(usuarioId, cvId)

    try {
        return await prisma.cvHabilidad.update({
            where: { cvId_habilidadId: { cvId, habilidadId } },
            data: { nivel: datos.nivel },
            include: { habilidad: { select: { id: true, nombre: true } } },
        })
    } catch (err) {
        //P2025 = no existe la fila. El CV es del usuario (comprobado arriba),
        //así que el 404 es "esta habilidad no está en tu CV", no un fisgón.
        if (
            err instanceof Prisma.PrismaClientKnownRequestError &&
            err.code === 'P2025'
        ) {
            throw new HttpError(404, 'Esta habilidad no está asignada al CV')
        }
        throw err
    }
}

export async function quitarHabilidadDeCv(
    usuarioId: string,
    cvId: string,
    habilidadId: string,
) {
    await cvDelCandidato(usuarioId, cvId)

    try {
        await prisma.cvHabilidad.delete({
            where: { cvId_habilidadId: { cvId, habilidadId } },
        })
    } catch (err) {
        if (
            err instanceof Prisma.PrismaClientKnownRequestError &&
            err.code === 'P2025'
        ) {
            throw new HttpError(404, 'Esta habilidad no está asignada al CV')
        }
        throw err
    }
}
