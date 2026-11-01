import fs from 'node:fs/promises'
import path from 'node:path'
import { afterEach, describe, expect, it } from 'vitest'
import { prisma } from '../../lib/prisma'
import { leerArchivoDeCv } from './cv.service'

const MARCA = '__test_cv_archivo__'
const CARPETA_SUBIDAS = path.join(__dirname, '../../../uploads')
const usuarios: string[] = []
const archivos: string[] = []

afterEach(async () => {
    for (const id of usuarios.splice(0)) {
        await prisma.usuario.delete({ where: { id } })
    }
    for (const archivo of archivos.splice(0)) {
        await fs.unlink(archivo).catch(() => {})
    }
})

async function escenario(conArchivo: boolean) {
    const sufijo = crypto.randomUUID()
    const crear = async (etiqueta: string) => {
        const u = await prisma.usuario.create({
            data: {
                nombre: MARCA,
                apellidos: MARCA,
                email: `${MARCA}-${etiqueta}-${sufijo}@test.local`,
                rol: 'CANDIDATO',
            },
        })
        usuarios.push(u.id)
        return u
    }
    const dueno = await crear('dueno')
    const otro = await crear('otro')

    const nombre = `${MARCA}${sufijo}.pdf`
    const ruta = path.join(CARPETA_SUBIDAS, nombre)
    const contenido = Buffer.from('%PDF-1.4 contenido de prueba')
    if (conArchivo) {
        await fs.mkdir(CARPETA_SUBIDAS, { recursive: true })
        await fs.writeFile(ruta, contenido)
        archivos.push(ruta)
    }
    const cv = await prisma.cv.create({
        data: { usuarioId: dueno.id, titulo: 'Mi CV de prueba', urlArchivo: `uploads/${nombre}` },
    })
    return { dueno, otro, cv, contenido }
}

describe('leerArchivoDeCv', () => {
    it('devuelve el PDF al dueño', async () => {
        const { dueno, cv, contenido } = await escenario(true)
        const resultado = await leerArchivoDeCv(dueno.id, cv.id)
        expect(resultado.titulo).toBe('Mi CV de prueba')
        expect(resultado.archivo.equals(contenido)).toBe(true)
    })

    it('devuelve 404 a otro usuario, como si no existiera', async () => {
        const { otro, cv } = await escenario(true)
        await expect(leerArchivoDeCv(otro.id, cv.id)).rejects.toMatchObject({ statusCode: 404 })
    })

    it('devuelve 404 si el archivo ya no está en disco', async () => {
        const { dueno, cv } = await escenario(false)
        await expect(leerArchivoDeCv(dueno.id, cv.id)).rejects.toMatchObject({
            statusCode: 404,
            message: 'El archivo del CV ya no está disponible',
        })
    })
})
