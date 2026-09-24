//Traduce HTTP <-> service. La validación del body ya la hizo validateBody.
import type { NextFunction, Request, Response } from 'express'
import * as requisitoService from './oferta_requisito.service'
import { HttpError } from '../../lib/http-error'
import type {
    ActualizarRequisitoInput,
    AnadirRequisitoInput,
    ReemplazarRequisitosInput,
} from './oferta_requisito.schema'

function usuarioAutenticado(req: Request) {
    if (!req.usuario) {
        throw new HttpError(401, 'Falta el token de acceso')
    }
    return req.usuario
}

//ofertaId viene del router PADRE (/ofertas/:ofertaId/requisitos) y solo llega
//aquí porque el router se crea con { mergeParams: true }.
function leerParam(req: Request, nombre: string): string {
    const valor = req.params[nombre]

    if (typeof valor !== 'string' || valor.length === 0) {
        throw new HttpError(400, `Parámetro ${nombre} no válido`)
    }

    return valor
}

//Lectura abierta a ambos roles: el candidato necesita ver qué le piden.
export async function listar(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        usuarioAutenticado(req)
        res.status(200).json(
            await requisitoService.listarRequisitos(leerParam(req, 'ofertaId')),
        )
    } catch (err) {
        next(err)
    }
}

export async function anadir(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        const creado = await requisitoService.anadirRequisito(
            usuario.id,
            leerParam(req, 'ofertaId'),
            req.body as AnadirRequisitoInput,
        )
        res.status(201).json(creado)
    } catch (err) {
        next(err)
    }
}

export async function actualizar(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        res.status(200).json(
            await requisitoService.actualizarRequisito(
                usuario.id,
                leerParam(req, 'ofertaId'),
                leerParam(req, 'habilidadId'),
                req.body as ActualizarRequisitoInput,
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
        await requisitoService.quitarRequisito(
            usuario.id,
            leerParam(req, 'ofertaId'),
            leerParam(req, 'habilidadId'),
        )
        res.status(204).end()
    } catch (err) {
        next(err)
    }
}

//PUT y no PATCH: reemplaza el conjunto entero, no lo parchea.
export async function reemplazar(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        res.status(200).json(
            await requisitoService.reemplazarRequisitos(
                usuario.id,
                leerParam(req, 'ofertaId'),
                req.body as ReemplazarRequisitosInput,
            ),
        )
    } catch (err) {
        next(err)
    }
}
