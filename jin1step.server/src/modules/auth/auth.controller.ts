//Traduce entre HTTP y el service: lee el body, llama, responde.
//La validación ya la hizo validateBody en la ruta, así que aquí req.body
//viene parseado y normalizado por zod.
import type { NextFunction, Request, Response } from 'express'
import * as authService from './auth.service'
import type {
    GoogleAuthInput,
    LinkedinAuthInput,
    LoginInput,
    RegisterInput,
} from './auth.schema'

export async function register(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const resultado = await authService.register(req.body as RegisterInput)
        res.status(201).json(resultado)
    } catch (err) {
        next(err)
    }
}

export async function login(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const resultado = await authService.login(req.body as LoginInput)
        res.status(200).json(resultado)
    } catch (err) {
        next(err)
    }
}

export async function loginConGoogle(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const resultado = await authService.loginConGoogle(req.body as GoogleAuthInput)
        res.status(200).json(resultado)
    } catch (err) {
        next(err)
    }
}

export async function loginConLinkedin(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const resultado = await authService.loginConLinkedin(
            req.body as LinkedinAuthInput,
        )
        res.status(200).json(resultado)
    } catch (err) {
        next(err)
    }
}

export async function sincronizarLinkedin(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const resultado = await authService.sincronizarConLinkedinUsuarioActual(
            req.usuario!.id,
            req.body as LinkedinAuthInput,
        )
        res.status(200).json(resultado)
    } catch (err) {
        next(err)
    }
}
