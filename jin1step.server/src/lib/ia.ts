//Cliente mínimo de IA con salida JSON estructurada. Soporta Gemini y OpenAI.
//
//Se usa fetch en vez de SDKs: solo necesitamos una llamada y así no añadimos
//dependencias. Todo lo que habla con un proveedor pasa por aquí, de modo que
//cambiar de proveedor o de modelo es tocar el .env (o este archivo).
import { env } from '../config/env'
import { HttpError } from './http-error'

type Proveedor = 'gemini' | 'openai'

//IA_PROVIDER manda si está puesto y su clave existe; si no, el primero con clave.
function proveedorActivo(): Proveedor | null {
    const tiene = { gemini: env.geminiApiKey !== '', openai: env.openaiApiKey !== '' }
    if (env.iaProvider === 'gemini' || env.iaProvider === 'openai') {
        return tiene[env.iaProvider] ? env.iaProvider : null
    }
    if (tiene.gemini) return 'gemini'
    if (tiene.openai) return 'openai'
    return null
}

export function iaDisponible(): boolean {
    return proveedorActivo() !== null
}

type OpcionesJson = {
    //Nombre del esquema (solo informativo para la API).
    nombre: string
    //JSON Schema estricto de la respuesta esperada.
    esquema: Record<string, unknown>
    sistema: string
    usuario: string
    timeoutMs?: number
    maxTokens?: number
}

const MODELOS_FALLBACK_GEMINI = [
    'gemini-3.1-flash-lite',
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
]

async function llamarGeminiConModelo(
    modelo: string,
    o: OpcionesJson,
): Promise<string | null | undefined> {
    const respuesta = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${modelo}:generateContent`,
        {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                //La clave va en cabecera, no en la URL, para que no acabe en logs.
                'x-goog-api-key': env.geminiApiKey,
            },
            body: JSON.stringify({
                systemInstruction: { parts: [{ text: o.sistema }] },
                contents: [{ role: 'user', parts: [{ text: o.usuario }] }],
                generationConfig: {
                    temperature: 0.2,
                    maxOutputTokens: o.maxTokens ?? 4000,
                    responseMimeType: 'application/json',
                    responseJsonSchema: o.esquema,
                },
            }),
            signal: AbortSignal.timeout(o.timeoutMs ?? 20_000),
        },
    )
    //Solo el código HTTP: el cuerpo del error podría incluir fragmentos del
    //prompt (datos del CV) y no queremos que acaben en los logs.
    if (!respuesta.ok) throw new Error(`Gemini (${modelo}) respondió ${respuesta.status}`)

    const datos = (await respuesta.json()) as {
        candidates?: { content?: { parts?: { text?: string }[] } }[]
    }
    return datos.candidates?.[0]?.content?.parts?.map((p) => p.text ?? '').join('')
}

async function llamarGemini(o: OpcionesJson): Promise<string | null | undefined> {
    const candidatos = Array.from(
        new Set([env.geminiModel, ...MODELOS_FALLBACK_GEMINI]),
    )
    let ultimoError: unknown
    for (const modelo of candidatos) {
        try {
            return await llamarGeminiConModelo(modelo, o)
        } catch (error) {
            ultimoError = error
        }
    }
    throw ultimoError instanceof Error ? ultimoError : new Error('Gemini no disponible')
}

async function llamarOpenAi(o: OpcionesJson): Promise<string | null | undefined> {
    const respuesta = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${env.openaiApiKey}`,
        },
        body: JSON.stringify({
            model: env.openaiModel,
            temperature: 0.2,
            max_completion_tokens: o.maxTokens ?? 4000,
            messages: [
                { role: 'system', content: o.sistema },
                { role: 'user', content: o.usuario },
            ],
            response_format: {
                type: 'json_schema',
                json_schema: { name: o.nombre, strict: true, schema: o.esquema },
            },
        }),
        signal: AbortSignal.timeout(o.timeoutMs ?? 60_000),
    })
    if (!respuesta.ok) throw new Error(`OpenAI respondió ${respuesta.status}`)

    const datos = (await respuesta.json()) as {
        choices?: { message?: { content?: string | null } }[]
    }
    return datos.choices?.[0]?.message?.content
}

export async function completarJson(opciones: OpcionesJson): Promise<unknown> {
    const proveedor = proveedorActivo()
    if (!proveedor) {
        throw new HttpError(503, 'La IA no está configurada en este servidor')
    }

    const contenido =
        proveedor === 'gemini' ? await llamarGemini(opciones) : await llamarOpenAi(opciones)
    if (!contenido) {
        throw new Error(`${proveedor} no devolvió contenido`)
    }

    return JSON.parse(contenido)
}
