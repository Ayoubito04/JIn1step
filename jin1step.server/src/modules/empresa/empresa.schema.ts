//Validación del alta de una empresa. No hay schema de actualización a propósito:
//las empresas son un registro compartido y su edición se hace desde admin, no
//por API (ver comentario en empresa.service.ts).
import { z } from 'zod'

//Los enums Modalidad y EstadoOferta viven en ofertas.schema.ts. Aquí no se
//tocan ofertas: crear una empresa NO implica crear una oferta.
export const crearEmpresaSchema = z.object({
    nombre: z
        .string()
        .trim()
        .min(1, 'El nombre de la empresa es obligatorio')
        .max(150, 'El nombre no puede superar los 150 caracteres'),

    //Los tres opcionales aceptan null explícitamente para que el frontend
    //pueda desasignar un valor (mandando null) sin tener que omitir el campo.
    sector: z
        .string()
        .trim()
        .min(1, 'El sector no puede estar vacío')
        .max(100, 'El sector no puede superar los 100 caracteres')
        .nullish(),

    ubicacion: z
        .string()
        .trim()
        .min(1, 'La ubicación no puede estar vacía')
        .max(150, 'La ubicación no puede superar los 150 caracteres')
        .nullish(),

    //z.url() y no z.string().url(): estilo Zod v4, coherente con auth.schema.ts.
    sitioWeb: z
        .url('El sitio web debe ser una URL válida')
        .max(300, 'El sitio web no puede superar los 300 caracteres')
        .nullish(),
  
    
})

export type CrearEmpresaInput = z.infer<typeof crearEmpresaSchema>
