//Rutas de preferencias del autopiloto, montadas bajo /api/preferencias-autopilot.
import { Router } from 'express'
import * as preferenciasController from './preferencias_autopilot.controller'
import { requireAuth, requireRol } from '../../middlewares/auth.middleware'
import { validateBody } from '../../middlewares/validate.middleware'
import { actualizarPreferenciasSchema } from './preferencias_autopilot.schema'

export const preferenciasAutopilotRouter = Router()

preferenciasAutopilotRouter.use(requireAuth)
preferenciasAutopilotRouter.use(requireRol('CANDIDATO'))
//Para poder usar este servicio tendrías que ser candidato primeramente

//GET no valida body; siempre devuelve algo (defaults si no hay fila).
preferenciasAutopilotRouter.get('/', preferenciasController.getPreferencias)

//PATCH y no PUT: el schema es .partial(), el usuario puede mandar solo un campo.
preferenciasAutopilotRouter.patch(
    '/',
    validateBody(actualizarPreferenciasSchema),
    preferenciasController.updatePreferencias,
)
