//Validación de los datos de una oferta.
//Los campos son exactamente los del modelo Oferta de Prisma. Ojo: reclutadorId
//NO está aquí a propósito, sale del token en el controller; si se aceptara del
//body, un reclutador podría publicar ofertas en nombre de otro.
import { z } from 'zod'

export const crearOfertaSchema = z.object({
    empresaId: z.uuid('empresaId debe ser un uuid válido'),
    titulo: z
        .string()
        .trim()
        .min(1, 'El título de la oferta es obligatorio')
        .max(100, 'El título no puede superar los 100 caracteres'),
    descripcion: z
        .string()
        .trim()
        .min(1, 'La descripción es obligatoria')
        .max(1000, 'La descripción no puede superar los 1000 caracteres'),
    modalidad: z.enum(['REMOTO', 'HIBRIDO', 'PRESENCIAL']),
}).strict()

//fechaPublicacion no se acepta del cliente: la pone la base de datos con
//@default(now()), así nadie puede publicar una oferta con fecha falsa para
//aparecer el primero en el listado.

//Al editar, todos los campos son opcionales: se manda solo lo que cambia.
//empresaId y reclutadorId no están: una oferta no cambia de dueño ni de empresa.
//Aquí sí se acepta estado, que es como un reclutador cierra una oferta.
export const actualizarOfertaSchema = crearOfertaSchema
    .omit({ empresaId: true })
    .extend({
        estado: z.enum(['ABIERTA', 'CERRADA']),
    })
    .partial() //partial es para que todos los campos sean opcionales, ya que al actualizar una oferta, no es necesario enviar todos los campos, solo los que se desean modificar.
    //.strict() ANTES de .refine(): refine devuelve un ZodEffects que ya no
    //expone .strict(), asi que invertir el orden no compila.
    .strict()
    .refine((datos) => Object.keys(datos).length > 0, {
        message: 'No has enviado ningún campo que actualizar',
    })

export type CrearOfertaInput = z.infer<typeof crearOfertaSchema>
export type ActualizarOfertaInput = z.infer<typeof actualizarOfertaSchema>
