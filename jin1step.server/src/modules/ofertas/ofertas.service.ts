//Servicios de ofertas: la lógica de negocio. La validación del body la hace
//validateBody; aquí se comprueban las reglas que dependen de la base de datos.
import { prisma } from '../../lib/prisma'
import { HttpError } from '../../lib/http-error'
import type { ActualizarOfertaInput, CrearOfertaInput } from './ofertas.schema'

//Qué se enseña del reclutador dentro de cada oferta.
//Es un select explícito y NO un `include: { reclutador: true }`: eso devolvería
//la fila entera de Usuario —passwordHash y googleId incluidos— a cualquiera que
//mire el listado de ofertas.
//El email tampoco va: para hablar con el reclutador está el chat, y publicarlo
//aquí sería regalar una lista de correos a cualquier scraper.
const RECLUTADOR_PUBLICO = {
    select: {
        id: true,
        nombre: true,
        apellidos: true,
    },
} as const

const EMPRESA_PUBLICA = {
    select: {
        id: true,
        nombre: true,
        sector: true,
        ubicacion: true,
    },
} as const

//Se repite en todas las consultas para que la forma de la respuesta sea
//siempre la misma, la pida quien la pida.
const CON_RECLUTADOR_Y_EMPRESA = {
    reclutador: RECLUTADOR_PUBLICO,
    empresa: EMPRESA_PUBLICA,
} as const

export async function crearOferta(reclutadorId: string, datos: CrearOfertaInput) {
    //Se comprueba antes de crear: si la empresa no existe, Prisma lanzaría un
    //error de clave foránea que acabaría saliendo como un 500 poco útil.
    const empresa = await prisma.empresa.findUnique({
        where: { id: datos.empresaId },
        select: { id: true },
    })

    if (!empresa) {
        throw new HttpError(404, 'La empresa indicada no existe')
    }

    return prisma.oferta.create({
        data: {
            empresaId: datos.empresaId,
            //El id sale del token, nunca del body
            reclutadorId,
            titulo: datos.titulo,
            descripcion: datos.descripcion,
            modalidad: datos.modalidad,
            //estado y fechaPublicacion los pone la BD con sus @default
        },
        include: CON_RECLUTADOR_Y_EMPRESA,
    })
}

//Listado público: solo ofertas abiertas, cada una con su reclutador y empresa.
export async function listarOfertas() {
    return prisma.oferta.findMany({
        where: { estado: 'ABIERTA' },
        orderBy: { fechaPublicacion: 'desc' },
        include: CON_RECLUTADOR_Y_EMPRESA,
    })
}

//Las ofertas de un reclutador, incluidas las cerradas: son suyas y las ve todas.
export async function listarReclutadoresOfertas(reclutadorId: string) {
    return prisma.oferta.findMany({
        where: { reclutadorId },
        orderBy: { fechaPublicacion: 'desc' },
        include: CON_RECLUTADOR_Y_EMPRESA,
    })
}

export async function obtenerOfertaPorId(ofertaId: string) {
    const oferta = await prisma.oferta.findUnique({
        where: { id: ofertaId },
        include: CON_RECLUTADOR_Y_EMPRESA,
    })

    if (!oferta) {
        throw new HttpError(404, 'Oferta no encontrada')
    }

    return oferta
}

export async function actualizarReclutadorOferta(
    reclutadorId: string,
    ofertaId: string,
    datos: ActualizarOfertaInput,
) {
    //Comprobar la propiedad ANTES de actualizar es lo único que impide que un
    //reclutador edite la oferta de otro. Un update con `where: { id }` a secas
    //dejaría que cualquiera modificase cualquier oferta.
    const oferta = await prisma.oferta.findUnique({
        where: { id: ofertaId },
        select: { id: true, reclutadorId: true },
    })

    if (!oferta || oferta.reclutadorId !== reclutadorId) {
        //Mismo 404 si no existe que si es de otro: un 403 confirmaría que esa
        //oferta existe y es de alguien.
        throw new HttpError(404, 'Oferta no encontrada')
    }

    //Solo se tocan los campos que vengan. reclutadorId y empresaId no se
    //actualizan nunca, para que una oferta no pueda cambiar de dueño.
    return prisma.oferta.update({
        where: { id: ofertaId },
        data: datos,
        include: CON_RECLUTADOR_Y_EMPRESA,
    })
}
