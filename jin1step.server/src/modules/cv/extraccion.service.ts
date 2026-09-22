//Extrae las habilidades de un CV buscándolas en el texto, sin IA.
//
//Las habilidades técnicas son un vocabulario cerrado: están todas en la tabla
//Habilidad. Por eso basta con buscarlas, y esto cuesta 0 € frente a una llamada
//por CV a un LLM.
//
//Limitación conocida: no entiende el contexto. "No tengo experiencia en React"
//cuenta como que sabe React. Si algún día eso molesta, se sustituye SOLO esta
//función por una llamada a un LLM; el resto del sistema no se entera.
import { prisma } from '../../lib/prisma'

//Nombres alternativos con los que la gente escribe la misma habilidad.
//La clave es el nombre tal cual está en la tabla Habilidad (sin distinguir
//mayúsculas); el valor, las formas que también valen.
//Vive aquí y no en la BD para no tener que migrar cada vez que se añade un
//sinónimo; si crece mucho, su sitio natural es una tabla HabilidadAlias.
const ALIAS: Record<string, string[]> = {
    javascript: ['js', 'ecmascript'],
    typescript: ['ts'],
    'node.js': ['node', 'nodejs'],
    react: ['react.js', 'reactjs'],
    'vue.js': ['vue', 'vuejs'],
    angular: ['angularjs'],
    postgresql: ['postgres', 'psql'],
    mysql: ['my sql'],
    mongodb: ['mongo'],
    'c#': ['csharp', 'c sharp'],
    'c++': ['cpp'],
    '.net': ['dotnet', 'net core', '.net core'],
    kubernetes: ['k8s'],
    docker: ['contenedores docker'],
    'python': ['py'],
    'inglés': ['ingles', 'english'],
}

//Quita tildes y pasa a minúsculas para que "Inglés", "ingles" e "INGLÉS"
//sean la misma cosa al comparar.
function normalizar(texto: string): string {
    return texto
        .toLowerCase()
        .normalize('NFD')
        .replace(/[̀-ͯ]/g, '')
}

function escaparRegex(texto: string): string {
    return texto.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

//Busca el término como palabra suelta. No se usa \b porque falla con nombres
//que acaban en símbolo: en "C++" o "C#" el \b final no casa donde se espera.
//
//El punto se excluye SOLO por delante, y es importante: sin eso el alias "js"
//casaba dentro de "node.js" y todo CV que mencionara Node.js o Vue.js aparecía
//sabiendo JavaScript. Por detrás sí se permite, o "domino TypeScript." no
//casaría por el punto final de la frase.
function apareceEnTexto(textoNormalizado: string, termino: string): boolean {
    const t = normalizar(termino)

    if (t.length === 0) {
        return false
    }

    const patron = new RegExp(
        `(?<![\\p{L}\\p{N}.])${escaparRegex(t)}(?![\\p{L}\\p{N}])`,
        'u',
    )

    return patron.test(textoNormalizado)
}

export type HabilidadDetectada = {
    habilidadId: string
    nombre: string
}

//Devuelve las habilidades del catálogo que aparecen en el texto del CV.
export async function detectarHabilidades(
    textoCv: string,
): Promise<HabilidadDetectada[]> {
    const catalogo = await prisma.habilidad.findMany({
        select: { id: true, nombre: true },
    })

    const textoNormalizado = normalizar(textoCv)

    return catalogo
        .filter((habilidad) => {
            const alias = ALIAS[habilidad.nombre.toLowerCase()] ?? []
            const terminos = [habilidad.nombre, ...alias]

            return terminos.some((termino) => apareceEnTexto(textoNormalizado, termino))
        })
        .map((habilidad) => ({ habilidadId: habilidad.id, nombre: habilidad.nombre }))
}

//Detecta las habilidades de un CV y las guarda en CvHabilidad.
//Se vuelve a calcular entero en cada llamada: si el candidato sube una versión
//nueva del CV, las habilidades que ya no aparezcan deben desaparecer.
export async function sincronizarHabilidadesDeCv(cvId: string, textoCv: string) {
    const detectadas = await detectarHabilidades(textoCv)

    await prisma.$transaction([
        prisma.cvHabilidad.deleteMany({ where: { cvId } }),
        prisma.cvHabilidad.createMany({
            data: detectadas.map((h) => ({ cvId, habilidadId: h.habilidadId })),
            skipDuplicates: true,
        }),
    ])

    return detectadas
}
