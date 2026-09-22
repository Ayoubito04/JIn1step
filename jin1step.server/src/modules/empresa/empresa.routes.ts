//Aquí vamos a definir las rutas para poder crear 
//y consultar las empresas dentro de la app Jin1step

import {Router} from 'express'

import * as empresaController from './empresa.controller'
import { requireAuth, requireRol } from '../../middlewares/auth.middleware'
import { validateBody } from '../../middlewares/validate.middleware'
import { crearEmpresaSchema } from './empresa.schema'

export const empresaRouter = Router()

//Todas las rutas de empresas requieren autenticación y rol de reclutador
empresaRouter.use(requireAuth)
empresaRouter.use(requireRol('RECLUTADOR'))

//Crear una empresa
empresaRouter.post(
    '/',
    validateBody(crearEmpresaSchema),
    empresaController.crearEmpresa,
)

//Ver todas las empresas
empresaRouter.get('/', empresaController.verMisEmpresas)

