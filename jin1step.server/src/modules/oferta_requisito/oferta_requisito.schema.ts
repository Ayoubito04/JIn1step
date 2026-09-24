//Validación de los requisitos de una oferta: qué habilidades pide y cuáles
//son imprescindibles.
//
//ofertaId no aparece en el body: viene de la ruta (/ofertas/:ofertaId/
//requisitos). Aceptarlo del body permitiría añadir requisitos a la oferta de
//otro reclutador aunque la URL apuntase a la tuya.
import { z } from 'zod'

//Solo habilidadId, nunca un nombre libre: el catálogo Habilidad es compartido
//y se usa para el matching. Si aquí se aceptara texto, un reclutador crearía
//"Reactt" y ningún CV casaría nunca con esa oferta.
export const anadirRequisitoSchema = z
    .object({
        habilidadId: z.uuid('habilidadId debe ser un uuid válido'),

        //Por defecto true: si el reclutador se molesta en añadir un requisito,
        //lo normal es que lo considere necesario. El peso real lo aplica
        //calcularMatch (0.7 obligatorias / 0.3 opcionales).
        obligatorio: z.boolean().default(true),
    })
    .strict()

//Solo se puede cambiar el peso de un requisito ya añadido. Cambiar la
//habilidad sería otro requisito distinto: para eso se borra y se añade.
export const actualizarRequisitoSchema = z
    .object({
        obligatorio: z.boolean(),
    })
    .strict()

//Alta en bloque, para el formulario de publicar oferta: el reclutador marca
//varias habilidades de una vez y no tiene sentido una petición por cada una.
//
//El tope de 30 es nuestro: una oferta con más requisitos que eso no la cumple
//nadie, y sin límite esto es una vía fácil para inflar la tabla.
export const reemplazarRequisitosSchema = z
    .object({
        requisitos: z
            .array(anadirRequisitoSchema)
            .max(30, 'Una oferta no puede tener más de 30 requisitos')
            //Sin esto, mandar [] borraría todos los requisitos en silencio a
            //través de un endpoint que dice "reemplazar". Para vaciar están
            //los DELETE uno a uno, que son explícitos.
            .min(1, 'Envía al menos un requisito'),
    })
    .strict()
    //Dos entradas con la misma habilidadId reventarían contra el @@id
    //compuesto a mitad de transacción. Mejor rechazarlo antes de tocar la BD.
    .refine(
        (datos) =>
            new Set(datos.requisitos.map((r) => r.habilidadId)).size ===
            datos.requisitos.length,
        { message: 'Hay habilidades repetidas en la lista' },
    )

export type AnadirRequisitoInput = z.infer<typeof anadirRequisitoSchema>
export type ActualizarRequisitoInput = z.infer<typeof actualizarRequisitoSchema>
export type ReemplazarRequisitosInput = z.infer<typeof reemplazarRequisitosSchema>
