//Rutas de requisitos, anidadas bajo /api/ofertas/:ofertaId/requisitos.
//
//Van anidadas y no sueltas porque un requisito no existe por sí mismo: su
//identidad es la pareja (oferta, habilidad). La URL lo deja claro y evita
//tener que aceptar ofertaId por el body, que sería falsificable.
import { Router } from 'express'
import * as requisitoController from './oferta_requisito.controller'
import { requireRol } from '../../middlewares/auth.middleware'
import { validateBody } from '../../middlewares/validate.middleware'
import {
    actualizarRequisitoSchema,
    anadirRequisitoSchema,
    reemplazarRequisitosSchema,
} from './oferta_requisito.schema'

//mergeParams: true para poder leer :ofertaId del router padre. Sin esto,
//req.params.ofertaId sería undefined y todo daría 400.
export const ofertaRequisitoRouter = Router({ mergeParams: true })

//Sin requireAuth: lo hereda de ofertasRouter, que ya lo aplica.

//Lectura para ambos roles: el candidato necesita saber qué le piden antes de
//postularse, y es la misma información que usa calcularMatch.
ofertaRequisitoRouter.get('/', requisitoController.listar)

//Escritura solo para reclutadores. Que la oferta sea SUYA lo comprueba el
//service con ofertaDelReclutador.
ofertaRequisitoRouter.post(
    '/',
    requireRol('RECLUTADOR'),
    validateBody(anadirRequisitoSchema),
    requisitoController.anadir,
)

//PUT sobre la colección: reemplaza el conjunto entero de una vez. Es lo que
//necesita el formulario de edición de la oferta.
ofertaRequisitoRouter.put(
    '/',
    requireRol('RECLUTADOR'),
    validateBody(reemplazarRequisitosSchema),
    requisitoController.reemplazar,
)

//La habilidad identifica el requisito dentro de la oferta, así que va en la
//URL y no en el body.
ofertaRequisitoRouter.patch(
    '/:habilidadId',
    requireRol('RECLUTADOR'),
    validateBody(actualizarRequisitoSchema),
    requisitoController.actualizar,
)
ofertaRequisitoRouter.delete(
    '/:habilidadId',
    requireRol('RECLUTADOR'),
    requisitoController.quitar,
)
