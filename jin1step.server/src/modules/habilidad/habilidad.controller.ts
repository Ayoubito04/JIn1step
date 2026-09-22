//Traduce HTTP <-> service. La validación de body ya la hizo validateBody.
import type { NextFunction, Request, Response } from 'express'
import * as habilidadService from './habilidad.service'
import { HttpError } from '../../lib/http-error'
import type {
    ActualizarNivelInput,
    AsignarHabilidadInput,
} from './habilidad.schema'

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

export async function listarCatalogo(
    _req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        res.status(200).json(await habilidadService.listarCatalogo())
    } catch (err) {
        next(err)
    }
}

export async function listarDeCv(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        res.status(200).json(
            await habilidadService.listarHabilidadesDeCv(
                usuario.id,
                leerParam(req, 'cvId'),
            ),
        )
    } catch (err) {
        next(err)
    }
}

export async function asignar(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        const creada = await habilidadService.asignarHabilidadACv(
            usuario.id,
            leerParam(req, 'cvId'),
            req.body as AsignarHabilidadInput,
        )
        res.status(201).json(creada)
    } catch (err) {
        next(err)
    }
}

export async function actualizarNivel(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        res.status(200).json(
            await habilidadService.actualizarNivelHabilidad(
                usuario.id,
                leerParam(req, 'cvId'),
                leerParam(req, 'habilidadId'),
                req.body as ActualizarNivelInput,
            ),
        )
    } catch (err) {
        next(err)
    }
}

export async function quitar(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        await habilidadService.quitarHabilidadDeCv(
            usuario.id,
            leerParam(req, 'cvId'),
            leerParam(req, 'habilidadId'),
        )
        res.status(204).end()
    } catch (err) {
        next(err)
    }
}
