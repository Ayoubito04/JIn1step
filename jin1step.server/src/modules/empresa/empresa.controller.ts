//Traduce HTTP <-> service. La validación del body ya la hizo validateBody.
import type { Request, Response, NextFunction } from 'express'
import * as empresaService from './empresa.service'
import { HttpError } from '../../lib/http-error'
import type { CrearEmpresaInput } from './empresa.schema'

//requireAuth deja el usuario en req.usuario (ver src/types/express.d.ts).
//El tipo es opcional porque una ruta podría no pasar por requireAuth.
function usuarioAutenticado(req: Request) {
    if (!req.usuario) {
        throw new HttpError(401, 'Falta el token de acceso')
    }
    return req.usuario
}

//En Express 5 los params se tipan como string | string[].
function leerParam(req: Request, nombre: string): string {
    const valor = req.params[nombre]

    if (typeof valor !== 'string' || valor.length === 0) {
        throw new HttpError(400, `Parámetro ${nombre} no válido`)
    }

    return valor
}

export async function crearEmpresa(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        //Se exige sesión aunque el service no use el id: sin esto cualquiera
        //sin token podría llenar la tabla de empresas basura.
        usuarioAutenticado(req)

        const empresa = await empresaService.crearEmpresa(
            req.body as CrearEmpresaInput,
        )
        res.status(201).json(empresa)
    } catch (err) {
        next(err)
    }
}

//Listado del catálogo. Lo usa el reclutador para elegir empresa al publicar y
//el candidato para saber de quién es la oferta a la que se postula.
export async function listarEmpresas(
    _req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        res.status(200).json(await empresaService.listarEmpresas())
    } catch (err) {
        next(err)
    }
}

export async function obtenerEmpresa(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        res.status(200).json(
            await empresaService.obtenerEmpresa(leerParam(req, 'id')),
        )
    } catch (err) {
        next(err)
    }
}
