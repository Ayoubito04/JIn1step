import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

const { completarJson } = vi.hoisted(() => ({ completarJson: vi.fn() }))
vi.mock('../../lib/ia', () => ({ iaDisponible: () => true, completarJson }))

import { prisma } from '../../lib/prisma'
import { ejecutarAutopilot } from './postulaciones_autopilot.service'

const MARCA = '__test_autopilot_ia__'
const PERFIL = {
    resumen: 'Desarrollador full stack con 2 años de experiencia',
    rolesObjetivo: ['Full Stack Developer'],
    seniority: 'junior',
    sector: 'tecnología',
    tecnologias: ['TypeScript'],
    palabrasClave: ['react', 'node', MARCA],
    idiomas: ['español'],
}

//La "IA" simulada puntúa por título y, de regalo, devuelve un id inventado
//que el servicio tiene que descartar. Las ofertas de prueba llevan MARCA en la
//descripción y en las palabras clave del perfil: la BD de desarrollo tiene más
//de 60 ofertas y el prefiltro por palabras clave solo deja pasar 60 a la IA.
function iaSimulada(puntuaciones: Record<string, number>) {
    completarJson.mockImplementation(async (op: { nombre: string; usuario: string }) => {
        if (op.nombre === 'perfil_cv') return PERFIL
        const { ofertas } = JSON.parse(op.usuario) as {
            ofertas: { ofertaId: string; titulo: string }[]
        }
        if (op.nombre === 'valoracion_ofertas') {
            return {
                valoraciones: [
                    ...ofertas.map((o) => ({
                        ofertaId: o.ofertaId,
                        puntuacion: puntuaciones[o.titulo] ?? 0,
                        motivo: `motivo ${o.titulo}`,
                        palabrasClaveCubiertas: [],
                        palabrasClaveFaltantes: [],
                    })),
                    {
                        ofertaId: crypto.randomUUID(),
                        puntuacion: 100,
                        motivo: 'inventada',
                        palabrasClaveCubiertas: [],
                        palabrasClaveFaltantes: [],
                    },
                ],
            }
        }
        return {
            cartas: ofertas.map((o) => ({
                ofertaId: o.ofertaId,
                carta: `carta ${o.titulo}`,
            })),
        }
    })
}

let usuarios: string[] = []
let empresaId: string | undefined
let habilidadId: string | undefined

beforeEach(() => {
    completarJson.mockReset()
})

afterEach(async () => {
    for (const id of usuarios) await prisma.usuario.delete({ where: { id } })
    if (empresaId) await prisma.empresa.delete({ where: { id: empresaId } })
    if (habilidadId) await prisma.habilidad.delete({ where: { id: habilidadId } })
    usuarios = []
    empresaId = undefined
    habilidadId = undefined
})

//Candidato con CV con texto y tres ofertas: dos con la habilidad del CV como
//requisito (A, B) y una sin requisitos (C), que el match SQL descarta.
async function montar(opciones: { suscripcion: boolean; maxPorDia?: number }) {
    const sufijo = crypto.randomUUID()
    const candidato = await prisma.usuario.create({
        data: {
            nombre: MARCA,
            apellidos: MARCA,
            email: `${MARCA}-c-${sufijo}@test.local`,
            rol: 'CANDIDATO',
        },
    })
    const reclutador = await prisma.usuario.create({
        data: {
            nombre: MARCA,
            apellidos: MARCA,
            email: `${MARCA}-r-${sufijo}@test.local`,
            rol: 'RECLUTADOR',
        },
    })
    usuarios = [candidato.id, reclutador.id]

    const empresa = await prisma.empresa.create({
        data: { nombre: `${MARCA} ${sufijo}`, ubicacion: 'Madrid' },
    })
    empresaId = empresa.id
    const habilidad = await prisma.habilidad.create({
        data: { nombre: `${MARCA} ${sufijo}` },
    })
    habilidadId = habilidad.id

    const cv = await prisma.cv.create({
        data: {
            usuarioId: candidato.id,
            titulo: 'CV de prueba',
            urlArchivo: 'test://autopilot-ia.pdf',
            contenidoTexto: 'Desarrollador full stack. React, Node, TypeScript.',
        },
    })
    await prisma.cvHabilidad.create({
        data: { cvId: cv.id, habilidadId: habilidad.id, nivel: 'INTERMEDIO' },
    })

    const crearOferta = (titulo: string, conRequisito: boolean) =>
        prisma.oferta.create({
            data: {
                empresaId: empresa.id,
                reclutadorId: reclutador.id,
                titulo,
                descripcion: `Descripción de ${titulo} ${MARCA}`,
                modalidad: 'REMOTO',
                requisitos: conRequisito
                    ? { create: [{ habilidadId: habilidad.id, obligatorio: true }] }
                    : undefined,
            },
        })
    const [a, b, c] = await Promise.all([
        crearOferta('Oferta A', true),
        crearOferta('Oferta B', true),
        crearOferta('Oferta C', false),
    ])

    await prisma.preferenciasAutopilot.create({
        data: {
            usuarioId: candidato.id,
            cvId: cv.id,
            activo: true,
            scoreMinimo: 70,
            maxPorDia: opciones.maxPorDia ?? 5,
        },
    })
    if (opciones.suscripcion) {
        await prisma.suscripcion.create({
            data: {
                usuarioId: candidato.id,
                estado: 'ACTIVA',
                proveedorPago: 'STRIPE',
                tipoPlan: 'MENSUAL',
                precioCentimos: 500,
            },
        })
    }
    return { candidato, cv, ofertas: { a, b, c } }
}

describe('ejecutarAutopilot con IA', () => {
    it('postula según la IA, guarda motivo y carta, y descarta ids inventados', async () => {
        const { candidato, cv, ofertas } = await montar({ suscripcion: true })
        //C no tiene requisitos (el SQL la descartaría) pero la IA la ve encajar.
        iaSimulada({ 'Oferta A': 90, 'Oferta B': 50, 'Oferta C': 80 })

        const resultado = await ejecutarAutopilot(candidato.id)

        expect(resultado).toMatchObject({ creadas: 2, via: 'ia' })
        const guardadas = await prisma.postulacion.findMany({
            where: { cvId: cv.id },
            orderBy: { puntuacionIa: 'desc' },
        })
        expect(guardadas.map((p) => p.ofertaId)).toEqual([ofertas.a.id, ofertas.c.id])
        expect(guardadas[0]).toMatchObject({
            puntuacionIa: 90,
            motivoIa: 'motivo Oferta A',
            cartaIa: 'carta Oferta A',
            matchScore: 100,
            postuladoPorIa: true,
            estado: 'ENVIADA',
        })
        expect(guardadas[1]).toMatchObject({ puntuacionIa: 80, matchScore: 0 })
    })

    it('respeta maxPorDia aunque la IA apruebe más ofertas', async () => {
        const { candidato, cv } = await montar({ suscripcion: true, maxPorDia: 1 })
        iaSimulada({ 'Oferta A': 90, 'Oferta B': 85, 'Oferta C': 80 })

        const resultado = await ejecutarAutopilot(candidato.id)

        expect(resultado.creadas).toBe(1)
        expect(await prisma.postulacion.count({ where: { cvId: cv.id } })).toBe(1)
    })

    it('cae al match por habilidades si la IA falla', async () => {
        const { candidato, cv, ofertas } = await montar({ suscripcion: true })
        completarJson.mockRejectedValue(new Error('OpenAI respondió 429'))
        const consola = vi.spyOn(console, 'error').mockImplementation(() => {})

        const resultado = await ejecutarAutopilot(candidato.id)
        consola.mockRestore()

        expect(resultado).toMatchObject({ creadas: 2, via: 'habilidades' })
        const guardadas = await prisma.postulacion.findMany({ where: { cvId: cv.id } })
        expect(guardadas.map((p) => p.ofertaId).sort()).toEqual(
            [ofertas.a.id, ofertas.b.id].sort(),
        )
        expect(guardadas.every((p) => p.puntuacionIa === null && p.cartaIa === null)).toBe(true)
    })

    it('reutiliza el perfil del CV sin volver a llamar a la IA', async () => {
        const { candidato } = await montar({ suscripcion: true })
        iaSimulada({ 'Oferta A': 90, 'Oferta B': 20, 'Oferta C': 20 })

        await ejecutarAutopilot(candidato.id)
        await ejecutarAutopilot(candidato.id)

        const llamadasPerfil = completarJson.mock.calls.filter(
            ([op]) => op.nombre === 'perfil_cv',
        )
        expect(llamadasPerfil).toHaveLength(1)
    })

    it('sin suscripción devuelve 402 y no llama a la IA', async () => {
        const { candidato } = await montar({ suscripcion: false })
        iaSimulada({ 'Oferta A': 90 })

        await expect(ejecutarAutopilot(candidato.id)).rejects.toMatchObject({
            statusCode: 402,
        })
        expect(completarJson).not.toHaveBeenCalled()
    })
})
