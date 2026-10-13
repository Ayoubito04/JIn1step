import { afterEach, describe, expect, it } from 'vitest'
import { prisma } from '../../lib/prisma'
import { previsualizarAutopilot } from './postulaciones_autopilot.service'

const MARCA = '__test_autopilot_preview__'
let candidatoId: string | undefined
let reclutadorId: string | undefined
let empresaId: string | undefined
let habilidadId: string | undefined

afterEach(async () => {
    if (candidatoId) {
        await prisma.usuario.delete({ where: { id: candidatoId } })
    }
    if (reclutadorId) {
        await prisma.usuario.delete({ where: { id: reclutadorId } })
    }
    if (empresaId) {
        await prisma.empresa.delete({ where: { id: empresaId } })
    }
    if (habilidadId) {
        await prisma.habilidad.delete({ where: { id: habilidadId } })
    }
    candidatoId = undefined
    reclutadorId = undefined
    empresaId = undefined
    habilidadId = undefined
})

describe('previsualizarAutopilot', () => {
    it('muestra ofertas compatibles sin suscripción ni crear postulaciones', async () => {
        const sufijo = crypto.randomUUID()
        const candidato = await prisma.usuario.create({
            data: {
                nombre: MARCA,
                apellidos: MARCA,
                email: `${MARCA}-candidato-${sufijo}@test.local`,
                rol: 'CANDIDATO',
            },
        })
        candidatoId = candidato.id

        const reclutador = await prisma.usuario.create({
            data: {
                nombre: MARCA,
                apellidos: MARCA,
                email: `${MARCA}-reclutador-${sufijo}@test.local`,
                rol: 'RECLUTADOR',
            },
        })
        reclutadorId = reclutador.id

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
                urlArchivo: 'test://autopilot-preview.pdf',
            },
        })
        await prisma.cvHabilidad.create({
            data: {
                cvId: cv.id,
                habilidadId: habilidad.id,
                nivel: 'AVANZADO',
            },
        })

        const oferta = await prisma.oferta.create({
            data: {
                empresaId: empresa.id,
                reclutadorId: reclutador.id,
                titulo: 'Oferta compatible de prueba',
                descripcion: 'Oferta temporal para probar el autopiloto.',
                modalidad: 'HIBRIDO',
                requisitos: {
                    create: [{ habilidadId: habilidad.id, obligatorio: true }],
                },
            },
        })

        await prisma.preferenciasAutopilot.create({
            data: {
                usuarioId: candidato.id,
                cvId: cv.id,
                scoreMinimo: 70,
                maxPorDia: 3,
            },
        })

        const resultado = await previsualizarAutopilot(candidato.id)

        expect(resultado.ofertas).toEqual([
            expect.objectContaining({
                ofertaId: oferta.id,
                titulo: 'Oferta compatible de prueba',
                empresa: `${MARCA} ${sufijo}`,
                score: 100,
            }),
        ])
        expect(resultado.motivo).toBeNull()
        expect(
            await prisma.postulacion.count({ where: { cvId: cv.id } }),
        ).toBe(0)
        expect(
            await prisma.suscripcion.count({ where: { usuarioId: candidato.id } }),
        ).toBe(0)
    })
})
