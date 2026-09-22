//Rutas de mensajes. Salen DOS routers a propósito, porque los mensajes se
//usan desde dos sitios distintos:
//
//  - mensajesDeConversacionRouter  anidado bajo /api/conversaciones/:id/mensajes.
//                                  Un mensaje no existe fuera de un hilo, así
//                                  que su URL cuelga de la conversación.
//  - mensajeRouter                 suelto bajo /api/mensajes, solo para lo que
//                                  NO pertenece a un hilo concreto: el
//                                  contador global del badge.
import { Router } from 'express'
import * as mensajeController from './mensaje.controller'
import { requireAuth, requireRol } from '../../middlewares/auth.middleware'
import { validateBody } from '../../middlewares/validate.middleware'
import { enviarMensajeSchema } from './mensajes.schema'

//mergeParams: true es OBLIGATORIO aquí, no un detalle de estilo.
//
//Por defecto un router hijo NO ve los params del padre: sin esto,
//req.params.conversacionId sería undefined en todos los handlers y cada
//petición acabaría en el 400 de leerParam. Es el fallo clásico de los routers
//anidados en Express, y no lo detecta TypeScript: compila igual y revienta en
//tiempo de ejecución.
export const mensajesDeConversacionRouter = Router({ mergeParams: true })

//Sin requireAuth ni requireRol: los hereda del conversacionRouter, que ya los
//aplica con .use() antes de montar este. Repetirlos aquí no rompería nada,
//pero haría creer que este router se puede montar suelto sin protección.
mensajesDeConversacionRouter.get('/', mensajeController.listarMensajes)

mensajesDeConversacionRouter.post(
    '/',
    validateBody(enviarMensajeSchema),
    mensajeController.enviarMensaje,
)

//Router suelto: este sí se monta directamente en el router principal, así que
//necesita su propia protección.
export const mensajeRouter = Router()

mensajeRouter.use(requireAuth)
mensajeRouter.use(requireRol('CANDIDATO', 'RECLUTADOR'))

//Badge de la campanita: cuántos mensajes tiene sin leer en TODAS sus
//conversaciones. No cuelga de ningún hilo, por eso no está en el router de
//arriba.
mensajeRouter.get('/sin-leer', mensajeController.contarNoLeidos)
