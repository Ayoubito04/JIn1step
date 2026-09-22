//Traduce HTTP <-> service. La validación del body ya la hizo validateBody.
import type { NextFunction, Request, Response } from 'express'
import * as suscripcionService from './suscripcion.service'
import { HttpError } from '../../lib/http-error'
import type {
    CancelarSuscripcionInput,
    IniciarSuscripcionInput,
} from './suscripcion.schema'

//requireAuth deja el usuario en req.usuario (ver src/types/express.d.ts).
function usuarioAutenticado(req: Request) {
    if (!req.usuario) {
        throw new HttpError(401, 'Falta el token de acceso')
    }
    return req.usuario
}

//Arranca el alta. La fila nace en PENDIENTE_PAGO: NO da acceso al autopiloto
//hasta que la pasarela confirme el cobro por webhook.
export async function crear(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        const suscripcion = await suscripcionService.CrearSuscripcion(
            usuario.id,
            req.body as IniciarSuscripcionInput,
        )
        res.status(201).json(suscripcion)
    } catch (err) {
        next(err)
    }
}

//La suscripción activa, o null. El frontend la usa para saber si enseñar el
//botón del autopiloto o el de contratar.
export async function miSuscripcion(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        res.status(200).json(
            await suscripcionService.ObtenerSuscripcionActiva(usuario.id),
        )
    } catch (err) {
        next(err)
    }
}

//Historial completo para la pantalla de facturación.
export async function listarMias(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        res.status(200).json(
            await suscripcionService.ListarMisSuscripciones(usuario.id),
        )
    } catch (err) {
        next(err)
    }
}

export async function cancelar(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        res.status(200).json(
            await suscripcionService.CancelarSuscripcion(
                usuario.id,
                req.body as CancelarSuscripcionInput,
            ),
        )
    } catch (err) {
        next(err)
    }
}
