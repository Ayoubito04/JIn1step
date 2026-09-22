//Validación de los datos que acompañan a la subida de un CV.
//El archivo en sí no se valida aquí: de eso se encarga multer en cv.routes.ts,
//porque zod trabaja sobre el body en JSON y el archivo llega como multipart.
import { z } from 'zod'

export const subirCvSchema = z.object({
    titulo: z
        .string()
        .trim()
        .min(1, 'El título es obligatorio (ej. "Desarrollador React")')
        .max(100, 'El título no puede superar los 100 caracteres'),
}).strict()

export type SubirCvInput = z.infer<typeof subirCvSchema>
