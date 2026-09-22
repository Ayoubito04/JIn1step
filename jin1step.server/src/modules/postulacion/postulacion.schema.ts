import { z } from 'zod'

//Lo único que manda el candidato al postularse: con qué CV y a qué oferta.
//empresaId no hace falta: se deduce de la oferta, y aceptarlo del cliente
//permitiría mandar una empresa que no es la de esa oferta.
//El resto del modelo Postulacion lo decide el servidor:
//  - matchScore       lo calcula el servidor comparando CV y requisitos.
//                     Si viniera del cliente, cualquiera se pondría un 100.
//  - postuladoPorIa   lo sabe el servidor según qué endpoint se use.
//  - estado           empieza en PENDIENTE (@default en Prisma); si lo mandara
//                     el candidato, se pondría él mismo ENTREVISTA.
//  - fechaPostulacion la pone la base de datos con @default(now()).
export const CrearPostulacionesSchema = z.object({
    ofertaId: z.uuid('ofertaId debe ser un uuid válido'),
    cvId: z.uuid('cvId debe ser un uuid válido'),
}).strict()

//Los estados que puede poner el RECLUTADOR al revisar una postulación.
//
//PENDIENTE y ENVIADA quedan fuera a propósito: son estados del flujo de envío,
//no decisiones de nadie que revise. PENDIENTE es el @default de Prisma y
//ENVIADA la escribe el autopiloto en el propio createMany
//(postulaciones_autopilot.service.ts), así que ninguno de los dos necesita
//llegar por este endpoint. Aceptarlos permitía devolver una postulación ya
//revisada a PENDIENTE y perder para siempre el rastro de que se revisó.
//
//VISTA sí entra: está en el enum EstadoPostulacion de Prisma, es la primera
//acción real del reclutador y hasta ahora era un valor inalcanzable, porque no
//se asignaba en ningún punto del código.
export const actualizarPostulacionesSchema = z.object({
    estado: z.enum(['VISTA', 'RECHAZADA', 'ENTREVISTA']),
}).strict()

//Para consultar el match ANTES de postularse: el candidato ve qué le falta
//sin dejar rastro en la base de datos. La puntuación NO la da la IA, sale de
//comparar CvHabilidad con OfertaRequisito (ver matching.service.ts).
export const MatchingPostulacionesSchema = z.object({
    ofertaId: z.uuid('ofertaId debe ser un uuid válido'),
    cvId: z.uuid('cvId debe ser un uuid válido'),
}).strict()
export type CrearPostulacionesInput = z.infer<typeof CrearPostulacionesSchema>
export type ActualizarPostulacionesInput = z.infer<typeof actualizarPostulacionesSchema>
export type MatchingPostulacionesInput = z.infer<typeof MatchingPostulacionesSchema>
