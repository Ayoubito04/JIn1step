//Validación del perfil del candidato: los datos que NO caben en el CV pero
//hacen falta para filtrar candidaturas (dónde está y cuándo puede empezar).
//
//usuarioId no aparece a propósito: es el @id del modelo y sale del token.
//Aceptarlo del body permitiría editar el perfil de otro.
import { z } from 'zod'

//Un solo schema para crear y actualizar porque el endpoint es un upsert: el
//perfil no se "crea" en un paso aparte, nace la primera vez que lo guardas.
//
//.nullish() en los dos campos para poder vaciarlos mandando null, sin tener
//que omitir la clave. Mismo criterio que en empresa.
export const actualizarPerfilSchema = z
    .object({
        ubicacion: z
            .string()
            .trim()
            .min(1, 'La ubicación no puede estar vacía')
            .max(150, 'La ubicación no puede superar los 150 caracteres')
            .nullish(),

        //Texto libre y no enum a propósito: "inmediata", "15 días", "a partir
        //de junio" y "solo tardes" son respuestas legítimas y muy distintas.
        //Encerrarlo en un enum obligaría a migrar cada vez que aparezca un
        //caso nuevo, y el campo solo se enseña al reclutador, no se filtra.
        disponibilidad: z
            .string()
            .trim()
            .min(1, 'La disponibilidad no puede estar vacía')
            .max(200, 'La disponibilidad no puede superar los 200 caracteres')
            .nullish(),
    })
    .strict()
    //Sin esto, un PATCH con {} pasaría la validación y haría un upsert que no
    //cambia nada, devolviendo 200 como si hubiera guardado algo.
    .refine((datos) => Object.keys(datos).length > 0, {
        message: 'No has enviado ningún campo que actualizar',
    })

export type ActualizarPerfilInput = z.infer<typeof actualizarPerfilSchema>
