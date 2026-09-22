import { defineConfig } from 'vitest/config'

export default defineConfig({
    test: {
        include: ['src/**/*.test.ts'],

        // Los tests del service son de INTEGRACIÓN: hablan con la base de
        // datos de verdad, no con un mock. Si vitest corriera los ficheros en
        // paralelo, dos suites creando y borrando filas a la vez se pisarían
        // (sobre todo con el índice único parcial de "una sola ACTIVA").
        fileParallelism: false,

        // Levantar el cliente de Prisma y hablar con Postgres es más lento que
        // un test unitario en memoria; 5s por test se queda corto en el
        // primer arranque.
        testTimeout: 20000,
    },
})
