//Traduce HTTP <-> service. La validación ya la hizo validateBody.
import type { NextFunction, Request, Response } from 'express'
import * as postulacionService from './postulacion.service'
import { HttpError } from '../../lib/http-error'
import type {
    ActualizarPostulacionesInput,
    CrearPostulacionesInput,
    MatchingPostulacionesInput,
} from './postulacion.schema'

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

export async function crearPostulacion(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)

        //postuladoPorIa se queda en false: este endpoint es el manual.
        //El autopiloto llamará al service con true.
        const postulacion = await postulacionService.crearPostulacion(
            usuario.id,
            req.body as CrearPostulacionesInput,
        )

        res.status(201).json(postulacion)
    } catch (err) {
        next(err)
    }
}

export async function listarMisPostulaciones(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)

        res.status(200).json(
            await postulacionService.listarPostulacionesDeCandidato(usuario.id),
        )
    } catch (err) {
        next(err)
    }
}

export async function listarPostulacionesDeOferta(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)

        res.status(200).json(
            await postulacionService.listarPostulacionesDeOferta(
                usuario.id,
                leerParam(req, 'ofertaId'),
            ),
        )
    } catch (err) {
        next(err)
    }
}

export async function actualizarEstado(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)

        res.status(200).json(
            await postulacionService.actualizarEstadoPostulacion(
                usuario.id,
                leerParam(req, 'id'),
                req.body as ActualizarPostulacionesInput,
            ),
        )
    } catch (err) {
        next(err)
    }
}

export async function simularMatch(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        const { cvId, ofertaId } = req.body as MatchingPostulacionesInput

        res.status(200).json(
            await postulacionService.simularMatch(usuario.id, cvId, ofertaId),
        )
    } catch (err) {
        next(err)
    }
}
