// Tests de INTEGRACIÓN de las conversaciones. Hablan con Postgres de verdad.
//
// Los tests de escribir y leer mensajes están en
// mensaje/mensajes.service.test.ts; aquí solo se prueba abrir y listar hilos.
//
// Requiere la base de datos levantada:  npx prisma migrate deploy
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { prisma } from '../../lib/prisma'
import { abrirConversacion, listarMisConversaciones } from './conversacion.service'
import { enviarMensaje } from '../mensaje/mensajes.service'

const MARCA = '__test_conversacion__'

let candidato: string
let reclutador: string

async function crearUsuario(rol: 'CANDIDATO' | 'RECLUTADOR') {
    const u = await prisma.usuario.create({
        data: {
            nombre: MARCA,
            apellidos: MARCA,
            email: `${MARCA}-${crypto.randomUUID()}@test.local`,
            rol,
        },
    })
    return u.id
}

async function hilo() {
    const { conversacion } = await abrirConversacion(candidato, 'CANDIDATO', {
        usuarioId: reclutador,
    })
    return conversacion.id
}

beforeEach(async () => {
    candidato = await crearUsuario('CANDIDATO')
    reclutador = await crearUsuario('RECLUTADOR')
})

afterEach(async () => {
    await prisma.usuario.deleteMany({ where: { nombre: MARCA } })
})

describe('abrirConversacion', () => {
    // El rol de quien llama decide en qué hueco va cada uno. Da igual quién
    // abra el hilo: candidatoId tiene que ser el candidato siempre.
    it('coloca a cada uno en su hueco según el rol de quien abre', async () => {
        const desdeCandidato = await abrirConversacion(candidato, 'CANDIDATO', {
            usuarioId: reclutador,
        })
        expect(desdeCandidato.conversacion.candidato.id).toBe(candidato)
        expect(desdeCandidato.conversacion.reclutador.id).toBe(reclutador)

        const otroCandidato = await crearUsuario('CANDIDATO')
        const desdeReclutador = await abrirConversacion(reclutador, 'RECLUTADOR', {
            usuarioId: otroCandidato,
        })
        expect(desdeReclutador.conversacion.candidato.id).toBe(otroCandidato)
        expect(desdeReclutador.conversacion.reclutador.id).toBe(reclutador)
    })

    it('marca creada=true la primera vez y false al repetir', async () => {
        const primera = await abrirConversacion(candidato, 'CANDIDATO', {
            usuarioId: reclutador,
        })
        expect(primera.creada).toBe(true)

        const segunda = await abrirConversacion(candidato, 'CANDIDATO', {
            usuarioId: reclutador,
        })
        expect(segunda.creada).toBe(false)
        expect(segunda.conversacion.id).toBe(primera.conversacion.id)
    })

    // El @@unique del modelo NO cubre este caso, porque en Postgres NULL nunca
    // es igual a NULL. Si el service no deduplicara a mano, cada vez que el
    // usuario pulsara "Contactar" tendría un hilo nuevo y vacío.
    it('no duplica la conversación general aunque el índice único no lo impida', async () => {
        await abrirConversacion(candidato, 'CANDIDATO', { usuarioId: reclutador })
        await abrirConversacion(candidato, 'CANDIDATO', { usuarioId: reclutador })
        await abrirConversacion(reclutador, 'RECLUTADOR', { usuarioId: candidato })

        const filas = await prisma.conversacion.count({
            where: { candidatoId: candidato, reclutadorId: reclutador },
        })
        expect(filas).toBe(1)
    })

    it('rechaza abrir una conversación consigo mismo', async () => {
        await expect(
            abrirConversacion(candidato, 'CANDIDATO', { usuarioId: candidato }),
        ).rejects.toMatchObject({ statusCode: 400 })
    })

    // Sin esta comprobación la fila quedaría con un candidato metido en el
    // hueco de reclutador: un dato que es mentira.
    it('rechaza abrir conversación con alguien del mismo rol', async () => {
        const otroCandidato = await crearUsuario('CANDIDATO')

        await expect(
            abrirConversacion(candidato, 'CANDIDATO', { usuarioId: otroCandidato }),
        ).rejects.toMatchObject({ statusCode: 404 })
    })

    it('rechaza una oferta que no existe', async () => {
        await expect(
            abrirConversacion(candidato, 'CANDIDATO', {
                usuarioId: reclutador,
                ofertaId: crypto.randomUUID(),
            }),
        ).rejects.toMatchObject({ statusCode: 404 })
    })
})

describe('listarMisConversaciones', () => {
    it('resuelve el interlocutor y cuenta lo que falta por leer', async () => {
        const conversacionId = await hilo()
        await enviarMensaje(reclutador, conversacionId, { contenido: 'uno' })
        await enviarMensaje(reclutador, conversacionId, { contenido: 'dos' })

        const [bandeja] = await listarMisConversaciones(candidato)

        expect(bandeja.interlocutor.id).toBe(reclutador)
        expect(bandeja.sinLeer).toBe(2)
        expect(bandeja.ultimoMensaje?.contenido).toBe('dos')
    })

    it('no devuelve conversaciones de otros', async () => {
        await hilo()
        const ajeno = await crearUsuario('CANDIDATO')

        expect(await listarMisConversaciones(ajeno)).toHaveLength(0)
    })

    // Un hilo viejo con un mensaje reciente tiene que salir por delante de uno
    // creado después pero sin actividad.
    it('ordena por actividad, no por fecha de creación', async () => {
        const viejo = await hilo()
        const otroReclutador = await crearUsuario('RECLUTADOR')
        const { conversacion: nuevo } = await abrirConversacion(candidato, 'CANDIDATO', {
            usuarioId: otroReclutador,
        })

        await enviarMensaje(candidato, viejo, { contenido: 'revivo el hilo viejo' })

        const bandeja = await listarMisConversaciones(candidato)
        expect(bandeja[0].id).toBe(viejo)
        expect(bandeja[1].id).toBe(nuevo.id)
    })
})
