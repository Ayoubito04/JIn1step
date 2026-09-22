// Tests de INTEGRACIÓN del service de suscripciones.
//
// Hablan con la base de datos de verdad, no con un mock, y es a propósito: casi
// todo lo que protege este módulo vive en constraints de Postgres (el índice
// único parcial de "una sola ACTIVA", el @unique de idExterno, el NOT NULL de
// precioCentimos). Un mock de Prisma daría verde sin probar nada de eso.
//
// Requiere la base de datos levantada y las migraciones aplicadas:
//   npx prisma migrate deploy
//
// Cada test crea sus propios usuarios con el prefijo MARCA y los borra al
// terminar; el onDelete: Cascade del modelo arrastra sus suscripciones.
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { prisma } from '../../lib/prisma'
import { HttpError } from '../../lib/http-error'
import {
    ActivarPorWebhook,
    CancelarSuscripcion,
    CrearSuscripcion,
    ListarMisSuscripciones,
    ObtenerSuscripcionActiva,
    TieneSuscripcionActiva,
} from './suscripcion.service'
import { cancelarSuscripcionSchema, iniciarSuscripcionSchema } from './suscripcion.schema'

const MARCA = '__test_suscripcion__'

// Los bodies se construyen pasando por el schema, igual que haría validateBody.
// Así los tests prueban el camino real y no una forma inventada a mano.
const bodyAlta = (plan?: 'MENSUAL' | 'ANUAL') =>
    iniciarSuscripcionSchema.parse(plan ? { tipoPlan: plan } : undefined)
const bodyBaja = (alFinal?: boolean) =>
    cancelarSuscripcionSchema.parse(alFinal === undefined ? undefined : { alFinalDelPeriodo: alFinal })

const enDias = (n: number) => new Date(Date.now() + n * 24 * 60 * 60 * 1000)

let usuarioId: string

async function crearUsuario() {
    const u = await prisma.usuario.create({
        data: {
            nombre: MARCA,
            apellidos: MARCA,
            email: `${MARCA}-${crypto.randomUUID()}@test.local`,
            rol: 'CANDIDATO',
        },
    })
    return u.id
}

beforeEach(async () => {
    usuarioId = await crearUsuario()
})

afterEach(async () => {
    await prisma.usuario.deleteMany({ where: { nombre: MARCA } })
})

describe('CrearSuscripcion', () => {
    // Lo más importante del módulo: contratar NO da acceso. El acceso llega
    // cuando la pasarela confirma el cobro por webhook.
    it('nace en PENDIENTE_PAGO y todavía no da acceso al autopiloto', async () => {
        const s = await CrearSuscripcion(usuarioId, bodyAlta())

        expect(s.estado).toBe('PENDIENTE_PAGO')
        expect(await TieneSuscripcionActiva(usuarioId)).toBe(false)
    })

    it('el precio lo pone el servidor según el plan, no el cliente', async () => {
        const mensual = await CrearSuscripcion(usuarioId, bodyAlta('MENSUAL'))
        expect(mensual.precioCentimos).toBe(500)

        const otro = await crearUsuario()
        const anual = await CrearSuscripcion(otro, bodyAlta('ANUAL'))
        expect(anual.precioCentimos).toBe(5000)
    })

    // idExterno no se devuelve: es un identificador interno de la pasarela y
    // el frontend no lo necesita para nada.
    it('la respuesta no expone idExterno', async () => {
        const s = await CrearSuscripcion(usuarioId, bodyAlta())
        expect(s).not.toHaveProperty('idExterno')
    })

    it('deja varias altas pendientes (aún no hay ninguna ACTIVA)', async () => {
        await CrearSuscripcion(usuarioId, bodyAlta())
        await expect(CrearSuscripcion(usuarioId, bodyAlta())).resolves.toBeDefined()
    })

    it('da 409 si el usuario ya tiene una ACTIVA', async () => {
        const s = await CrearSuscripcion(usuarioId, bodyAlta())
        await ActivarPorWebhook(s.id, `sub_${crypto.randomUUID()}`, enDias(30))

        await expect(CrearSuscripcion(usuarioId, bodyAlta())).rejects.toMatchObject({
            statusCode: 409,
        })
    })

    it('da 404 si el usuario no existe', async () => {
        await expect(CrearSuscripcion(crypto.randomUUID(), bodyAlta())).rejects.toBeInstanceOf(
            HttpError,
        )
    })
})

describe('ActivarPorWebhook', () => {
    it('es el único camino a ACTIVA y abre el acceso', async () => {
        const s = await CrearSuscripcion(usuarioId, bodyAlta())
        const activa = await ActivarPorWebhook(s.id, `sub_${crypto.randomUUID()}`, enDias(30))

        expect(activa.estado).toBe('ACTIVA')
        expect(await TieneSuscripcionActiva(usuarioId)).toBe(true)
        expect((await ObtenerSuscripcionActiva(usuarioId))?.id).toBe(s.id)
    })

    // Los webhooks de Stripe llegan duplicados y desordenados por diseño. El
    // mismo evento reintentado no puede crear una segunda fila ni reventar.
    it('es idempotente ante el mismo evento repetido', async () => {
        const s = await CrearSuscripcion(usuarioId, bodyAlta())
        const idExterno = `sub_${crypto.randomUUID()}`

        const primera = await ActivarPorWebhook(s.id, idExterno, enDias(30))
        const segunda = await ActivarPorWebhook(s.id, idExterno, enDias(30))

        expect(segunda.id).toBe(primera.id)
        expect(await prisma.suscripcion.count({ where: { usuarioId } })).toBe(1)
    })

    it('da 404 si la suscripción no existe', async () => {
        await expect(
            ActivarPorWebhook(crypto.randomUUID(), 'sub_x', enDias(30)),
        ).rejects.toMatchObject({ statusCode: 404 })
    })
})

describe('TieneSuscripcionActiva', () => {
    // El caso que se olvida siempre: Stripe deja de cobrar, el webhook de
    // impago no llega o falla, y la fila se queda en ACTIVA siendo ya papel
    // mojado. Sin esta comprobación el usuario seguiría usando el autopiloto
    // gratis indefinidamente.
    it('devuelve false si la renovación ya venció, aunque siga ACTIVA', async () => {
        const s = await CrearSuscripcion(usuarioId, bodyAlta())
        await ActivarPorWebhook(s.id, `sub_${crypto.randomUUID()}`, enDias(-1))

        expect((await ObtenerSuscripcionActiva(usuarioId))?.estado).toBe('ACTIVA')
        expect(await TieneSuscripcionActiva(usuarioId)).toBe(false)
    })

    it('devuelve false si el usuario no tiene ninguna suscripción', async () => {
        expect(await TieneSuscripcionActiva(usuarioId)).toBe(false)
    })
})

describe('CancelarSuscripcion', () => {
    async function conActiva() {
        const s = await CrearSuscripcion(usuarioId, bodyAlta())
        return ActivarPorWebhook(s.id, `sub_${crypto.randomUUID()}`, enDias(30))
    }

    // Lo que espera la ley de consumo de la UE: el usuario conserva el
    // servicio hasta que se acabe lo que ya pagó. La pasarela la pasará a
    // CANCELADA cuando venza de verdad.
    it('por defecto deja la suscripción viva hasta el final del periodo', async () => {
        await conActiva()
        const c = await CancelarSuscripcion(usuarioId, bodyBaja())

        expect(c.estado).toBe('ACTIVA')
        expect(c.fechaCancelacion).not.toBeNull()
        expect(await TieneSuscripcionActiva(usuarioId)).toBe(true)
    })

    it('con alFinalDelPeriodo=false corta el acceso de inmediato', async () => {
        await conActiva()
        const c = await CancelarSuscripcion(usuarioId, bodyBaja(false))

        expect(c.estado).toBe('CANCELADA')
        expect(await TieneSuscripcionActiva(usuarioId)).toBe(false)
    })

    it('da 404 si no hay ninguna suscripción activa', async () => {
        await expect(CancelarSuscripcion(usuarioId, bodyBaja())).rejects.toMatchObject({
            statusCode: 404,
        })
    })
})

describe('ListarMisSuscripciones', () => {
    it('devuelve el histórico, lo más reciente primero', async () => {
        const vieja = await CrearSuscripcion(usuarioId, bodyAlta())
        await ActivarPorWebhook(vieja.id, `sub_${crypto.randomUUID()}`, enDias(30))
        await CancelarSuscripcion(usuarioId, bodyBaja(false))
        const nueva = await CrearSuscripcion(usuarioId, bodyAlta('ANUAL'))

        const historial = await ListarMisSuscripciones(usuarioId)

        expect(historial).toHaveLength(2)
        expect(historial[0].id).toBe(nueva.id)
    })

    it('no devuelve las de otros usuarios', async () => {
        await CrearSuscripcion(usuarioId, bodyAlta())
        const otro = await crearUsuario()

        expect(await ListarMisSuscripciones(otro)).toHaveLength(0)
    })
})
