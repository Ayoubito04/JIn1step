//Ahora vamos con los controladores,una vez que tengamos la parte de servicios y la estructura de datos definida
//Traducen HTTP <-> service: la validación ya la hizo validateBody.
import type { NextFunction, Request, Response } from 'express'
import * as ofertasService from './ofertas.service'
import { HttpError } from '../../lib/http-error'
import type { ActualizarOfertaInput, CrearOfertaInput } from './ofertas.schema'

//requireAuth ya garantiza que req.usuario existe, pero TypeScript no lo sabe.
function usuarioAutenticado(req: Request) {
    if (!req.usuario) {
        throw new HttpError(401, 'Falta el token de acceso')
    }

    return req.usuario
}

//En Express 5 req.params.id se tipa como string | string[].
function leerIdDeLaRuta(req: Request): string {
    const id = req.params.id

    if (typeof id !== 'string' || id.length === 0) {
        throw new HttpError(400, 'Id de oferta no válido')
    }

    return id
}

export async function crearOferta(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        const oferta = await ofertasService.crearOferta(
            usuario.id,
            req.body as CrearOfertaInput,
        )

        res.status(201).json(oferta)
    } catch (err) {
        next(err)
    }
}

export async function listarOfertas(
    _req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        res.status(200).json(await ofertasService.listarOfertas())
    } catch (err) {
        next(err)
    }
}

export async function listarMisOfertas(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)

        res.status(200).json(
            await ofertasService.listarReclutadoresOfertas(usuario.id),
        )
    } catch (err) {
        next(err)
    }
}

export async function obtenerOferta(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        res.status(200).json(
            await ofertasService.obtenerOfertaPorId(leerIdDeLaRuta(req)),
        )
    } catch (err) {
        next(err)
    }
}

export async function actualizarOferta(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)

        res.status(200).json(
            await ofertasService.actualizarReclutadorOferta(
                usuario.id,
                leerIdDeLaRuta(req),
                req.body as ActualizarOfertaInput,
            ),
        )
    } catch (err) {
        next(err)
    }
}
