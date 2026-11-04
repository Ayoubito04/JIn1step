//Cálculo híbrido del matchScore entre un CV y una oferta:
//  - 50 % requisitos obligatorios
//  - 20 % requisitos deseables
//  - 30 % encaje del CV con los términos clave de la descripción y título
import { prisma } from '../../lib/prisma'

const PESO_OBLIGATORIAS = 0.5
const PESO_OPCIONALES = 0.2
const PESO_DESCRIPCION = 0.3

//Vocabulario profesional y técnico que se busca en la descripción y el título
//de la oferta para compararlo con el texto y las habilidades del CV.
const TERMINOS_CLAVE: { etiqueta: string; variantes: string[] }[] = [
    { etiqueta: 'React', variantes: ['react', 'reactjs', 'react.js'] },
    { etiqueta: 'Angular', variantes: ['angular', 'angularjs'] },
    { etiqueta: 'Vue.js', variantes: ['vue', 'vuejs', 'vue.js'] },
    { etiqueta: 'TypeScript', variantes: ['typescript', 'ts'] },
    { etiqueta: 'JavaScript', variantes: ['javascript', 'js', 'ecmascript'] },
    { etiqueta: 'Node.js', variantes: ['node.js', 'nodejs', 'node'] },
    { etiqueta: 'Next.js', variantes: ['next.js', 'nextjs'] },
    { etiqueta: 'NestJS', variantes: ['nestjs', 'nest.js'] },
    { etiqueta: 'Express', variantes: ['express', 'expressjs'] },
    { etiqueta: 'HTML', variantes: ['html', 'html5'] },
    { etiqueta: 'CSS', variantes: ['css', 'css3', 'sass', 'scss'] },
    { etiqueta: 'Tailwind', variantes: ['tailwind', 'tailwindcss'] },
    { etiqueta: 'Python', variantes: ['python', 'py'] },
    { etiqueta: 'Django', variantes: ['django'] },
    { etiqueta: 'FastAPI', variantes: ['fastapi'] },
    { etiqueta: 'Java', variantes: ['java'] },
    { etiqueta: 'Spring Boot', variantes: ['spring boot', 'spring'] },
    { etiqueta: 'C#', variantes: ['c#', 'csharp', 'c sharp'] },
    { etiqueta: '.NET', variantes: ['.net', 'dotnet', 'net core', '.net core', 'asp.net'] },
    { etiqueta: 'C++', variantes: ['c++', 'cpp'] },
    { etiqueta: 'PHP', variantes: ['php'] },
    { etiqueta: 'Laravel', variantes: ['laravel'] },
    { etiqueta: 'Go', variantes: ['golang'] },
    { etiqueta: 'Rust', variantes: ['rust'] },
    { etiqueta: 'Kotlin', variantes: ['kotlin'] },
    { etiqueta: 'Swift', variantes: ['swift'] },
    { etiqueta: 'Flutter', variantes: ['flutter'] },
    { etiqueta: 'Dart', variantes: ['dart'] },
    { etiqueta: 'SQL', variantes: ['sql'] },
    { etiqueta: 'PostgreSQL', variantes: ['postgresql', 'postgres', 'psql'] },
    { etiqueta: 'MySQL', variantes: ['mysql', 'my sql'] },
    { etiqueta: 'MongoDB', variantes: ['mongodb', 'mongo'] },
    { etiqueta: 'Redis', variantes: ['redis'] },
    { etiqueta: 'Prisma', variantes: ['prisma'] },
    { etiqueta: 'Docker', variantes: ['docker', 'contenedores'] },
    { etiqueta: 'Kubernetes', variantes: ['kubernetes', 'k8s'] },
    { etiqueta: 'AWS', variantes: ['aws', 'amazon web services'] },
    { etiqueta: 'Azure', variantes: ['azure'] },
    { etiqueta: 'Google Cloud', variantes: ['gcp', 'google cloud'] },
    { etiqueta: 'Firebase', variantes: ['firebase'] },
    { etiqueta: 'Git', variantes: ['git', 'github', 'gitlab'] },
    { etiqueta: 'CI/CD', variantes: ['ci/cd', 'cicd', 'integracion continua'] },
    { etiqueta: 'Linux', variantes: ['linux', 'ubuntu', 'bash'] },
    { etiqueta: 'REST', variantes: ['rest', 'api rest', 'restful'] },
    { etiqueta: 'GraphQL', variantes: ['graphql'] },
    { etiqueta: 'Microservicios', variantes: ['microservicios', 'microservices'] },
    { etiqueta: 'Testing', variantes: ['testing', 'pruebas unitarias', 'unit test', 'tdd'] },
    { etiqueta: 'Jest', variantes: ['jest', 'vitest'] },
    { etiqueta: 'Cypress', variantes: ['cypress', 'playwright'] },
    { etiqueta: 'Selenium', variantes: ['selenium'] },
    { etiqueta: 'Scrum', variantes: ['scrum', 'agile', 'agil', 'kanban'] },
    { etiqueta: 'Figma', variantes: ['figma'] },
    { etiqueta: 'Inglés', variantes: ['ingles', 'english', 'b2', 'c1'] },
    { etiqueta: 'Frontend', variantes: ['frontend', 'front-end', 'front end'] },
    { etiqueta: 'Backend', variantes: ['backend', 'back-end', 'back end'] },
    { etiqueta: 'Full Stack', variantes: ['full stack', 'fullstack', 'full-stack'] },
    { etiqueta: 'DevOps', variantes: ['devops'] },
    { etiqueta: 'Clean Architecture', variantes: ['clean architecture', 'arquitectura limpia', 'solid', 'ddd'] },
]

function normalizar(texto: string): string {
    return texto
        .toLowerCase()
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
}

function escaparRegex(texto: string): string {
    return texto.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

function apareceEnTexto(textoNormalizado: string, termino: string): boolean {
    const t = normalizar(termino).trim()
    if (!t) return false
    const patron = new RegExp(
        `(?<![\\p{L}\\p{N}.])${escaparRegex(t)}(?![\\p{L}\\p{N}])`,
        'u',
    )
    return patron.test(textoNormalizado)
}

export function analizarDescripcionOferta(
    textoOferta: string,
    nombresHabilidadesCv: string[],
    textoCv: string,
    nombresRequisitosOferta: string[] = [],
): {
    cubiertas: string[]
    faltantes: string[]
    porcentaje: number
} {
    const ofertaNorm = normalizar(textoOferta)
    if (!ofertaNorm.trim()) {
        return { cubiertas: [], faltantes: [], porcentaje: 0 }
    }

    const cvNorm = normalizar(`${nombresHabilidadesCv.join(' ')} ${textoCv}`)
    const candidatos = new Map<string, string[]>()

    for (const item of TERMINOS_CLAVE) {
        candidatos.set(item.etiqueta, item.variantes)
    }
    for (const nombre of nombresRequisitosOferta) {
        if (!candidatos.has(nombre)) {
            candidatos.set(nombre, [nombre])
        }
    }

    const cubiertas: string[] = []
    const faltantes: string[] = []

    for (const [etiqueta, variantes] of candidatos.entries()) {
        const todasVariantes = [etiqueta, ...variantes]
        const enOferta = todasVariantes.some((v) => apareceEnTexto(ofertaNorm, v))
        if (!enOferta) continue

        const enCv = todasVariantes.some((v) => apareceEnTexto(cvNorm, v))
        if (enCv) {
            cubiertas.push(etiqueta)
        } else {
            faltantes.push(etiqueta)
        }
    }

    const total = cubiertas.length + faltantes.length
    const porcentaje = total === 0 ? 0 : Math.round((cubiertas.length / total) * 100)
    return { cubiertas, faltantes, porcentaje }
}

export type ResultadoMatch = {
    //0-100. Se guarda en Postulacion.matchScore
    puntuacion: number
    obligatoriasCubiertas: string[]
    obligatoriasFaltantes: string[]
    opcionalesCubiertas: string[]
    opcionalesFaltantes: string[]
    descripcionCubiertas: string[]
    descripcionFaltantes: string[]
    porcentajeDescripcion: number
    sinRequisitos: boolean
}

export function calcularMatchEnMemoria(
    contenidoTextoCv: string,
    habilidadesCv: { habilidadId: string; habilidad: { nombre: string } }[],
    oferta: {
        titulo?: string | null
        descripcion?: string | null
        requisitos: {
            habilidadId: string
            obligatorio: boolean
            habilidad: { nombre: string }
        }[]
    },
): ResultadoMatch {
    const requisitos = oferta.requisitos
    const tieneCandidato = new Set(habilidadesCv.map((h) => h.habilidadId))
    const nombresHabilidadesCv = habilidadesCv.map((h) => h.habilidad.nombre)
    const obligatorias = requisitos.filter((r) => r.obligatorio)
    const opcionales = requisitos.filter((r) => !r.obligatorio)

    const cubre = (r: (typeof requisitos)[number]) => tieneCandidato.has(r.habilidadId)
    const nombre = (r: (typeof requisitos)[number]) => r.habilidad.nombre

    const obligatoriasCubiertas = obligatorias.filter(cubre).map(nombre)
    const obligatoriasFaltantes = obligatorias.filter((r) => !cubre(r)).map(nombre)
    const opcionalesCubiertas = opcionales.filter(cubre).map(nombre)
    const opcionalesFaltantes = opcionales.filter((r) => !cubre(r)).map(nombre)

    const textoOferta = (oferta.descripcion ?? '').trim()
    const analisisDesc = analizarDescripcionOferta(
        textoOferta,
        nombresHabilidadesCv,
        contenidoTextoCv,
        requisitos.map(nombre),
    )

    const detalle = {
        obligatoriasCubiertas,
        obligatoriasFaltantes,
        opcionalesCubiertas,
        opcionalesFaltantes,
        descripcionCubiertas: analisisDesc.cubiertas,
        descripcionFaltantes: analisisDesc.faltantes,
        porcentajeDescripcion: analisisDesc.porcentaje,
    }

    const totalDesc = analisisDesc.cubiertas.length + analisisDesc.faltantes.length

    if (requisitos.length === 0 && totalDesc === 0) {
        return { puntuacion: 0, sinRequisitos: true, ...detalle }
    }

    const ratioObligatorias = obligatorias.length
        ? obligatoriasCubiertas.length / obligatorias.length
        : null
    const ratioOpcionales = opcionales.length
        ? opcionalesCubiertas.length / opcionales.length
        : null
    const ratioDescripcion = totalDesc
        ? analisisDesc.cubiertas.length / totalDesc
        : null

    // Si no hay términos de descripción pero sí requisitos obligatorios y
    // deseables, mantiene la proporción clásica 70/30. Si hay descripción,
    // aplica 50 % obligatorias + 20 % deseables + 30 % descripción,
    // normalizando entre los bloques presentes.
    let sumaPuntos = 0
    let sumaPesos = 0

    if (ratioDescripcion === null && ratioObligatorias !== null && ratioOpcionales !== null) {
        sumaPuntos = ratioObligatorias * 0.7 + ratioOpcionales * 0.3
        sumaPesos = 1
    } else {
        if (ratioObligatorias !== null) {
            sumaPuntos += ratioObligatorias * PESO_OBLIGATORIAS
            sumaPesos += PESO_OBLIGATORIAS
        }
        if (ratioOpcionales !== null) {
            sumaPuntos += ratioOpcionales * PESO_OPCIONALES
            sumaPesos += PESO_OPCIONALES
        }
        if (ratioDescripcion !== null) {
            sumaPuntos += ratioDescripcion * PESO_DESCRIPCION
            sumaPesos += PESO_DESCRIPCION
        }
    }

    const puntuacion = sumaPesos > 0 ? sumaPuntos / sumaPesos : 0

    return {
        puntuacion: Math.round(puntuacion * 100 * 100) / 100,
        sinRequisitos: requisitos.length === 0,
        ...detalle,
    }
}

export async function calcularMatch(
    cvId: string,
    ofertaId: string,
): Promise<ResultadoMatch> {
    const [cv, habilidadesCv, oferta, requisitos] = await Promise.all([
        prisma.cv.findUnique({
            where: { id: cvId },
            select: { contenidoTexto: true },
        }),
        prisma.cvHabilidad.findMany({
            where: { cvId },
            select: {
                habilidadId: true,
                habilidad: { select: { nombre: true } },
            },
        }),
        prisma.oferta.findUnique({
            where: { id: ofertaId },
            select: { titulo: true, descripcion: true },
        }),
        prisma.ofertaRequisito.findMany({
            where: { ofertaId },
            select: {
                habilidadId: true,
                obligatorio: true,
                habilidad: { select: { nombre: true } },
            },
        }),
    ])

    return calcularMatchEnMemoria(cv?.contenidoTexto ?? '', habilidadesCv, {
        titulo: oferta?.titulo ?? null,
        descripcion: oferta?.descripcion ?? null,
        requisitos,
    })
}
