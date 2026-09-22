//Traduce entre HTTP y el service. La validación del body la hizo validateBody
//y la del archivo multer; aquí solo se recogen los datos y se responde.
import type { NextFunction, Request, Response } from 'express'
import * as cvService from './cv.service'
import { HttpError } from '../../lib/http-error'
import type { SubirCvInput } from './cv.schema'

//En Express 5 req.params.id se tipa como string | string[], porque una ruta
//puede repetir el mismo nombre de parámetro. Aquí solo vale un id suelto.
function leerIdDeLaRuta(req: Request): string {
    const id = req.params.id

    if (typeof id !== 'string' || id.length === 0) {
        throw new HttpError(400, 'Id de CV no válido')
    }

    return id
}

export async function subirCv(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        //requireAuth garantiza que existe, pero TypeScript no lo sabe
        if (!req.usuario) {
            throw new HttpError(401, 'Falta el token de acceso')
        }

        if (!req.file) {
            throw new HttpError(400, 'Falta el archivo del CV (campo "archivo")')
        }

        const { titulo } = req.body as SubirCvInput

        //El usuarioId sale SIEMPRE del token, nunca del body: si se aceptara del
        //cliente, cualquiera podría subir CVs en nombre de otro.
        const cv = await cvService.subirCv(req.usuario.id, titulo, req.file)

        res.status(201).json(cv)
    } catch (err) {
        next(err)
    }
}

export async function listarMisCvs(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        if (!req.usuario) {
            throw new HttpError(401, 'Falta el token de acceso')
        }

        res.status(200).json(await cvService.listarCvsDeUsuario(req.usuario.id))
    } catch (err) {
        next(err)
    }
}

export async function obtenerCv(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        if (!req.usuario) {
            throw new HttpError(401, 'Falta el token de acceso')
        }

        res.status(200).json(
            await cvService.obtenerCv(req.usuario.id, leerIdDeLaRuta(req)),
        )
    } catch (err) {
        next(err)
    }
}

export async function borrarCv(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        if (!req.usuario) {
            throw new HttpError(401, 'Falta el token de acceso')
        }

        res.status(200).json(
            await cvService.borrarCv(req.usuario.id, leerIdDeLaRuta(req)),
        )
    } catch (err) {
        next(err)
    }
}
