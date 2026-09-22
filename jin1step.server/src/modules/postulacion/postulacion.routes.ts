//Rutas de postulaciones, montadas bajo /api/postulaciones.
import { Router } from 'express'
import * as postulacionController from './postulacion.controller'
import { requireAuth, requireRol } from '../../middlewares/auth.middleware'
import { validateBody } from '../../middlewares/validate.middleware'
import {
    actualizarPostulacionesSchema,
    CrearPostulacionesSchema,
    MatchingPostulacionesSchema,
} from './postulacion.schema'

export const postulacionRouter = Router()

postulacionRouter.use(requireAuth)

//Lado candidato
postulacionRouter.post(
    '/',
    requireRol('CANDIDATO'),
    validateBody(CrearPostulacionesSchema),
    postulacionController.crearPostulacion,
)
postulacionRouter.get(
    '/mias',
    requireRol('CANDIDATO'),
    postulacionController.listarMisPostulaciones,
)
//Ver el match sin postularse. Es POST porque lleva cuerpo, aunque no cree nada.
postulacionRouter.post(
    '/simular-match',
    requireRol('CANDIDATO'),
    validateBody(MatchingPostulacionesSchema),
    postulacionController.simularMatch,
)

//Lado reclutador
postulacionRouter.get(
    '/oferta/:ofertaId',
    requireRol('RECLUTADOR'),
    postulacionController.listarPostulacionesDeOferta,
)
postulacionRouter.patch(
    '/:id',
    requireRol('RECLUTADOR'),
    validateBody(actualizarPostulacionesSchema),
    postulacionController.actualizarEstado,
)
