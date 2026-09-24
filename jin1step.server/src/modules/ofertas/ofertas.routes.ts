//Rutas de ofertas, montadas bajo /api/ofertas.
import { Router } from 'express'
import * as ofertasController from './ofertas.controller'
import { requireAuth, requireRol } from '../../middlewares/auth.middleware'
import { validateBody } from '../../middlewares/validate.middleware'
import { actualizarOfertaSchema, crearOfertaSchema } from './ofertas.schema'
import { ofertaRequisitoRouter } from '../oferta_requisito/oferta_requisito.routes'

export const ofertasRouter = Router()

//Todo exige estar identificado: el listado enseña datos del reclutador.
ofertasRouter.use(requireAuth)

//Las de un reclutador van ANTES de /:id, si no Express interpretaría "mias"
//como un id y acabaría en un 404 de oferta no encontrada.
ofertasRouter.get('/mias', requireRol('RECLUTADOR'), ofertasController.listarMisOfertas)

ofertasRouter.get('/', ofertasController.listarOfertas)
ofertasRouter.get('/:id', ofertasController.obtenerOferta)

//Publicar y editar son solo para reclutadores: un candidato con token válido
//no debe poder crear ofertas.
ofertasRouter.post(
    '/',
    requireRol('RECLUTADOR'),
    validateBody(crearOfertaSchema),
    ofertasController.crearOferta,
)
ofertasRouter.patch(
    '/:id',
    requireRol('RECLUTADOR'),
    validateBody(actualizarOfertaSchema),
    ofertasController.actualizarOferta,
)

//Requisitos de la oferta, anidados. Heredan requireAuth de este router.
ofertasRouter.use('/:ofertaId/requisitos', ofertaRequisitoRouter)
