//Rutas de suscripciones, montadas bajo /api/suscripciones.
import { Router } from 'express'
import * as suscripcionController from './suscripcion.controller'
import { requireAuth, requireRol } from '../../middlewares/auth.middleware'
import { validateBody } from '../../middlewares/validate.middleware'
import {
    cancelarSuscripcionSchema,
    iniciarSuscripcionSchema,
} from './suscripcion.schema'

export const suscripcionRouter = Router()

//Solo candidatos: el autopiloto de pago es suyo, el reclutador no lo usa.
suscripcionRouter.use(requireAuth)
suscripcionRouter.use(requireRol('CANDIDATO'))

//Devuelve la ACTIVA o null. El frontend decide con esto si enseña el botón de
//contratar o el del autopiloto.
suscripcionRouter.get('/mia', suscripcionController.miSuscripcion)

//Historial para la pantalla de facturación.
suscripcionRouter.get('/', suscripcionController.listarMias)

//Arranca el alta. Crea la fila en PENDIENTE_PAGO; no da acceso todavía.
suscripcionRouter.post(
    '/',
    validateBody(iniciarSuscripcionSchema),
    suscripcionController.crear,
)

//DELETE y no POST /cancelar: es la baja del recurso. No lleva id porque se
//cancela la ACTIVA del usuario del token.
suscripcionRouter.delete(
    '/',
    validateBody(cancelarSuscripcionSchema),
    suscripcionController.cancelar,
)

//OJO: aquí falta POST /webhook, que es quien pasa una suscripción a ACTIVA.
//No se monta en este router porque necesita express.raw() para conservar el
//body crudo que exige la verificación de firma, y este router va detrás del
//express.json() global. Su sitio es app.ts, antes del json().
