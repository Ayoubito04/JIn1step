//Traduce HTTP <-> service. La validación del body ya la hizo validateBody.
import type { NextFunction, Request, Response } from 'express'
import { HttpError } from '../../lib/http-error'
import {
    obtenerPreferencias,
    actualizarPreferencias,
} from './preferencias_autopilot.service'
import type { ActualizarPreferenciasInput } from './preferencias_autopilot.schema'

//El middleware requireAuth deja el usuario en req.usuario. Como el tipo es
//opcional (podría no haberse pasado por requireAuth), lo forzamos aquí.
function usuarioAutenticado(req: Request) {
    if (!req.usuario) {
        throw new HttpError(401, 'Falta el token de acceso')
    }
    return req.usuario
}

export async function getPreferencias(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        res.status(200).json(await obtenerPreferencias(usuario.id))
    } catch (err) {
        next(err)
    }
}

export async function updatePreferencias(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        res.status(200).json(
            await actualizarPreferencias(
                usuario.id,
                req.body as ActualizarPreferenciasInput,
            ),
        )
    } catch (err) {
        next(err)
    }
}
