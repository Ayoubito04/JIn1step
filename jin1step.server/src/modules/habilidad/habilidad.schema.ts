//Validación de las operaciones sobre CvHabilidad.
//El catálogo de Habilidad no se toca desde aquí (lo pinta el seed y se
//consulta en lectura): un usuario cualquiera no debe poder meter "TypeScrit"
//con typo en la tabla compartida.
import { z } from 'zod'

//Los mismos tres valores del enum NivelHabilidad de Prisma, que antes era un
//String libre con un comentario "de ejemplo" en minúsculas y con tilde: la
//comparación en filtros dependía de que todo el mundo pasara por este endpoint.
//Ahora la restricción está también en la base de datos, así que este enum y la
//columna no pueden divergir en silencio.
//
//Se escriben a mano, como en el resto de schemas, porque esto es el contrato
//HTTP: si alguien añade un nivel en Prisma, la API no debe empezar a aceptarlo
//sola. La referencia por número de línea que había aquí se quita a propósito;
//apuntaba a la 131 cuando la columna estaba en la 141.
const nivelSchema = z.enum(['BASICO', 'INTERMEDIO', 'AVANZADO'])

export const asignarHabilidadSchema = z.object({
    habilidadId: z.uuid('habilidadId debe ser un uuid válido'),
    nivel: nivelSchema.optional(),
}).strict()

//nivel nullable para poder desasignarlo sin borrar la habilidad entera.
export const actualizarNivelSchema = z.object({
    nivel: nivelSchema.nullable(),
}).strict()

export type AsignarHabilidadInput = z.infer<typeof asignarHabilidadSchema>
export type ActualizarNivelInput = z.infer<typeof actualizarNivelSchema>
