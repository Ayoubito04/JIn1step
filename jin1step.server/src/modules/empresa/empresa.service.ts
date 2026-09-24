//Lógica de empresas. Registro compartido: cualquier reclutador puede dar de
//alta una empresa; nadie las edita ni borra desde la API (para eso, admin
//desde la BD). Es la política más simple que evita vandalismo entre
//reclutadores sin necesidad de añadir `creadoPor` al modelo.
import { Prisma } from '@prisma/client'
import { prisma } from '../../lib/prisma'
import { HttpError } from '../../lib/http-error'
import type { CrearEmpresaInput } from './empresa.schema'

//Objeto, no array: es lo que espera el `select` de Prisma.
//Se explicita para no filtrar campos que se añadan al modelo en el futuro y
//no deban ser públicos (email de contacto interno, notas de admin…).
const CAMPOS_PUBLICOS = {
    id: true,
    nombre: true,
    sector: true,
    ubicacion: true,
    sitioWeb: true,
} as const

//Se llama "listar" y no "verMisEmpresas" porque el modelo Empresa NO tiene
//dueño: no hay usuarioId ni creadoPor. Sin ese campo es imposible filtrar por
//reclutador, y devolver todas llamándolo "mis empresas" sería mentir.
//
//Si algún día hace falta la propiedad real, se añade `creadoPor` al modelo con
//una migración y esta función pasa a recibir el usuarioId.
export async function listarEmpresas() {
    return prisma.empresa.findMany({
        select: CAMPOS_PUBLICOS,
        orderBy: { nombre: 'asc' },
    })
}

export async function obtenerEmpresa(id: string) {
    const empresa = await prisma.empresa.findUnique({
        where: { id },
        select: CAMPOS_PUBLICOS,
    })

    if (!empresa) {
        throw new HttpError(404, 'Empresa no encontrada')
    }

    return empresa
}

//No recibe usuarioId: el modelo no guarda quién la creó, así que aceptarlo
//sería un parámetro que no se usa y que hace pensar que sí se asocia.
//
//Tampoco comprueba "ya existe una con este nombre" a propósito: dos empresas
//pueden llamarse igual en distintos países ("Delta" aerolínea vs grifería).
//El deduplicado, si algún día molesta, lo hace un admin.
export async function crearEmpresa(datos: CrearEmpresaInput) {
    try {
        return await prisma.empresa.create({
            data: {
                nombre: datos.nombre,
                sector: datos.sector ?? null,
                ubicacion: datos.ubicacion ?? null,
                sitioWeb: datos.sitioWeb ?? null,
            },
            select: CAMPOS_PUBLICOS,
        })
    } catch (err) {
        //Hoy no hay ningún @unique en Empresa, pero se deja el escudo por si
        //se añade @unique(nombre) más adelante y se olvida traducirlo aquí.
        if (
            err instanceof Prisma.PrismaClientKnownRequestError &&
            err.code === 'P2002'
        ) {
            throw new HttpError(409, 'Ya existe una empresa con esos datos')
        }
        throw err
    }
}
