//Traduce HTTP <-> service. La validación del body ya la hizo validateBody.
import type { NextFunction, Request, Response } from 'express'
import * as perfilService from './CandidatoPerfil.service'
import { HttpError } from '../../lib/http-error'
import type { ActualizarPerfilInput } from './CandidatoPerfil.schema'

//requireAuth deja el usuario en req.usuario (ver src/types/express.d.ts).
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

export async function miPerfil(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        res.status(200).json(await perfilService.obtenerMiPerfil(usuario.id))
    } catch (err) {
        next(err)
    }
}

export async function actualizarMiPerfil(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        res.status(200).json(
            await perfilService.actualizarMiPerfil(
                usuario.id,
                req.body as ActualizarPerfilInput,
            ),
        )
    } catch (err) {
        next(err)
    }
}

//Lo consulta el reclutador al revisar una candidatura.
export async function perfilDeCandidato(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        usuarioAutenticado(req)
        res.status(200).json(
            await perfilService.obtenerPerfilDeCandidato(
                leerParam(req, 'candidatoId'),
            ),
        )
    } catch (err) {
        next(err)
    }
}

export async function borrarMiPerfil(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        await perfilService.borrarMiPerfil(usuario.id)
        res.status(204).end()
    } catch (err) {
        next(err)
    }
}
