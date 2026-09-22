//Cliente de Prisma compartido por toda la app
import { PrismaClient } from '@prisma/client'
import { env } from '../config/env'

//En desarrollo ts-node-dev reinicia el proceso en cada guardado. Si creáramos
//un PrismaClient nuevo cada vez, se acumularían conexiones abiertas contra
//Postgres hasta agotarlas. Guardándolo en globalThis reutilizamos el mismo.
const globalForPrisma = globalThis as unknown as {
    prisma: PrismaClient | undefined
}

export const prisma =
    globalForPrisma.prisma ??
    new PrismaClient({
        log: env.isProduction ? ['error'] : ['query', 'warn', 'error'],
    })

if (!env.isProduction) {
    globalForPrisma.prisma = prisma
}
