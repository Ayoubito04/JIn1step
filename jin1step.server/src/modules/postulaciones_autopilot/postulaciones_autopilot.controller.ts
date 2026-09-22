import type { NextFunction, Request, Response } from 'express'
import { HttpError } from '../../lib/http-error'
import { ejecutarAutopilot } from './postulaciones_autopilot.service'

function usuarioAutenticado(req: Request) {
    if (!req.usuario) {
        throw new HttpError(401, 'Falta el token de acceso')
    }
    return req.usuario
}

export async function ejecutar(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        res.status(200).json(await ejecutarAutopilot(usuario.id))
    } catch (err) {
        next(err)
    }
}
