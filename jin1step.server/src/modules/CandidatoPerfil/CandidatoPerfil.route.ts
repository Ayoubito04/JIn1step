//Rutas del perfil de candidato, montadas bajo /api/perfil-candidato.
import { Router } from 'express'
import multer from 'multer'
import * as perfilController from './CandidatoPerfil.controller'
import { requireAuth, requireRol } from '../../middlewares/auth.middleware'
import { validateBody } from '../../middlewares/validate.middleware'
import { HttpError } from '../../lib/http-error'
import { actualizarPerfilSchema } from './CandidatoPerfil.schema'

const MAX_BANNER_BYTES = 5 * 1024 * 1024 // 5 MB
const TIPOS_IMAGEN = new Set([
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'image/gif',
])

const uploadBanner = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: MAX_BANNER_BYTES, files: 1 },
    fileFilter: (_req, file, cb) => {
        if (!TIPOS_IMAGEN.has(file.mimetype.toLowerCase())) {
            cb(
                new HttpError(
                    400,
                    'Solo se aceptan imágenes JPG, PNG, WEBP o GIF para el banner',
                ),
            )
            return
        }
        cb(null, true)
    },
})

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
candidatoPerfilRouter.post(
    '/mio/banner',
    requireRol('CANDIDATO'),
    uploadBanner.single('archivo'),
    perfilController.subirBanner,
)
candidatoPerfilRouter.delete(
    '/mio/banner',
    requireRol('CANDIDATO'),
    perfilController.borrarBanner,
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
