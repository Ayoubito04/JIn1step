// Tests del CONTRATO HTTP de suscripciones. No tocan la base de datos:
// aquí solo se comprueba qué bodies entran y cuáles se rechazan.
//
// El valor de estos tests no es cubrir líneas, es congelar las decisiones de
// seguridad del schema. Si alguien quita el .strict() o añade precioCentimos
// al objeto "para que el frontend lo mande", esto se pone rojo.
import { describe, expect, it } from 'vitest'
import {
    cancelarSuscripcionSchema,
    iniciarSuscripcionSchema,
} from './suscripcion.schema'

describe('iniciarSuscripcionSchema', () => {
    // En Express 5 un POST sin body deja req.body en undefined (en Express 4
    // era {}), y validateBody se lo pasa tal cual a safeParse. Como todos los
    // campos tienen default, "contrátame el plan por defecto" es justo una
    // petición sin body: si esto fallara, el caso más común daría 400.
    it('acepta una petición sin body y rellena los defaults', () => {
        expect(iniciarSuscripcionSchema.parse(undefined)).toEqual({
            tipoPlan: 'MENSUAL',
            proveedorPago: 'STRIPE',
        })
    })

    it('acepta un body vacío y rellena los defaults', () => {
        expect(iniciarSuscripcionSchema.parse({})).toEqual({
            tipoPlan: 'MENSUAL',
            proveedorPago: 'STRIPE',
        })
    })

    it('deja elegir el plan, que es lo único que decide el cliente', () => {
        expect(iniciarSuscripcionSchema.parse({ tipoPlan: 'ANUAL' })).toEqual({
            tipoPlan: 'ANUAL',
            proveedorPago: 'STRIPE',
        })
    })

    it('deja elegir proveedor, para las tiendas de las apps móviles', () => {
        const r = iniciarSuscripcionSchema.parse({ proveedorPago: 'GOOGLE_PLAY' })
        expect(r.proveedorPago).toBe('GOOGLE_PLAY')
    })

    it('rechaza un plan que no existe', () => {
        expect(iniciarSuscripcionSchema.safeParse({ tipoPlan: 'SEMANAL' }).success).toBe(false)
    })

    // El grupo importante. Cada uno de estos campos, si se aceptara del body,
    // sería dinero perdido: estado ACTIVA = autopiloto gratis, precioCentimos
    // = pagar 1 céntimo, usuarioId = suscribir a otro.
    it.each([
        ['estado', { estado: 'ACTIVA' }],
        ['precioCentimos', { precioCentimos: 1 }],
        ['usuarioId', { usuarioId: 'otro-usuario' }],
        ['idExterno', { idExterno: 'sub_falso' }],
        ['fechaInicio', { fechaInicio: '2020-01-01' }],
    ])('rechaza el body si intenta inyectar %s', (_campo, body) => {
        expect(iniciarSuscripcionSchema.safeParse(body).success).toBe(false)
    })

    // Con el strip por defecto de Zod una errata se descarta en silencio y la
    // petición parece correcta, contratando el plan por defecto sin avisar.
    it('rechaza erratas del frontend en vez de tragárselas', () => {
        const r = iniciarSuscripcionSchema.safeParse({ provedorPago: 'STRIPE' })
        expect(r.success).toBe(false)
        expect(r.error?.issues[0].message).toContain('provedorPago')
    })

    it('exige que claveIdempotencia sea un uuid', () => {
        expect(iniciarSuscripcionSchema.safeParse({ claveIdempotencia: 'abc' }).success).toBe(false)
        expect(
            iniciarSuscripcionSchema.safeParse({
                claveIdempotencia: '3f2504e0-4f89-11d3-9a0c-0305e82c3301',
            }).success,
        ).toBe(true)
    })
})

describe('cancelarSuscripcionSchema', () => {
    // alFinalDelPeriodo=true es lo que esperan las leyes de consumo de la UE:
    // el usuario conserva lo que ya pagó. Que sea el default importa, porque
    // "cancelar sin dar motivo" es una petición sin body.
    it('sin body cancela al final del periodo', () => {
        expect(cancelarSuscripcionSchema.parse(undefined)).toEqual({
            alFinalDelPeriodo: true,
        })
    })

    it('permite pedir el corte inmediato', () => {
        const r = cancelarSuscripcionSchema.parse({ alFinalDelPeriodo: false })
        expect(r.alFinalDelPeriodo).toBe(false)
    })

    it('normaliza el motivo quitando espacios', () => {
        const r = cancelarSuscripcionSchema.parse({ motivo: '  demasiado caro  ' })
        expect(r.motivo).toBe('demasiado caro')
    })

    it('rechaza un motivo vacío y uno de más de 300 caracteres', () => {
        expect(cancelarSuscripcionSchema.safeParse({ motivo: '   ' }).success).toBe(false)
        expect(cancelarSuscripcionSchema.safeParse({ motivo: 'x'.repeat(301) }).success).toBe(false)
    })

    // Cancelar no lleva id: se cancela la ACTIVA del usuario del token.
    // Aceptar un id permitiría cancelar la suscripción de otro.
    it('rechaza un id en el body', () => {
        expect(cancelarSuscripcionSchema.safeParse({ id: 'la-de-otro' }).success).toBe(false)
    })
})
