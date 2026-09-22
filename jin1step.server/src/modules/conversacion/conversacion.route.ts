//Rutas de conversaciones, montadas bajo /api/conversaciones.
import { Router } from 'express'
import * as conversacionController from './conversacion.controller'
import { mensajesDeConversacionRouter } from '../mensaje/mensaje.routes'
import { requireAuth, requireRol } from '../../middlewares/auth.middleware'
import { validateBody } from '../../middlewares/validate.middleware'
import { crearConversacionSchema } from './conversacion.schema'

export const conversacionRouter = Router()

conversacionRouter.use(requireAuth)

//Los dos roles usan estos endpoints, así que no hay requireRol por endpoint;
//pero sí se deja fuera a ADMIN, que no tiene por qué entrar en el chat privado
//de dos usuarios. Quién puede ver CADA conversación lo decide el service.
conversacionRouter.use(requireRol('CANDIDATO', 'RECLUTADOR'))

//Bandeja de entrada.
conversacionRouter.get('/', conversacionController.listarMisConversaciones)

//Abre la conversación con otro usuario, o devuelve la que ya había.
//201 si la crea, 200 si ya existía.
conversacionRouter.post(
    '/',
    validateBody(crearConversacionSchema),
    conversacionController.abrirConversacion,
)

//Los mensajes cuelgan de la conversación, que es lo que son de verdad: no
//existen fuera de un hilo. Por eso el router de mensajes se monta anidado aquí
//en vez de vivir suelto bajo /api/mensajes.
//
//Ese router se crea con { mergeParams: true }, sin lo cual :conversacionId no
//llegaría a sus handlers: por defecto un router hijo no ve los params del
//padre, y req.params saldría vacío.
conversacionRouter.use('/:conversacionId/mensajes', mensajesDeConversacionRouter)
