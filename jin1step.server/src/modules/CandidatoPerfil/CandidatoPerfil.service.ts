//Lógica del perfil del candidato y su red profesional (seguidores / siguiendo).
import { prisma } from '../../lib/prisma'
import { HttpError } from '../../lib/http-error'
import type { ActualizarPerfilInput } from './CandidatoPerfil.schema'

const PERFIL_VACIO = {
    ubicacion: null,
    disponibilidad: null,
    expectativaSalarial: null,
    banner: null,
    fotoPerfil: null,
}

const CAMPOS_PUBLICOS = {
    usuarioId: true,
    ubicacion: true,
    disponibilidad: true,
    expectativaSalarial: true,
    banner: true,
    fotoPerfil: true,
} as const

async function contarConexiones(usuarioId: string) {
    const [seguidoresCount, siguiendoCount] = await Promise.all([
        prisma.seguimientoCandidato.count({ where: { seguidoId: usuarioId } }),
        prisma.seguimientoCandidato.count({ where: { seguidorId: usuarioId } }),
    ])
    return { seguidoresCount, siguiendoCount }
}

//El perfil propio. Nunca lanza 404: si no hay fila, devuelve los valores
//vacíos, porque "aún no lo he rellenado" no es un error.
export async function obtenerMiPerfil(usuarioId: string) {
    const [perfil, conteos] = await Promise.all([
        prisma.candidatoPerfil.findUnique({
            where: { usuarioId },
            select: CAMPOS_PUBLICOS,
        }),
        contarConexiones(usuarioId),
    ])

    return {
        ...(perfil ?? { usuarioId, ...PERFIL_VACIO }),
        ...conteos,
    }
}

//El perfil de OTRO candidato, consultable tanto por un reclutador como por
//otro candidato de la red profesional.
export async function obtenerPerfilDeCandidato(
    candidatoId: string,
    visitanteId?: string,
) {
    const usuario = await prisma.usuario.findFirst({
        where: { id: candidatoId, rol: 'CANDIDATO' },
        select: {
            id: true,
            nombre: true,
            apellidos: true,
            email: true,
            createdAt: true,
            _count: {
                select: {
                    seguidores: true,
                    siguiendo: true,
                },
            },
            cvs: {
                orderBy: { createdAt: 'desc' },
                select: {
                    id: true,
                    titulo: true,
                    atsScore: true,
                    perfilIa: true,
                    contenidoTexto: true,
                    createdAt: true,
                    habilidades: {
                        select: {
                            nivel: true,
                            habilidad: { select: { id: true, nombre: true } },
                        },
                    },
                },
            },
        },
    })

    if (!usuario) {
        throw new HttpError(404, 'Candidato no encontrado')
    }

    const [perfil, relacionLoSigo, relacionMeSigue] = await Promise.all([
        prisma.candidatoPerfil.findUnique({
            where: { usuarioId: candidatoId },
            select: CAMPOS_PUBLICOS,
        }),
        visitanteId && visitanteId !== candidatoId
            ? prisma.seguimientoCandidato.findUnique({
                  where: {
                      seguidorId_seguidoId: {
                          seguidorId: visitanteId,
                          seguidoId: candidatoId,
                      },
                  },
              })
            : Promise.resolve(null),
        visitanteId && visitanteId !== candidatoId
            ? prisma.seguimientoCandidato.findUnique({
                  where: {
                      seguidorId_seguidoId: {
                          seguidorId: candidatoId,
                          seguidoId: visitanteId,
                      },
                  },
              })
            : Promise.resolve(null),
    ])

    const base = perfil ?? { usuarioId: candidatoId, ...PERFIL_VACIO }
    return {
        ...base,
        seguidoresCount: usuario._count.seguidores,
        siguiendoCount: usuario._count.siguiendo,
        loSigo: Boolean(relacionLoSigo),
        meSigue: Boolean(relacionMeSigue),
        usuario: {
            id: usuario.id,
            nombre: usuario.nombre,
            apellidos: usuario.apellidos,
            email: usuario.email,
            createdAt: usuario.createdAt,
        },
        cvs: usuario.cvs,
    }
}

export async function actualizarMiPerfil(
    usuarioId: string,
    datos: ActualizarPerfilInput,
) {
    const [perfil, conteos] = await Promise.all([
        prisma.candidatoPerfil.upsert({
            where: { usuarioId },
            create: { usuarioId, ...datos },
            update: datos,
            select: CAMPOS_PUBLICOS,
        }),
        contarConexiones(usuarioId),
    ])
    return { ...perfil, ...conteos }
}

export async function guardarBanner(
    usuarioId: string,
    archivo: Express.Multer.File,
) {
    const base64 = archivo.buffer.toString('base64')
    const dataUrl = `data:${archivo.mimetype};base64,${base64}`
    const [perfil, conteos] = await Promise.all([
        prisma.candidatoPerfil.upsert({
            where: { usuarioId },
            create: { usuarioId, banner: dataUrl },
            update: { banner: dataUrl },
            select: CAMPOS_PUBLICOS,
        }),
        contarConexiones(usuarioId),
    ])
    return { ...perfil, ...conteos }
}

export async function borrarBanner(usuarioId: string) {
    const [perfil, conteos] = await Promise.all([
        prisma.candidatoPerfil.upsert({
            where: { usuarioId },
            create: { usuarioId, banner: null },
            update: { banner: null },
            select: CAMPOS_PUBLICOS,
        }),
        contarConexiones(usuarioId),
    ])
    return { ...perfil, ...conteos }
}

export async function guardarFotoPerfil(
    usuarioId: string,
    archivo: Express.Multer.File,
) {
    const base64 = archivo.buffer.toString('base64')
    const dataUrl = `data:${archivo.mimetype};base64,${base64}`
    const [perfil, conteos] = await Promise.all([
        prisma.candidatoPerfil.upsert({
            where: { usuarioId },
            create: { usuarioId, fotoPerfil: dataUrl },
            update: { fotoPerfil: dataUrl },
            select: CAMPOS_PUBLICOS,
        }),
        contarConexiones(usuarioId),
    ])
    return { ...perfil, ...conteos }
}

export async function borrarFotoPerfil(usuarioId: string) {
    const [perfil, conteos] = await Promise.all([
        prisma.candidatoPerfil.upsert({
            where: { usuarioId },
            create: { usuarioId, fotoPerfil: null },
            update: { fotoPerfil: null },
            select: CAMPOS_PUBLICOS,
        }),
        contarConexiones(usuarioId),
    ])
    return { ...perfil, ...conteos }
}

export async function borrarMiPerfil(usuarioId: string) {
    await prisma.candidatoPerfil.deleteMany({ where: { usuarioId } })
}

export async function seguirCandidato(seguidorId: string, seguidoId: string) {
    if (seguidorId === seguidoId) {
        throw new HttpError(400, 'No puedes seguirte a ti mismo')
    }

    const objetivo = await prisma.usuario.findFirst({
        where: { id: seguidoId, rol: 'CANDIDATO' },
        select: { id: true },
    })
    if (!objetivo) {
        throw new HttpError(404, 'Candidato no encontrado')
    }

    await prisma.seguimientoCandidato.upsert({
        where: {
            seguidorId_seguidoId: { seguidorId, seguidoId },
        },
        create: { seguidorId, seguidoId },
        update: {},
    })

    const [seguidoresObjetivo, misConteos] = await Promise.all([
        prisma.seguimientoCandidato.count({ where: { seguidoId } }),
        contarConexiones(seguidorId),
    ])

    return {
        loSigo: true,
        seguidoresCount: seguidoresObjetivo,
        miSiguiendoCount: misConteos.siguiendoCount,
        miSeguidoresCount: misConteos.seguidoresCount,
    }
}

export async function dejarDeSeguirCandidato(
    seguidorId: string,
    seguidoId: string,
) {
    await prisma.seguimientoCandidato.deleteMany({
        where: { seguidorId, seguidoId },
    })

    const [seguidoresObjetivo, misConteos] = await Promise.all([
        prisma.seguimientoCandidato.count({ where: { seguidoId } }),
        contarConexiones(seguidorId),
    ])

    return {
        loSigo: false,
        seguidoresCount: seguidoresObjetivo,
        miSiguiendoCount: misConteos.siguiendoCount,
        miSeguidoresCount: misConteos.seguidoresCount,
    }
}

export async function obtenerRedCandidatos(
    usuarioId: string,
    busqueda?: string,
) {
    const [relacionesSigo, relacionesMeSiguen, candidatos] = await Promise.all([
        prisma.seguimientoCandidato.findMany({
            where: { seguidorId: usuarioId },
            select: { seguidoId: true },
        }),
        prisma.seguimientoCandidato.findMany({
            where: { seguidoId: usuarioId },
            select: { seguidorId: true },
        }),
        prisma.usuario.findMany({
            where: {
                rol: 'CANDIDATO',
                id: { not: usuarioId },
            },
            orderBy: { createdAt: 'desc' },
            take: 80,
            select: {
                id: true,
                nombre: true,
                apellidos: true,
                email: true,
                candidatoPerfil: {
                    select: {
                        ubicacion: true,
                        disponibilidad: true,
                        expectativaSalarial: true,
                        banner: true,
                        fotoPerfil: true,
                    },
                },
                _count: {
                    select: {
                        seguidores: true,
                        siguiendo: true,
                    },
                },
                cvs: {
                    orderBy: { createdAt: 'desc' },
                    take: 1,
                    select: {
                        titulo: true,
                        perfilIa: true,
                        habilidades: {
                            take: 6,
                            select: {
                                nivel: true,
                                habilidad: { select: { nombre: true } },
                            },
                        },
                    },
                },
            },
        }),
    ])

    const idsSigo = new Set(relacionesSigo.map((r) => r.seguidoId))
    const idsMeSiguen = new Set(relacionesMeSiguen.map((r) => r.seguidorId))
    const filtro = (busqueda ?? '').trim().toLowerCase()

    const tarjetas = candidatos.map((c) => {
        const cv = c.cvs[0]
        const rawIa = cv?.perfilIa as Record<string, unknown> | null | undefined
        const roles = Array.isArray(rawIa?.rolesObjetivo)
            ? (rawIa.rolesObjetivo as unknown[]).filter(
                  (r): r is string => typeof r === 'string',
              )
            : []
        const seniority =
            typeof rawIa?.seniority === 'string' ? rawIa.seniority : null
        const resumen =
            typeof rawIa?.resumen === 'string' ? rawIa.resumen : null
        const habilidades = (cv?.habilidades ?? []).map(
            (h) => h.habilidad.nombre,
        )
        const titular =
            roles.length > 0
                ? [roles[0], seniority].filter(Boolean).join(' · ')
                : (cv?.titulo ?? 'Candidato/a en JIn1Step')

        return {
            id: c.id,
            nombre: c.nombre,
            apellidos: c.apellidos,
            email: c.email,
            ubicacion: c.candidatoPerfil?.ubicacion ?? null,
            disponibilidad: c.candidatoPerfil?.disponibilidad ?? null,
            expectativaSalarial: c.candidatoPerfil?.expectativaSalarial ?? null,
            banner: c.candidatoPerfil?.banner ?? null,
            fotoPerfil: c.candidatoPerfil?.fotoPerfil ?? null,
            titular,
            resumen,
            habilidades,
            seguidoresCount: c._count.seguidores,
            siguiendoCount: c._count.siguiendo,
            loSigo: idsSigo.has(c.id),
            meSigue: idsMeSiguen.has(c.id),
        }
    })

    const coincide = (t: (typeof tarjetas)[number]) => {
        if (!filtro) return true
        const texto = [
            t.nombre,
            t.apellidos,
            t.ubicacion,
            t.disponibilidad,
            t.titular,
            t.resumen,
            ...t.habilidades,
        ]
            .filter(Boolean)
            .join(' ')
            .toLowerCase()
        return texto.includes(filtro)
    }

    const filtradas = tarjetas.filter(coincide)

    return {
        seguidoresCount: idsMeSiguen.size,
        siguiendoCount: idsSigo.size,
        siguiendo: filtradas.filter((t) => t.loSigo),
        seguidores: filtradas.filter((t) => t.meSigue),
        descubrir: filtradas,
    }
}
