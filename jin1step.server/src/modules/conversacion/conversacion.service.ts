//Lógica de las conversaciones del chat: abrirlas y listarlas.
//
//Escribir y leer mensajes vive en mensaje/mensajes.service.ts. La frontera es
//deliberada y la dependencia va en UN solo sentido: mensaje importa de aquí
//(necesita el guard de acceso), y aquí no se importa nada de mensaje. Si algún
//día hiciera falta al revés, sería señal de que los dos módulos son uno.
import type { Rol } from '@prisma/client'
import { prisma } from '../../lib/prisma'
import { HttpError } from '../../lib/http-error'
import type { CrearConversacionInput } from './conversacion.schema'

//Se incluyen los dos participantes porque el service resuelve después quién es
//el interlocutor; el frontend no debería tener que comparar ids.
const CamposConversacion = {
    id: true,
    ofertaId: true,
    createdAt: true,
    candidato: { select: { id: true, nombre: true, apellidos: true } },
    reclutador: { select: { id: true, nombre: true, apellidos: true } },
    oferta: { select: { id: true, titulo: true } },
} as const

//Select mínimo para la vista previa del último mensaje en la bandeja.
//Se define aquí y no se importa de mensaje/ para no crear un ciclo entre los
//dos módulos: es un puñado de campos, y duplicarlos sale más barato que
//enredar las dependencias.
const CamposUltimoMensaje = {
    id: true,
    emisorId: true,
    contenido: true,
    leido: true,
    createdAt: true,
} as const

//EL guard del chat. Devuelve la conversación solo si el usuario es uno de los
//dos participantes, y lo usan tanto este módulo como el de mensajes.
//
//404 y no 403 a propósito: un 403 confirmaría que esa conversación existe, y
//eso ya es filtrar información a quien no debería tenerla.
//
//Es la única defensa que hay: en la base de datos no hay nada que impida leer
//la fila de otro, porque con el uuid basta para un findUnique.
export async function conversacionDelUsuario(conversacionId: string, usuarioId: string) {
    const conversacion = await prisma.conversacion.findFirst({
        where: {
            id: conversacionId,
            OR: [{ candidatoId: usuarioId }, { reclutadorId: usuarioId }],
        },
        select: { id: true, candidatoId: true, reclutadorId: true },
    })

    if (!conversacion) {
        throw new HttpError(404, 'Conversación no encontrada')
    }

    return conversacion
}

//Abre la conversación con otro usuario, o devuelve la que ya existía.
//
//Quién ocupa cada hueco lo decide el ROL de quien llama, no el body: si eres
//CANDIDATO tú eres candidatoId y el otro reclutadorId, y al revés. Así no hay
//forma de fabricar una conversación en la que tú figuras como otra persona.
export const abrirConversacion = async (
    usuarioId: string,
    rol: Rol,
    datos: CrearConversacionInput,
) => {
    if (usuarioId === datos.usuarioId) {
        throw new HttpError(400, 'No puedes abrir una conversación contigo mismo')
    }

    //El otro tiene que existir Y tener el rol contrario. Sin esta comprobación
    //un candidato podría abrir una conversación con otro candidato, que
    //quedaría guardada con un candidato metido en el hueco de reclutador: la
    //fila sería mentira y las consultas por rol dejarían de cuadrar.
    const rolContrario: Rol = rol === 'CANDIDATO' ? 'RECLUTADOR' : 'CANDIDATO'

    const otro = await prisma.usuario.findFirst({
        where: { id: datos.usuarioId, rol: rolContrario },
        select: { id: true },
    })

    if (!otro) {
        throw new HttpError(404, `No existe ningún ${rolContrario.toLowerCase()} con ese id`)
    }

    const candidatoId = rol === 'CANDIDATO' ? usuarioId : otro.id
    const reclutadorId = rol === 'CANDIDATO' ? otro.id : usuarioId
    const ofertaId = datos.ofertaId ?? null

    //Si se habla sobre una oferta, esa oferta tiene que existir. Con
    //onDelete: SetNull en el modelo, un id inventado daría un error de FK
    //(500) en vez de un 404 claro.
    if (ofertaId) {
        const oferta = await prisma.oferta.findUnique({
            where: { id: ofertaId },
            select: { id: true },
        })

        if (!oferta) {
            throw new HttpError(404, 'La oferta no existe')
        }
    }

    //find-or-create a mano, y no un upsert, por el NULL del índice único.
    //
    //El modelo tiene @@unique([candidatoId, reclutadorId, ofertaId]), pero en
    //Postgres NULL != NULL: ese índice NO impide dos conversaciones generales
    //entre la misma pareja. Para ofertaId nulo la deduplicación tiene que
    //salir de esta consulta, no de la base de datos.
    const existente = await prisma.conversacion.findFirst({
        where: { candidatoId, reclutadorId, ofertaId },
        select: CamposConversacion,
    })

    if (existente) {
        return { creada: false, conversacion: existente }
    }

    //Se devuelve "creada" en vez de dejar que el controller lo adivine
    //comparando createdAt con la hora actual: eso sería una carrera contra el
    //reloj, y con dos peticiones seguidas daría el código equivocado.
    return {
        creada: true,
        conversacion: await prisma.conversacion.create({
            data: { candidatoId, reclutadorId, ofertaId },
            select: CamposConversacion,
        }),
    }
}

//Las conversaciones en las que participa el usuario, con el último mensaje y
//cuántos le quedan por leer. Es lo que necesita la bandeja de entrada para
//pintarse de una sola petición, sin pedir los mensajes de cada hilo.
export const listarMisConversaciones = async (usuarioId: string) => {
    const conversaciones = await prisma.conversacion.findMany({
        where: {
            OR: [{ candidatoId: usuarioId }, { reclutadorId: usuarioId }],
        },
        select: {
            ...CamposConversacion,
            //take: 1 con orderBy desc = el último mensaje, para la vista previa.
            mensajes: {
                select: CamposUltimoMensaje,
                orderBy: { createdAt: 'desc' },
                take: 1,
            },
            //No leídos: solo cuentan los del OTRO. Los tuyos propios nunca
            //están "sin leer" para ti.
            _count: {
                select: {
                    mensajes: { where: { leido: false, emisorId: { not: usuarioId } } },
                },
            },
        },
    })

    return conversaciones
        .map(({ mensajes, _count, ...conversacion }) => ({
            ...conversacion,
            //El interlocutor, ya resuelto: el frontend no debería tener que
            //comparar ids para saber con quién habla.
            interlocutor:
                conversacion.candidato.id === usuarioId
                    ? conversacion.reclutador
                    : conversacion.candidato,
            ultimoMensaje: mensajes[0] ?? null,
            sinLeer: _count.mensajes,
        }))
        //Por actividad real, no por fecha de creación: un hilo viejo con un
        //mensaje de hace un minuto tiene que salir el primero.
        .sort((a, b) => {
            const fechaA = a.ultimoMensaje?.createdAt ?? a.createdAt
            const fechaB = b.ultimoMensaje?.createdAt ?? b.createdAt
            return fechaB.getTime() - fechaA.getTime()
        })
}
