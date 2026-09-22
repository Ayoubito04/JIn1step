//Validación de la configuración del autopiloto.
//Aquí solo va lo que manda el usuario por el body: el matchScore no aparece
//porque lo calcula el servidor (ver matching.service.ts), no el cliente.
import { z } from 'zod'

export const actualizarPreferenciasSchema = z
    .object({
        activo: z.boolean(),

        //null permite desasignar el CV sin desactivar el autopiloto.
        //OJO: zod solo comprueba que sea un uuid. Que ese CV sea SUYO hay que
        //verificarlo en el service contra la BD, o cualquiera podría poner el
        //id del CV de otro y postular con él.
        cvId: z.uuid('cvId debe ser un uuid válido').nullable(),
        //Definimos el CV,que nos servirá para que la IA preseleccione la oferta perfecta para nosotros
        //0-100, la misma escala que devuelve calcularMatch.
        //Si esto fuera 0-1, el usuario pondría 0,7 y la comparación
        //"61.67 >= 0.7" sería siempre cierta: postularía a todo.
        scoreMinimo: z
            .number()
            .min(0, 'El score mínimo no puede ser negativo')
            .max(100, 'El score mínimo no puede pasar de 100'),
       //El Scrore es un parametro importante para poder encontrar la oferta ideal
        //El tope de 20 es nuestro, no del usuario: las candidaturas salen con
        //el nombre de la plataforma detrás, y un reclutador que ve al mismo
        //candidato en todas sus ofertas lo marca como spam.
        maxPorDia: z
            .number()
            .int('Debe ser un número entero')
            .min(1, 'Como mínimo 1 al día')
            .max(20, 'Como máximo 20 al día'),
            //Definimos la cantidad de ofertas que nos buscará al día
    })
    //El usuario tiene que poder cambiar solo maxPorDia sin reenviar el resto
    .partial()
    //.strict() ANTES de .refine(): refine devuelve un ZodEffects que ya no
    //expone .strict(), asi que invertir el orden no compila.
    .strict()
    .refine((datos) => Object.keys(datos).length > 0, {
        message: 'No has enviado ningún campo que actualizar',
    })

export type ActualizarPreferenciasInput = z.infer<typeof actualizarPreferenciasSchema>
