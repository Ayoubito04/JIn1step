import { afterEach, describe, expect, it } from 'vitest'
import { prisma } from '../../lib/prisma'
import { previsualizarAutopilot } from '../postulaciones_autopilot/postulaciones_autopilot.service'
import {
    actualizarEstadoPostulacion,
    listarPostulacionesDeCandidato,
    listarPostulacionesDeOferta,
    obtenerCvDePostulacion,
    retirarPostulacion,
} from './postulacion.service'

const MARCA = '__test_retirar_postulacion__'
const usuarios: string[] = []
let empresaId: string | undefined
let habilidadId: string | undefined

afterEach(async () => {
    for (const id of usuarios.splice(0)) {
        await prisma.usuario.delete({ where: { id } })
    }
    if (empresaId) await prisma.empresa.delete({ where: { id: empresaId } })
    if (habilidadId) await prisma.habilidad.delete({ where: { id: habilidadId } })
    empresaId = undefined
    habilidadId = undefined
})

async function escenario() {
    const sufijo = crypto.randomUUID()
    const crearUsuario = async (rol: 'CANDIDATO' | 'RECLUTADOR', etiqueta: string) => {
        const u = await prisma.usuario.create({
            data: {
                nombre: MARCA,
                apellidos: MARCA,
                email: `${MARCA}-${etiqueta}-${sufijo}@test.local`,
                rol,
            },
        })
        usuarios.push(u.id)
        return u
    }
    const candidato = await crearUsuario('CANDIDATO', 'candidato')
    const otro = await crearUsuario('CANDIDATO', 'otro')
    const reclutador = await crearUsuario('RECLUTADOR', 'reclutador')

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
            urlArchivo: 'test://retirar.pdf',
        },
    })
    await prisma.cvHabilidad.create({
        data: { cvId: cv.id, habilidadId: habilidad.id, nivel: 'AVANZADO' },
    })
    const oferta = await prisma.oferta.create({
        data: {
            empresaId: empresa.id,
            reclutadorId: reclutador.id,
            titulo: 'Oferta de prueba',
            descripcion: 'Oferta temporal.',
            modalidad: 'REMOTO',
            requisitos: { create: [{ habilidadId: habilidad.id, obligatorio: true }] },
        },
    })
    const postulacion = await prisma.postulacion.create({
        data: {
            cvId: cv.id,
            ofertaId: oferta.id,
            matchScore: 100,
            postuladoPorIa: true,
            estado: 'ENVIADA',
        },
    })
    return { candidato, otro, reclutador, cv, oferta, postulacion }
}

describe('retirarPostulacion', () => {
    it('la marca RETIRADA sin borrarla, la oculta al reclutador y el autopiloto no la repite', async () => {
        const { candidato, reclutador, cv, oferta, postulacion } = await escenario()

        const retirada = await retirarPostulacion(candidato.id, postulacion.id)
        expect(retirada.estado).toBe('RETIRADA')

        // Sigue en la lista del candidato, con su estado.
        const mias = await listarPostulacionesDeCandidato(candidato.id)
        expect(mias.map((p) => [p.id, p.estado])).toEqual([[postulacion.id, 'RETIRADA']])

        // El reclutador ya no la ve, ni puede abrir su CV ni cambiarle el estado.
        expect(await listarPostulacionesDeOferta(reclutador.id, oferta.id)).toEqual([])
        await expect(obtenerCvDePostulacion(reclutador.id, postulacion.id)).rejects.toMatchObject({ statusCode: 404 })
        await expect(
            actualizarEstadoPostulacion(reclutador.id, postulacion.id, { estado: 'ENTREVISTA' }),
        ).rejects.toMatchObject({ statusCode: 404 })

        // El autopiloto no vuelve a proponer esa oferta.
        await prisma.preferenciasAutopilot.create({
            data: { usuarioId: candidato.id, cvId: cv.id, scoreMinimo: 70, maxPorDia: 3 },
        })
        const preview = await previsualizarAutopilot(candidato.id)
        expect(preview.ofertas).toEqual([])
    })

    it('es idempotente', async () => {
        const { candidato, postulacion } = await escenario()
        await retirarPostulacion(candidato.id, postulacion.id)
        const otra = await retirarPostulacion(candidato.id, postulacion.id)
        expect(otra.estado).toBe('RETIRADA')
    })

    it('devuelve 404 si la candidatura es de otro candidato', async () => {
        const { otro, postulacion } = await escenario()
        await expect(retirarPostulacion(otro.id, postulacion.id)).rejects.toMatchObject({ statusCode: 404 })
        const intacta = await prisma.postulacion.findUniqueOrThrow({ where: { id: postulacion.id } })
        expect(intacta.estado).toBe('ENVIADA')
    })

    it.each(['VISTA', 'ENTREVISTA', 'RECHAZADA'] as const)(
        'devuelve 409 si la empresa ya la ha marcado como %s',
        async (estado) => {
            const { candidato, postulacion } = await escenario()
            await prisma.postulacion.update({ where: { id: postulacion.id }, data: { estado } })
            await expect(retirarPostulacion(candidato.id, postulacion.id)).rejects.toMatchObject({ statusCode: 409 })
            const intacta = await prisma.postulacion.findUniqueOrThrow({ where: { id: postulacion.id } })
            expect(intacta.estado).toBe(estado)
        },
    )
})
