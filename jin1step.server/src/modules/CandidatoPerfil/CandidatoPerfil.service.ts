//Lógica del perfil del candidato: ubicación y disponibilidad.
//
//Son datos que el CV no cubre bien. El CV es un PDF y su texto se usa para
//detectar habilidades, no para saber si alguien se puede mudar a Bilbao.
import { prisma } from '../../lib/prisma'
import { HttpError } from '../../lib/http-error'
import type { ActualizarPerfilInput } from './CandidatoPerfil.schema'

//Valores que se devuelven cuando el candidato todavía no ha rellenado nada.
//Así el frontend siempre tiene algo que pintar y no hay que crear la fila
//antes de tiempo. Mismo criterio que PREFERENCIAS_POR_DEFECTO en autopilot.
const PERFIL_VACIO = {
    ubicacion: null,
    disponibilidad: null,
}

const CAMPOS_PUBLICOS = {
    usuarioId: true,
    ubicacion: true,
    disponibilidad: true,
} as const

//El perfil propio. Nunca lanza 404: si no hay fila, devuelve los valores
//vacíos, porque "aún no lo he rellenado" no es un error.
export async function obtenerMiPerfil(usuarioId: string) {
    const perfil = await prisma.candidatoPerfil.findUnique({
        where: { usuarioId },
        select: CAMPOS_PUBLICOS,
    })

    return perfil ?? { usuarioId, ...PERFIL_VACIO }
}

//El perfil de OTRO candidato, para que el reclutador lo vea al revisar una
//candidatura. Aquí sí hace falta comprobar que el usuario existe y es
//candidato: sin eso, un reclutador podría sondear ids ajenos y distinguir
//"existe pero sin perfil" de "no existe".
export async function obtenerPerfilDeCandidato(candidatoId: string) {
    const usuario = await prisma.usuario.findFirst({
        where: { id: candidatoId, rol: 'CANDIDATO' },
        select: { id: true },
    })

    if (!usuario) {
        throw new HttpError(404, 'Candidato no encontrado')
    }

    const perfil = await prisma.candidatoPerfil.findUnique({
        where: { usuarioId: candidatoId },
        select: CAMPOS_PUBLICOS,
    })

    return perfil ?? { usuarioId: candidatoId, ...PERFIL_VACIO }
}

//upsert y no update: el perfil nace la primera vez que se guarda. Con update
//habría que crear la fila en el registro, y quedarían filas vacías de todos
//los candidatos que nunca entran aquí.
//
//No recibe usuarioId por parámetro de datos: viene del token. Es lo único
//que impide editar el perfil de otro.
export async function actualizarMiPerfil(
    usuarioId: string,
    datos: ActualizarPerfilInput,
) {
    return prisma.candidatoPerfil.upsert({
        where: { usuarioId },
        create: { usuarioId, ...datos },
        update: datos,
        select: CAMPOS_PUBLICOS,
    })
}

//Borrar el perfil, no el usuario. Deja la cuenta intacta y solo quita los
//datos opcionales: es lo que espera alguien que pulsa "borrar mis datos de
//perfil" sin querer darse de baja.
export async function borrarMiPerfil(usuarioId: string) {
    //deleteMany y no delete: delete lanza P2025 si no hay fila, y borrar algo
    //que ya no está no es un error. Así la operación es idempotente.
    await prisma.candidatoPerfil.deleteMany({ where: { usuarioId } })
}
