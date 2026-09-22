//Rutas de autenticación, montadas bajo /api/auth
import { Router } from 'express'
import rateLimit from 'express-rate-limit'
import * as authController from './auth.controller'
import { validateBody } from '../../middlewares/validate.middleware'
import { googleAuthSchema, loginSchema, registerSchema } from './auth.schema'

//El login es el objetivo típico de fuerza bruta, así que va limitado por IP
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 10,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    message: { error: 'Demasiados intentos. Prueba de nuevo en unos minutos.' },
})

export const authRouter = Router()

authRouter.post(
    '/register',
    authLimiter,
    validateBody(registerSchema),
    authController.register,
)
authRouter.post('/login', authLimiter, validateBody(loginSchema), authController.login)
authRouter.post(
    '/login/google',
    authLimiter,
    validateBody(googleAuthSchema),
    authController.loginConGoogle,
)
