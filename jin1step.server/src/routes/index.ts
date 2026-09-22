//Punto único donde se juntan los routers de cada módulo.
//Los nuevos módulos (cvs, ofertas, postulaciones...) se añaden aquí.
import { Router } from 'express'
import { authRouter } from '../modules/auth/auth.routes'
import { cvRouter } from '../modules/cv/cv.routes'
import { ofertasRouter } from '../modules/ofertas/ofertas.routes'
import { postulacionRouter } from '../modules/postulacion/postulacion.routes'
import { preferenciasAutopilotRouter } from '../modules/preferencias_autopilot/preferencias_autopilot.routes'
import { postulacionesAutopilotRouter } from '../modules/postulaciones_autopilot/postulaciones_autopilot.routes'
import { habilidadRouter } from '../modules/habilidad/habilidad.routes'
import { empresaRouter } from '../modules/empresa/empresa.routes'
import { conversacionRouter } from '../modules/conversacion/conversacion.route'
import { mensajeRouter } from '../modules/mensaje/mensaje.routes'

export const router = Router()

router.get('/health', (_req, res) => {
    res.json({
        status: 'ok',
    })
})

router.use('/auth', authRouter)
router.use('/cv', cvRouter)
router.use('/ofertas', ofertasRouter)
router.use('/postulaciones', postulacionRouter)
router.use('/preferencias-autopilot', preferenciasAutopilotRouter)
router.use('/postulaciones-autopilot', postulacionesAutopilotRouter)
router.use('/habilidades', habilidadRouter)
router.use('/empresas', empresaRouter)

//Los mensajes cuelgan de /conversaciones/:conversacionId/mensajes, montados
//dentro del conversacionRouter. Bajo /mensajes solo queda el contador global
//del badge, que no pertenece a ningún hilo concreto.
router.use('/conversaciones', conversacionRouter)
router.use('/mensajes', mensajeRouter)
