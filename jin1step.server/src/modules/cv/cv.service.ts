//Lógica de negocio de los CV: guardar el archivo, extraer su texto y registrarlo.
import path from 'path'
import fs from 'fs/promises'
import crypto from 'crypto'
import { PDFParse } from 'pdf-parse'
import { prisma } from '../../lib/prisma'
import { HttpError } from '../../lib/http-error'
import { sincronizarHabilidadesDeCv } from './extraccion.service'

//Ruta absoluta a la carpeta de subidas. __dirname apunta a src/modules/cv
//(o dist/modules/cv en producción), de ahí los tres niveles hacia arriba.
const CARPETA_SUBIDAS = path.join(__dirname, '../../../uploads')

const EXTENSIONES_PERMITIDAS = ['.pdf'] as const

export type ArchivoSubido = {
    originalname: string
    mimetype: string
    buffer: Buffer
}

async function extraerTextoPdf(buffer: Buffer): Promise<string> {
    const parser = new PDFParse({ data: new Uint8Array(buffer) })

    try {
        const resultado = await parser.getText()
        return resultado.text.trim()
    } catch {
        //Un PDF corrupto o cifrado es culpa del archivo que mandan, no del
        //servidor: 400 en vez del 500 que saldría si dejáramos subir el error.
        throw new HttpError(400, 'No se ha podido leer el PDF. ¿Está dañado o protegido?')
    } finally {
        //Sin esto el worker de pdfjs queda vivo y el proceso no termina.
        await parser.destroy()
    }
}

export async function subirCv(
    usuarioId: string,
    titulo: string,
    archivo: ArchivoSubido,
) {
    const extension = path.extname(archivo.originalname).toLowerCase()

    if (!EXTENSIONES_PERMITIDAS.includes(extension as '.pdf')) {
        throw new HttpError(
            400,
            `La extensión ${extension || '(ninguna)'} no está permitida. Solo se aceptan ${EXTENSIONES_PERMITIDAS.join(', ')}`,
        )
    }

    //Se extrae el texto ANTES de escribir nada: si el PDF no se puede leer,
    //no queremos dejar un archivo huérfano en disco.
    const contenidoTexto = await extraerTextoPdf(archivo.buffer)

    await fs.mkdir(CARPETA_SUBIDAS, { recursive: true })

    //El nombre se genera aquí y nunca se usa el que manda el cliente: un
    //originalname como "../../.env" permitiría escribir fuera de uploads.
    //El sufijo aleatorio evita además que dos subidas del mismo usuario en el
    //mismo milisegundo se pisen.
    const nombreArchivo = `${usuarioId}_${Date.now()}_${crypto.randomBytes(6).toString('hex')}${extension}`

    //A disco va el PDF ORIGINAL, no el texto: el candidato tiene que poder
    //volver a descargarse su currículum tal cual lo subió.
    await fs.writeFile(path.join(CARPETA_SUBIDAS, nombreArchivo), archivo.buffer)

    try {
        const cv = await prisma.cv.create({
            data: {
                usuarioId,
                titulo,
                urlArchivo: `/uploads/${nombreArchivo}`,
                contenidoTexto,
            },
        })

        //Las habilidades se detectan al subir, no al postularse: así el cálculo
        //del match es una simple comparación de conjuntos y no hay que releer el
        //texto del CV en cada oferta.
        const habilidades = await sincronizarHabilidadesDeCv(cv.id, contenidoTexto)

        return { ...cv, habilidadesDetectadas: habilidades.map((h) => h.nombre) }
    } catch (err) {
        //Si el insert falla, el archivo ya está en disco: se borra para no
        //acumular ficheros que no apunta ningún registro.
        await fs.unlink(path.join(CARPETA_SUBIDAS, nombreArchivo)).catch(() => {})
        throw err
    }
}

export async function listarCvsDeUsuario(usuarioId: string) {
    return prisma.cv.findMany({
        where: { usuarioId },
        orderBy: { createdAt: 'desc' },
        //contenidoTexto puede ser enorme y no hace falta en un listado
        select: {
            id: true,
            titulo: true,
            urlArchivo: true,
            atsScore: true,
            createdAt: true,
        },
    })
}

export async function obtenerCv(usuarioId: string, cvId: string) {
    const cv = await prisma.cv.findUnique({ where: { id: cvId } })

    //Mismo 404 si no existe que si es de otro usuario: responder 403 delataría
    //que ese id existe y pertenece a alguien.
    if (!cv || cv.usuarioId !== usuarioId) {
        throw new HttpError(404, 'CV no encontrado')
    }

    return cv
}

export async function borrarCv(usuarioId: string, cvId: string) {
    const cv = await obtenerCv(usuarioId, cvId)

    await prisma.cv.delete({ where: { id: cv.id } })

    //El registro es lo que manda: si el archivo ya no estaba, no es un error.
    await fs
        .unlink(path.join(CARPETA_SUBIDAS, path.basename(cv.urlArchivo)))
        .catch(() => {})

    return { id: cv.id }
}
