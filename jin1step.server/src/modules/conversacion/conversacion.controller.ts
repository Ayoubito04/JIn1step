//Traduce HTTP <-> service. La validación del body ya la hizo validateBody, y
//quién puede ver cada conversación lo decide el service: aquí no se toma
//ninguna decisión de seguridad.
import type { NextFunction, Request, Response } from 'express'
import * as conversacionService from './conversacion.service'
import { HttpError } from '../../lib/http-error'
import type { CrearConversacionInput } from './conversacion.schema'

function usuarioAutenticado(req: Request) {
    if (!req.usuario) {
        throw new HttpError(401, 'Falta el token de acceso')
    }

    return req.usuario
}

//Abre la conversación con otro usuario, o devuelve la que ya existía.
//
//201 si la crea, 200 si ya estaba: es la diferencia entre "he creado un
//recurso" y "aquí tienes el que ya había". El frontend abre el chat igual en
//los dos casos, pero un 201 mentiría sobre lo que ha pasado en el servidor.
export async function abrirConversacion(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)

        //El rol viaja al service porque es quien decide si eres el candidato o
        //el reclutador de la fila. No se deduce del body a propósito.
        const { creada, conversacion } = await conversacionService.abrirConversacion(
            usuario.id,
            usuario.rol,
            req.body as CrearConversacionInput,
        )

        res.status(creada ? 201 : 200).json(conversacion)
    } catch (err) {
        next(err)
    }
}

//Bandeja de entrada: las conversaciones del usuario con su último mensaje y
//cuántos le quedan sin leer, para pintarla de una sola petición.
export async function listarMisConversaciones(
    req: Request,
    res: Response,
    next: NextFunction,
): Promise<void> {
    try {
        const usuario = usuarioAutenticado(req)

        res.status(200).json(
            await conversacionService.listarMisConversaciones(usuario.id),
        )
    } catch (err) {
        next(err)
    }
}
