//Rutas del perfil de candidato y su red profesional, montadas bajo /api/perfil-candidato.
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

//Las rutas fijas ("/mio", "/red") van ANTES de /:candidatoId. Si no, Express
//las interpretaría como un id de candidato.
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
candidatoPerfilRouter.post(
    '/mio/foto',
    requireRol('CANDIDATO'),
    uploadBanner.single('archivo'),
    perfilController.subirFotoPerfil,
)
candidatoPerfilRouter.delete(
    '/mio/foto',
    requireRol('CANDIDATO'),
    perfilController.borrarFotoPerfil,
)
candidatoPerfilRouter.delete(
    '/mio',
    requireRol('CANDIDATO'),
    perfilController.borrarMiPerfil,
)

// Red profesional entre candidatos (seguidores, siguiendo y directorio)
candidatoPerfilRouter.get(
    '/red',
    requireRol('CANDIDATO'),
    perfilController.redCandidatos,
)
candidatoPerfilRouter.post(
    '/:candidatoId/seguir',
    requireRol('CANDIDATO'),
    perfilController.seguirCandidato,
)
candidatoPerfilRouter.delete(
    '/:candidatoId/seguir',
    requireRol('CANDIDATO'),
    perfilController.dejarDeSeguirCandidato,
)

//Tanto RECLUTADOR (al revisar una candidatura) como CANDIDATO (en la red social)
//pueden ver el perfil completo de un candidato.
candidatoPerfilRouter.get(
    '/:candidatoId',
    requireRol('RECLUTADOR', 'CANDIDATO'),
    perfilController.perfilDeCandidato,
)
