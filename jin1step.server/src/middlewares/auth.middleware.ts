//Protege rutas: exige un accessToken válido y deja el usuario en req.usuario.
import type { NextFunction, Request, Response } from 'express'
import jwt from 'jsonwebtoken'
import type { Rol } from '@prisma/client'
import { env } from '../config/env'
import { HttpError } from '../lib/http-error'

type TokenPayload = {
    sub: string
    rol: Rol
}

export function requireAuth(req: Request, _res: Response, next: NextFunction): void {
    const cabecera = req.headers.authorization

    if (!cabecera?.startsWith('Bearer ')) {
        next(new HttpError(401, 'Falta el token de acceso'))
        return
    }

    const token = cabecera.slice('Bearer '.length).trim()

    try {
        //verify comprueba la firma Y la expiración. Si el token está caducado
        //lanza TokenExpiredError, que aquí se traduce a un 401 con su mensaje
        //propio para que el cliente sepa que debe renovarlo.
        const payload = jwt.verify(token, env.jwtSecret) as TokenPayload

        req.usuario = { id: payload.sub, rol: payload.rol }
        next()
    } catch (err) {
        if (err instanceof jwt.TokenExpiredError) {
            next(new HttpError(401, 'El token de acceso ha caducado'))
            return
        }
        next(new HttpError(401, 'Token de acceso no válido'))
    }
}

//Restringe una ruta a ciertos roles. Se usa SIEMPRE después de requireAuth.
export function requireRol(...rolesPermitidos: Rol[]) {
    return (req: Request, _res: Response, next: NextFunction): void => {
        if (!req.usuario) {
            next(new HttpError(401, 'Falta el token de acceso'))
            return
        }

        if (!rolesPermitidos.includes(req.usuario.rol)) {
            //403 y no 401: el usuario está identificado, simplemente no le
            //corresponde esta ruta.
            next(new HttpError(403, 'No tienes permiso para esta acción'))
            return
        }

        next()
    }
}
