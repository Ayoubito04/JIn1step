//Lógica de empresas. Registro compartido: cualquier reclutador puede dar de
//alta una empresa; nadie las edita ni borra desde la API (para eso, admin
//desde la BD). Es la política más simple que evita vandalismo entre
//reclutadores sin necesidad de añadir `creadoPor` al modelo.
import { Prisma } from '@prisma/client'
import { prisma } from '../../lib/prisma'
import { HttpError } from '../../lib/http-error'
import { CrearEmpresaInput } from './empresa.schema'

//La lógica de ofertas
export const CamposPublicos = [
    {
        id: true,
        nombre: true,
        sector: true,
        ubicacion: true,
        sitioWeb: true,

    }
]
//Tenemos todos los campos necesarios para la empresaç

//En el modelo de empresa están todos los campos necesarios para la empresa

export const CrearEmpresa = async (id: string, datos: CrearEmpresaInput) => {
    const empresa = await prisma.empresa.create({
        data: {
            nombre: datos.nombre,
            sector: datos.sector,
            ubicacion: datos.ubicacion,
            sitioWeb: datos.sitioWeb,


        }
    })
    return empresa
}
export const VerMisEmpresas = async (idUsuario: string) => {
    const MisEmpresas = await prisma.empresa.findMany({
        select: {
            id: true,
            nombre: true,
            sector: true,
            ubicacion: true,
            sitioWeb: true,
        }
    })
    return MisEmpresas
}
















