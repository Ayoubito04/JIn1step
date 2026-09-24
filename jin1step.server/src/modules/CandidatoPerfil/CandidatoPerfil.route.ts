//Rutas del perfil de candidato, montadas bajo /api/perfil-candidato.
import { Router } from 'express'
import * as perfilController from './CandidatoPerfil.controller'
import { requireAuth, requireRol } from '../../middlewares/auth.middleware'
import { validateBody } from '../../middlewares/validate.middleware'
import { actualizarPerfilSchema } from './CandidatoPerfil.schema'

export const candidatoPerfilRouter = Router()

candidatoPerfilRouter.use(requireAuth)

//Las rutas de "mi perfil" van ANTES de /:candidatoId. Si no, Express
//interpretaría "mio" como un id y buscaría un candidato llamado así.
//
//Solo CANDIDATO: un reclutador no tiene perfil de candidato que editar.
candidatoPerfilRouter.get(
    '/mio',
    requireRol('CANDIDATO'),
    perfilController.miPerfil,
)
candidatoPerfilRouter.patch(
    '/mio',
    requireRol('CANDIDATO'),
    validateBody(actualizarPerfilSchema),
    perfilController.actualizarMiPerfil,
)
//204 y sin body: borra ubicación y disponibilidad, NO la cuenta.
candidatoPerfilRouter.delete(
    '/mio',
    requireRol('CANDIDATO'),
    perfilController.borrarMiPerfil,
)

//Solo RECLUTADOR: lo consulta al revisar una candidatura. Un candidato no
//tiene por qué poder mirar el perfil de otros candidatos.
candidatoPerfilRouter.get(
    '/:candidatoId',
    requireRol('RECLUTADOR'),
    perfilController.perfilDeCandidato,
)
