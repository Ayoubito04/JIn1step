//Ahora definimos los controladores de las empresas


import type { Request, Response, NextFunction } from 'express'
import * as empresaService from './empresa.service'
import { HttpError } from '../../lib/http-error'

export const crearEmpresa = async (req: Request, res: Response, next: NextFunction) => {
    try {
        //El middleware requireAuth deja al usuario en req.usuario.
        //Como el tipo es opcional (podría no haberse pasado por requireAuth),
        //lo forzamos aquí.
        const usuario = req.usuario
        if (!usuario) {
            throw new HttpError(401, 'Usuario no autenticado')
        }
        const empresa = await empresaService.CrearEmpresa(usuario.id, req.body)
        res.status(201).json(empresa)
    } catch (error) {
        next(error)
    }
}

export const verMisEmpresas = async (req: Request, res: Response, next: NextFunction) => {
    try {
        //El middleware requireAuth deja al usuario en req.usuario.
        //Como el tipo es opcional (podría no haberse pasado por requireAuth),
        //lo forzamos aquí.
        const usuario = req.usuario
        if (!usuario) {
            throw new HttpError(401, 'Usuario no autenticado')
        }
        const empresas = await empresaService.VerMisEmpresas(usuario.id)
        res.status(200).json(empresas)
    } catch (error) {
        next(error)
    }
}

