//Rutas del disparador del autopiloto, montadas bajo /api/postulaciones-autopilot.
import { Router } from 'express'
import * as postulacionesAutopilotController from './postulaciones_autopilot.controller'
import { requireAuth, requireRol } from '../../middlewares/auth.middleware'
import { env } from '../../config/env'

export const postulacionesAutopilotRouter = Router()

//Solo candidatos: los reclutadores no tienen autopiloto.
postulacionesAutopilotRouter.use(requireAuth)
postulacionesAutopilotRouter.use(requireRol('CANDIDATO'))

// Simula coincidencias para probar la configuración sin pago ni escrituras.
// Se oculta en producción para que el plan de pago no tenga una vía gratuita.
if (!env.isProduction) {
    postulacionesAutopilotRouter.post(
        '/previsualizar',
        postulacionesAutopilotController.previsualizar,
    )
}

//POST porque crea recursos (postulaciones). No lleva body: toda la info viene
//de las preferencias guardadas + el token.
postulacionesAutopilotRouter.post(
    '/ejecutar',
    postulacionesAutopilotController.ejecutar,
)
