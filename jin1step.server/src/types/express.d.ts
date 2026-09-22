//Añade req.usuario al tipo Request de Express, que rellena requireAuth.
import type { Rol } from '@prisma/client'

declare global {
    namespace Express {
        interface Request {
            usuario?: {
                id: string
                rol: Rol
            }
        }
    }
}

export {}
