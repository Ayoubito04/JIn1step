//Rutas del disparador del autopiloto, montadas bajo /api/postulaciones-autopilot.
import { Router } from 'express'
import * as postulacionesAutopilotController from './postulaciones_autopilot.controller'
import { requireAuth, requireRol } from '../../middlewares/auth.middleware'

export const postulacionesAutopilotRouter = Router()

//Solo candidatos: los reclutadores no tienen autopiloto.
postulacionesAutopilotRouter.use(requireAuth)
postulacionesAutopilotRouter.use(requireRol('CANDIDATO'))

//POST porque crea recursos (postulaciones). No lleva body: toda la info viene
//de las preferencias guardadas + el token.
postulacionesAutopilotRouter.post(
    '/ejecutar',
    postulacionesAutopilotController.ejecutar,
)
