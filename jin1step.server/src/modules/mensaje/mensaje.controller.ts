//Traduce HTTP <-> service. La validación del body ya la hizo validateBody, y
//la comprobación de que el usuario participa en la conversación la hace el
//service: aquí no se decide nada de seguridad, solo se leen params y se elige
//el código de estado.
import type { NextFunction, Request, Response } from 'express'
import * as mensajesService from './mensajes.service'
import { HttpError } from '../../lib/http-error'
import type { EnviarMensajeInput } from './mensajes.schema'

function usuarioAutenticado(req: Request) {
    if (!req.usuario) {
        throw new HttpError(401, 'Falta el token de acceso')
    }

    return req.usuario
}

//En Express 5 los params se tipan como string | string[].
//
//conversacionId viene del router PADRE (/conversaciones/:conversacionId), y
//solo llega hasta aquí porque mensajesDeConversacionRouter se crea con
//{ mergeParams: true }. Sin eso esto devolvería 400 en todas las peticiones.
function leerParam(req: Request, nombre: string): string {
    const valor = req.params[nombre]

    if (typeof valor !== 'string' || valor.length === 0) {
        throw new HttpError(400, `Parámetro ${nombre} no válido`)
    }

    return valor
}

//Los mensajes de un hilo. Abrirlo marca como leídos los del otro, así que
//este GET no es del todo idempotente: cambia el estado de "leido".
//Es lo que hace cualquier chat, pero conviene saberlo antes de cachearlo.
export async function listarMensajes(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        const conversacionId = leerParam(req, 'conversacionId')

        res.status(200).json(
            await mensajesService.listarMensajes(usuario.id, conversacionId),
        )
    } catch (err) {
        next(err)
    }
}

//Envía un mensaje al hilo. El emisor sale del token, nunca del body.
export async function enviarMensaje(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)
        const conversacionId = leerParam(req, 'conversacionId')

        const mensaje = await mensajesService.enviarMensaje(
            usuario.id,
            conversacionId,
            req.body as EnviarMensajeInput,
        )

        res.status(201).json(mensaje)
    } catch (err) {
        next(err)
    }
}

//Contador global para el badge de la campanita.
//Se devuelve como objeto y no como número pelado para poder añadirle campos
//después (por ejemplo, cuántas conversaciones tienen algo sin leer) sin
//romper a los clientes que ya lo consumen.
export async function contarNoLeidos(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)

        res.status(200).json({
            sinLeer: await mensajesService.contarNoLeidos(usuario.id),
        })
    } catch (err) {
        next(err)
    }
}
