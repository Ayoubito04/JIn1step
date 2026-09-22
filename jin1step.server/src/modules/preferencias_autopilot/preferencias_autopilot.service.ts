//Lógica de la configuración del autopiloto.
//Este service NO postula a nada: solo guarda lo que el usuario quiere que haga
//la IA. Quien actúa es autopilot.service.ts, que lee esta tabla.
import { prisma } from '../../lib/prisma'
import { HttpError } from '../../lib/http-error'
import type { ActualizarPreferenciasInput } from './preferencias_autopilot.schema'

//Mismos valores que los @default del modelo en schema.prisma.
//Se devuelven cuando el usuario todavía no tiene fila, para que el frontend
//siempre tenga algo que pintar sin necesidad de crear la fila antes de tiempo.
const PREFERENCIAS_POR_DEFECTO = {
    activo: false,
    cvId: null,
    scoreMinimo: 70,
    maxPorDia: 200,
    activadoEn: null,
    revocadoEn: null,
}
//Estas preferencias las puede modificar el usuario cunado quierea,de todas formas  no son datos rigidos que pueda modificar el usuario
//Estas son las preferencias por defecto que devulven cuando el usuario todavia no tiene preferencias 
//Ahora vamos a obtener las preferencias del usuario
export const obtenerPreferencias = async (usuarioId: string) => {
    const preferencias = await prisma.preferenciasAutopilot.findUnique({
        where: { usuarioId },
    })
    return preferencias ?? { usuarioId, ...PREFERENCIAS_POR_DEFECTO }
}

//upsert: si no hay fila la crea, si existe la actualiza. Así el usuario no
//tiene que pasar por un endpoint de "crear" antes de poder modificar.
//Si se activa el autopiloto, hay que dejar constancia con activadoEn; si se
//desactiva, revocadoEn. Es el registro de consentimiento del que habla el
//schema.
export const actualizarPreferencias = async (
    usuarioId: string,
    datos: ActualizarPreferenciasInput,
) => {
    //Si viene un cvId, hay que verificar que ese CV es del propio usuario:
    //el zod solo comprueba que sea un uuid, no la propiedad.
    if (datos.cvId) {
        const cv = await prisma.cv.findFirst({
            where: { id: datos.cvId, usuarioId },
            select: { id: true },
        })

        if (!cv) {
            throw new HttpError(404, 'CV no encontrado')
        }
    }

    const ahora = new Date()
    const marcasConsentimiento =
        datos.activo === true
            ? { activadoEn: ahora, revocadoEn: null }
            : datos.activo === false
                ? { revocadoEn: ahora }
                : {}

    return prisma.preferenciasAutopilot.upsert({
        where: { usuarioId },
        create: {
            usuarioId,
            ...datos,
            ...marcasConsentimiento,
        },
        update: {
            ...datos,
            ...marcasConsentimiento,
        },
    })
}
//Comprobamos que el usuario ha subido su CV
export const comprobarUsuarioConCv = async (usuarioId: string) => {
    //El modelo Cv no tiene campo `estado`: no hay CVs "verificados" ni
    //"pendientes", subir uno es el único estado que existe. Basta con comprobar
    //que el usuario tenga al menos uno.
    const cv = await prisma.cv.findFirst({
        where: { usuarioId },
    })
    return cv !== null

}
//La lógica de "buscar ofertas y postularse" vive en postulaciones_autopilot/
//(service.ts). Este módulo se queda SOLO con la configuración, tal como decía
//el comentario del principio.