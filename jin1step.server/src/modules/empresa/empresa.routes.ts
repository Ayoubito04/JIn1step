//Rutas de empresas, montadas bajo /api/empresas.

import { Router } from 'express'

import * as empresaController from './empresa.controller'
import { requireAuth, requireRol } from '../../middlewares/auth.middleware'
import { validateBody } from '../../middlewares/validate.middleware'
import { crearEmpresaSchema } from './empresa.schema'

export const empresaRouter = Router()

//Solo la sesión es común a todas las rutas. El requireRol NO va aquí: si se
//aplica al router entero, un candidato no puede ver de qué empresa es la
//oferta a la que se está postulando, que es información que necesita.
empresaRouter.use(requireAuth)

//Lectura para ambos roles: el reclutador la usa para elegir empresa al
//publicar una oferta, y el candidato para ver la ficha de quien la publica.
empresaRouter.get('/', empresaController.listarEmpresas)
empresaRouter.get('/:id', empresaController.obtenerEmpresa)

//Dar de alta una empresa sí es cosa de reclutadores: un candidato con token
//válido no debe poder crear empresas.
empresaRouter.post(
    '/',
    requireRol('RECLUTADOR'),
    validateBody(crearEmpresaSchema),
    empresaController.crearEmpresa,
)
