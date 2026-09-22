//Lógica de los mensajes: leer un hilo, escribir en él y contar lo no leído.
//
//Abrir y listar conversaciones vive en conversacion/conversacion.service.ts.
//De ahí viene también conversacionDelUsuario, el guard que decide si puedes
//tocar un hilo: se importa en vez de duplicarlo para que la regla de acceso
//exista en UN solo sitio. Si estuviera copiada, el día que se arregle un fallo
//en una de las dos copias la otra seguiría abierta.
import { prisma } from '../../lib/prisma'
import { conversacionDelUsuario } from '../conversacion/conversacion.service'
import type { EnviarMensajeInput } from './mensajes.schema'

//Lo que se devuelve de un mensaje. emisorId sí va: el frontend lo necesita
//para saber de qué lado pintar la burbuja.
const CamposMensaje = {
    id: true,
    conversacionId: true,
    emisorId: true,
    contenido: true,
    leido: true,
    createdAt: true,
} as const

//Los mensajes de una conversación, del más antiguo al más nuevo, que es el
//orden en el que se lee un chat.
//
//Abrir la conversación marca como leídos los mensajes del OTRO. Nunca los
//propios: "leído" significa "el destinatario lo vio", y el emisor no es el
//destinatario de su propio mensaje.
export const listarMensajes = async (usuarioId: string, conversacionId: string) => {
    await conversacionDelUsuario(conversacionId, usuarioId)

    await prisma.mensaje.updateMany({
        where: { conversacionId, emisorId: { not: usuarioId }, leido: false },
        data: { leido: true },
    })

    //Después del updateMany, para que la respuesta ya refleje el visto y el
    //frontend no tenga que recargar.
    return prisma.mensaje.findMany({
        where: { conversacionId },
        select: CamposMensaje,
        orderBy: { createdAt: 'asc' },
    })
}

//Envía un mensaje. El emisor es SIEMPRE quien llama: no hay forma de escribir
//en nombre de otro, ni siquiera siendo participante de la conversación.
export const enviarMensaje = async (
    usuarioId: string,
    conversacionId: string,
    datos: EnviarMensajeInput,
) => {
    await conversacionDelUsuario(conversacionId, usuarioId)

    return prisma.mensaje.create({
        data: {
            conversacionId,
            emisorId: usuarioId,
            contenido: datos.contenido,
            //leido se queda en el @default(false) del modelo: acaba de
            //enviarse, nadie lo ha visto todavía.
        },
        select: CamposMensaje,
    })
}

//Total de mensajes sin leer en todas sus conversaciones, para el badge de la
//campanita. Consulta barata: un count con índice, sin traer filas.
export const contarNoLeidos = async (usuarioId: string) => {
    return prisma.mensaje.count({
        where: {
            leido: false,
            emisorId: { not: usuarioId },
            conversacion: {
                OR: [{ candidatoId: usuarioId }, { reclutadorId: usuarioId }],
            },
        },
    })
}
