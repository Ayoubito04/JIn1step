//Rutas de habilidades, montadas bajo /api/habilidades.
//El catálogo (/) es lectura pura; el resto opera sobre CvHabilidad y va
//scopeado por /cv/:cvId para dejar claro que son ajustes por CV.
import { Router } from 'express'
import * as habilidadController from './habilidad.controller'
import { requireAuth, requireRol } from '../../middlewares/auth.middleware'
import { validateBody } from '../../middlewares/validate.middleware'
import {
    actualizarNivelSchema,
    asignarHabilidadSchema,
} from './habilidad.schema'

export const habilidadRouter = Router()

//requireAuth también para el catálogo: es info interna, no un endpoint público
//del que puedan tirar bots para descargarnos el listado sin fricción.
habilidadRouter.use(requireAuth)

//El catálogo lo consultan candidatos (dropdown en su CV) y reclutadores (para
//marcar requisitos). Solo lectura, ambos roles pasan.
habilidadRouter.get('/', habilidadController.listarCatalogo)

//El resto son ajustes sobre CvHabilidad: solo el candidato dueño del CV.
//La comprobación de que el CV es SUYO se hace en el service (cvDelCandidato).
habilidadRouter.get(
    '/cv/:cvId',
    requireRol('CANDIDATO'),
    habilidadController.listarDeCv,
)
habilidadRouter.post(
    '/cv/:cvId',
    requireRol('CANDIDATO'),
    validateBody(asignarHabilidadSchema),
    habilidadController.asignar,
)
habilidadRouter.patch(
    '/cv/:cvId/:habilidadId',
    requireRol('CANDIDATO'),
    validateBody(actualizarNivelSchema),
    habilidadController.actualizarNivel,
)
habilidadRouter.delete(
    '/cv/:cvId/:habilidadId',
    requireRol('CANDIDATO'),
    habilidadController.quitar,
)
