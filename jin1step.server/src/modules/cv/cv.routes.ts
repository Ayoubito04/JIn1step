//Rutas de CV, montadas bajo /api/cv. Todas exigen estar autenticado.
import { Router } from 'express'
import multer from 'multer'
import * as cvController from './cv.controller'
import { requireAuth } from '../../middlewares/auth.middleware'
import { validateBody } from '../../middlewares/validate.middleware'
import { HttpError } from '../../lib/http-error'
import { subirCvSchema } from './cv.schema'

const MAX_TAMANO_BYTES = 5 * 1024 * 1024 // 5 MB

//memoryStorage: el archivo llega como Buffer y es el service quien decide
//dónde y con qué nombre se guarda. Con diskStorage multer escribiría el archivo
//antes de validarlo, dejando basura en disco cuando el PDF no sirve.
const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: MAX_TAMANO_BYTES, files: 1 },
    fileFilter: (_req, file, cb) => {
        if (file.mimetype !== 'application/pdf') {
            //HttpError y no Error a secas: un Error normal no lo reconoce el
            //ErrorHandler y acabaría saliendo como 500 en vez de 400.
            cb(new HttpError(400, 'Solo se aceptan archivos PDF'))
            return
        }
        cb(null, true)
    },
})

export const cvRouter = Router()

cvRouter.use(requireAuth)

//El orden importa: multer primero, porque hasta que no procesa el multipart
//req.body está vacío y validateBody rechazaría el título.
cvRouter.post('/', upload.single('archivo'), validateBody(subirCvSchema), cvController.subirCv)
cvRouter.get('/', cvController.listarMisCvs)
cvRouter.get('/:id', cvController.obtenerCv)
cvRouter.delete('/:id', cvController.borrarCv)
