//Cálculo del matchScore entre un CV y una oferta.
//
//Es una fórmula, no una IA, por tres razones:
//  - Coste: comparar dos conjuntos es SQL. Con 1.000 CVs y 500 ofertas hay
//    500.000 combinaciones; a una llamada de LLM cada una, un recálculo
//    completo costaría cientos de euros.
//  - Explicabilidad: se le puede decir al candidato "te falta Docker, que era
//    obligatorio". Un LLM devuelve un 73 y no sabe por qué.
//  - Reproducibilidad: el mismo CV y la misma oferta dan siempre lo mismo.
import { prisma } from '../../lib/prisma'

//Lo obligatorio pesa más que lo deseable, pero no lo es todo: un candidato al
//que le falta un requisito obligatorio y cumple el resto sigue siendo mejor
//que uno que no cumple nada.
const PESO_OBLIGATORIAS = 0.7 //Primeramanrete vamos a ver requisitos obligatorios
const PESO_OPCIONALES = 0.3//Después requisitos que sean opcionales

export type ResultadoMatch = {
    //0-100. Se guarda en Postulacion.matchScore
    puntuacion: number
    obligatoriasCubiertas: string[]//Las obligatorias las guardamos en una array
    obligatoriasFaltantes: string[]//Las faltantes también
    opcionalesCubiertas: string[]
    opcionalesFaltantes: string[]
}

export async function calcularMatch(
    cvId: string,//Como primer parametro metemos el CV
    ofertaId: string,//Después lo comparamos con la oferta
): Promise<ResultadoMatch> {
    const [habilidadesCv, requisitos] = await Promise.all([
        prisma.cvHabilidad.findMany({
            where: { cvId },//Buscamos el CV que le hemos ofrecido a la "IA"
            select: { habilidadId: true },//Después seleccionamos habilidades
        }),
        prisma.ofertaRequisito.findMany({
            where: { ofertaId },//Ahora seleccionamos la oferta
            select: {
                habilidadId: true,//seleccionamos las habilidades opcionales y obligatorias
                obligatorio: true,
                habilidad: { select: { nombre: true } },
            },
        }),
    ])

    const tieneCandidato = new Set(habilidadesCv.map((h) => h.habilidadId))
    //Mapeamos el pdf para encontrar que habilidades soj compatibles con la oferta
    const obligatorias = requisitos.filter((r) => r.obligatorio)//filtramos requisitos obligatorios
    const opcionales = requisitos.filter((r) => !r.obligatorio)//fuiltramos los requisitos que no sean obligatorios

    const cubre = (r: (typeof requisitos)[number]) => tieneCandidato.has(r.habilidadId)//Nombramos todas las habilidades
    const nombre = (r: (typeof requisitos)[number]) => r.habilidad.nombre //Extraemos los nombres de las habilidades

    const obligatoriasCubiertas = obligatorias.filter(cubre).map(nombre) //Ahora tocará hacer un matching de habilidades
    const obligatoriasFaltantes = obligatorias.filter((r) => !cubre(r)).map(nombre)
    const opcionalesCubiertas = opcionales.filter(cubre).map(nombre)
    const opcionalesFaltantes = opcionales.filter((r) => !cubre(r)).map(nombre)

    const detalle = {
        obligatoriasCubiertas,
        obligatoriasFaltantes,
        opcionalesCubiertas,
        opcionalesFaltantes,
    }

    //Una oferta sin requisitos no exige nada, así que todo el mundo los cumple
    //todos. Se devuelve 100 en vez de 0 para no penalizar a los candidatos por
    //un descuido del reclutador (y para que se note que faltan requisitos).
    if (requisitos.length === 0) {
        return { puntuacion: 100, ...detalle }
    }

    const ratioObligatorias = obligatorias.length
        ? obligatoriasCubiertas.length / obligatorias.length
        : null
    const ratioOpcionales = opcionales.length
        ? opcionalesCubiertas.length / opcionales.length
        : null

    //Si la oferta solo tiene requisitos de un tipo, ese tipo se lleva el 100%
    //del peso. Repartir 0.7/0.3 cuando no hay opcionales daría un máximo de 70.
    let puntuacion: number

    if (ratioObligatorias !== null && ratioOpcionales !== null) {
        puntuacion =
            ratioObligatorias * PESO_OBLIGATORIAS + ratioOpcionales * PESO_OPCIONALES
    } else {
        puntuacion = (ratioObligatorias ?? ratioOpcionales)!
    }

    return {
        puntuacion: Math.round(puntuacion * 100 * 100) / 100,
        ...detalle,
    }
}
