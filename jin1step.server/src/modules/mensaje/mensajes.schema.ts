//Validación de lo que llega por el body al escribir en el chat.
//
//Abrir una conversación tiene su propio schema en
//conversacion/conversacion.schema.ts: aquí solo se escribe dentro de un hilo
//que ya existe.
//
//Casi ningún campo del modelo Mensaje puede venir del cliente:
//
//  - emisorId        sale del token. Si viniera del body, cualquiera podría
//                    escribir mensajes firmados con el nombre de otro. Es el
//                    fallo más grave posible en un chat.
//  - conversacionId  va en la URL, no en el body: el recurso es
//                    /conversaciones/:conversacionId/mensajes.
//  - leido           lo marca el SERVIDOR cuando el destinatario abre la
//                    conversación. Si lo mandara el cliente, el emisor podría
//                    marcar sus propios mensajes como leídos y falsear el
//                    "visto", o dejarlos siempre en no leído para reventar el
//                    contador del otro.
//  - createdAt       la pone la BD con @default(now()). Aceptarlo permitiría
//                    colar mensajes con fecha falsa y desordenar el hilo.
import { z } from 'zod'

//Un mensaje es solo su texto: todo lo demás lo sabe el servidor.
export const enviarMensajeSchema = z
    .object({
        //trim antes del min: así un mensaje de solo espacios se rechaza en vez
        //de guardarse como una burbuja vacía en el chat.
        //
        //El tope de 2000 no es por la base de datos (la columna es text, sin
        //límite), es para que nadie use el chat como almacenamiento: sin tope,
        //un solo POST puede meter megabytes y reventar la pantalla del otro.
        contenido: z
            .string()
            .trim()
            .min(1, 'El mensaje no puede estar vacío')
            .max(2000, 'El mensaje no puede superar los 2000 caracteres'),
    })
    .strict()

export type EnviarMensajeInput = z.infer<typeof enviarMensajeSchema>
