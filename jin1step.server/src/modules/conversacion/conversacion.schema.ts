//Validación del body al abrir una conversación candidato <-> reclutador.
//
//Casi ningún campo del modelo puede venir del cliente:
//
//  - candidatoId /   no se aceptan por separado: el servidor sabe cuál eres tú
//    reclutadorId    por tu rol y coloca al otro en el hueco que queda.
//  - createdAt       la pone la BD con @default(now()).
//
//Los mensajes tienen su propio schema en mensaje/mensajes.schema.ts: aquí solo
//se abre el hilo, no se escribe en él.
import { z } from 'zod'

//Para abrir una conversación solo hace falta saber CON QUIÉN, porque el que
//llama ya está identificado por el token. El servidor decide si eres el
//candidato o el reclutador según tu rol; así es imposible construir una
//conversación con los dos huecos rellenados a mano.
//
//Necesitamos el id del usuario, pero también el de la oferta de empleo, para
//que el candidato pueda hablar con el reclutador sobre una oferta concreta.
export const crearConversacionSchema = z
    .object({
        //El OTRO participante. Se llama así y no candidatoId/reclutadorId
        //precisamente para que no haya forma de decir "yo soy este otro".
        usuarioId: z.uuid('usuarioId debe ser un uuid válido'),

        //Contexto opcional: sobre qué oferta se habla.
        //
        //nullable además de optional porque el modelo lo tiene como String?,
        //y el frontend necesita poder mandar null explícito para decir
        //"conversación general, no sobre una oferta concreta".
        //
        //OJO con el @@unique([candidatoId, reclutadorId, ofertaId]) del
        //modelo: en Postgres un NULL nunca es igual a otro NULL, así que ese
        //índice NO impide dos conversaciones generales entre la misma pareja.
        //Esa deduplicación hay que hacerla en el service, no aquí.
        ofertaId: z.uuid('ofertaId debe ser un uuid válido').nullish(),
    })
    .strict()

export type CrearConversacionInput = z.infer<typeof crearConversacionSchema>
