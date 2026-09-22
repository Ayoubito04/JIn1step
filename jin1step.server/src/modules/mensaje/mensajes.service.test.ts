// Tests de INTEGRACIÓN de los mensajes. Hablan con Postgres de verdad.
//
// Lo que más importa aquí no es que los mensajes se guarden, es que NADIE
// pueda leer ni escribir en una conversación que no es suya. Ese control vive
// en conversacionDelUsuario (conversacion/conversacion.service.ts), porque en
// la base de datos no hay nada que lo impida: con el uuid de una conversación
// basta para un findUnique. Se prueba desde aquí porque es aquí donde se usa.
//
// Abrir y listar conversaciones se prueba en
// conversacion/conversacion.service.test.ts.
//
// Requiere la base de datos levantada:  npx prisma migrate deploy
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { prisma } from '../../lib/prisma'
import { contarNoLeidos, enviarMensaje, listarMensajes } from './mensajes.service'
import { abrirConversacion } from '../conversacion/conversacion.service'

const MARCA = '__test_mensajes__'

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

// Abre el hilo entre los dos usuarios del test y devuelve su id.
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

describe('control de acceso', () => {
    // El grupo que justifica todo el módulo.
    it('un tercero no puede leer el hilo ajeno', async () => {
        const conversacionId = await hilo()
        const intruso = await crearUsuario('CANDIDATO')

        await expect(listarMensajes(intruso, conversacionId)).rejects.toMatchObject({
            statusCode: 404,
        })
    })

    it('un tercero no puede escribir en el hilo ajeno', async () => {
        const conversacionId = await hilo()
        const intruso = await crearUsuario('RECLUTADOR')

        await expect(
            enviarMensaje(intruso, conversacionId, { contenido: 'hola' }),
        ).rejects.toMatchObject({ statusCode: 404 })
    })

    // 404 y no 403: un 403 le confirmaría al intruso que ese hilo existe.
    it('devuelve 404 y no 403, para no confirmar que el hilo existe', async () => {
        const conversacionId = await hilo()
        const intruso = await crearUsuario('CANDIDATO')

        await expect(listarMensajes(intruso, conversacionId)).rejects.toMatchObject({
            statusCode: 404,
        })
        await expect(
            listarMensajes(intruso, crypto.randomUUID()),
        ).rejects.toMatchObject({ statusCode: 404 })
    })
})

describe('enviarMensaje', () => {
    it('el emisor es quien llama, y nace sin leer', async () => {
        const conversacionId = await hilo()
        const m = await enviarMensaje(candidato, conversacionId, { contenido: 'Buenas' })

        expect(m.emisorId).toBe(candidato)
        expect(m.leido).toBe(false)
    })

    it('los dos participantes pueden escribir', async () => {
        const conversacionId = await hilo()
        await enviarMensaje(candidato, conversacionId, { contenido: 'Hola' })
        await enviarMensaje(reclutador, conversacionId, { contenido: 'Qué tal' })

        expect(await prisma.mensaje.count({ where: { conversacionId } })).toBe(2)
    })
})

describe('listarMensajes', () => {
    it('devuelve el hilo del más antiguo al más nuevo', async () => {
        const conversacionId = await hilo()
        await enviarMensaje(candidato, conversacionId, { contenido: 'primero' })
        await enviarMensaje(reclutador, conversacionId, { contenido: 'segundo' })

        const mensajes = await listarMensajes(candidato, conversacionId)
        expect(mensajes.map((m) => m.contenido)).toEqual(['primero', 'segundo'])
    })

    // "leído" significa "el destinatario lo vio". Marcar los propios falsearía
    // el visto del otro lado.
    it('marca como leídos los del otro, nunca los propios', async () => {
        const conversacionId = await hilo()
        await enviarMensaje(candidato, conversacionId, { contenido: 'mío' })
        await enviarMensaje(reclutador, conversacionId, { contenido: 'suyo' })

        const vistos = await listarMensajes(candidato, conversacionId)

        expect(vistos.find((m) => m.contenido === 'suyo')?.leido).toBe(true)
        expect(vistos.find((m) => m.contenido === 'mío')?.leido).toBe(false)
    })
})

describe('contarNoLeidos', () => {
    it('cuenta solo los recibidos y sin leer', async () => {
        const conversacionId = await hilo()
        await enviarMensaje(candidato, conversacionId, { contenido: 'mío, no cuenta' })
        await enviarMensaje(reclutador, conversacionId, { contenido: 'suyo, cuenta' })

        expect(await contarNoLeidos(candidato)).toBe(1)
        expect(await contarNoLeidos(reclutador)).toBe(1)
    })

    it('baja a cero cuando se abre la conversación', async () => {
        const conversacionId = await hilo()
        await enviarMensaje(reclutador, conversacionId, { contenido: 'hola' })

        await listarMensajes(candidato, conversacionId)

        expect(await contarNoLeidos(candidato)).toBe(0)
    })
})
