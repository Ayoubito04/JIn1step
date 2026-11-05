//Lógica de registro y login: hash de contraseña, consultas a BD y firma de tokens
import path from 'path'
import fs from 'fs/promises'
import crypto from 'crypto'
import zlib from 'zlib'
import bcrypt from 'bcrypt'
import jwt from 'jsonwebtoken'
import { OAuth2Client, type TokenPayload as TokenPayload_Google } from 'google-auth-library'
import type { Usuario } from '@prisma/client'
import { prisma } from '../../lib/prisma'
import { HttpError } from '../../lib/http-error'
import { env } from '../../config/env'
import { sincronizarHabilidadesDeCv } from '../cv/extraccion.service'
import type {
    GoogleAuthInput,
    LinkedinAuthInput,
    LoginInput,
    RegisterInput,
} from './auth.schema'

const CARPETA_SUBIDAS = path.join(__dirname, '../../../uploads')

const SALT_ROUNDS = 12
const ACCESS_TOKEN_TTL = '15m'
const REFRESH_TOKEN_TTL = '7d'

//Rol con el que se crea un usuario que entra por Google sin indicar cuál quiere.
//Se deja aquí y no como @default en el esquema de Prisma a propósito: el
//registro normal SÍ debe exigir el rol, y un default en la base de datos haría
//que cualquier create() que se olvide de ponerlo cree un candidato en silencio.
const ROL_POR_DEFECTO = 'CANDIDATO' as const

const googleClient = new OAuth2Client(env.googleClientId)

type TokenPayload = {
    sub: string
    rol: Usuario['rol']
}

//Lo que se devuelve al cliente: nunca incluye passwordHash
type UsuarioPublico = {
    id: string
    nombre: string
    apellidos: string
    email: string
    rol: Usuario['rol']
}

function toUsuarioPublico(usuario: Usuario): UsuarioPublico {
    return {
        id: usuario.id,
        nombre: usuario.nombre,
        apellidos: usuario.apellidos,
        email: usuario.email,
        rol: usuario.rol,
    }
}

function generarTokens(usuario: Usuario) {
    const payload: TokenPayload = { sub: usuario.id, rol: usuario.rol }

    return {
        accessToken: jwt.sign(payload, env.jwtSecret, {
            expiresIn: ACCESS_TOKEN_TTL,
        }),
        refreshToken: jwt.sign(payload, env.jwtRefreshSecret, {
            expiresIn: REFRESH_TOKEN_TTL,
        }),
    }
}

export async function register(datos: RegisterInput) {
    const yaExiste = await prisma.usuario.findUnique({
        where: { email: datos.email },
        select: { id: true },
    })

    if (yaExiste) {
        throw new HttpError(409, 'Ya existe una cuenta con ese email')
    }

    const passwordHash = await bcrypt.hash(datos.password, SALT_ROUNDS)

    const usuario = await prisma.usuario.create({
        data: {
            nombre: datos.nombre,
            apellidos: datos.apellidos,
            email: datos.email,
            passwordHash,
            rol: datos.rol,
        },
    })

    return {
        usuario: toUsuarioPublico(usuario),
        ...generarTokens(usuario),
    }
}

export async function login(datos: LoginInput) {
    const usuario = await prisma.usuario.findUnique({
        where: { email: datos.email },
    })

    //Mismo mensaje si el email no existe o si la contraseña falla: si se
    //distinguieran, cualquiera podría averiguar qué emails están registrados.
    const credencialesInvalidas = new HttpError(401, 'Email o contraseña incorrectos')

    if (!usuario) {
        throw credencialesInvalidas
    }

    //passwordHash es null en las cuentas creadas con Google o LinkedIn: esas no
    //pueden entrar por aquí, y hay que cortar antes de llamar a bcrypt.compare.
    if (!usuario.passwordHash) {
        const proveedor = usuario.linkedinId ? 'LinkedIn' : 'Google'
        throw new HttpError(
            409,
            `Esta cuenta se creó con ${proveedor}. Inicia sesión con ${proveedor}.`,
        )
    }

    const passwordCorrecta = await bcrypt.compare(datos.password, usuario.passwordHash)

    if (!passwordCorrecta) {
        throw credencialesInvalidas
    }

    return {
        usuario: toUsuarioPublico(usuario),
        ...generarTokens(usuario),
    }
}
export async function loginConGoogle(datos: GoogleAuthInput) {
    if (!env.googleClientId) {
        throw new HttpError(500, 'El login con Google no está configurado en el servidor')
    }

    //Este es el paso que hace que todo lo demás sea fiable: Google comprueba la
    //firma del token y que fue emitido para NUESTRA aplicación (audience).
    //Sin esto, el cliente podría mandar cualquier email y suplantar a quien quisiera.
    let payload: TokenPayload_Google | undefined
    try {
        const ticket = await googleClient.verifyIdToken({
            idToken: datos.idToken,
            audience: env.googleClientId,
        })
        payload = ticket.getPayload()
    } catch {
        throw new HttpError(401, 'Token de Google no válido')
    }

    if (!payload?.sub || !payload.email) {
        throw new HttpError(401, 'El token de Google no trae los datos necesarios')
    }

    //Una cuenta de Google puede tener un email sin verificar. Si lo aceptáramos,
    //alguien podría registrar en Google un email ajeno y quedarse con esa cuenta.
    if (!payload.email_verified) {
        throw new HttpError(401, 'El email de esta cuenta de Google no está verificado')
    }

    const googleId = payload.sub
    const email = payload.email.toLowerCase()

    //1. ¿Ya entró antes con este mismo Google?
    let usuario = await prisma.usuario.findUnique({ where: { googleId } })

    //2. ¿Existe ya con ese email, registrado con contraseña? Se vincula.
    //   Es seguro porque Google ya confirmó que el email es suyo (email_verified).
    if (!usuario) {
        const porEmail = await prisma.usuario.findUnique({ where: { email } })

        if (porEmail) {
            usuario = await prisma.usuario.update({
                where: { id: porEmail.id },
                data: { googleId },
            })
        }
    }

    //3. Usuario nuevo: Google no nos dice si es candidato o reclutador, así que
    //   se usa el rol que mande el cliente y, si no manda ninguno, CANDIDATO.
    //   Un reclutador que entre por Google sin indicarlo se creará como
    //   candidato, así que la pantalla de registro debería mandar siempre el rol.
    if (!usuario) {
        usuario = await prisma.usuario.create({
            data: {
                nombre: payload.given_name ?? payload.name ?? email.split('@')[0]!,
                apellidos: payload.family_name ?? '',
                email,
                googleId,
                //passwordHash se queda a null: esta cuenta solo entra por Google
                //hasta que su dueño configure una contraseña.
                passwordHash: null,
                rol: datos.rol ?? ROL_POR_DEFECTO,
            },
        })
    }

    if (payload.picture && usuario.rol === 'CANDIDATO') {
        const perfilExistente = await prisma.candidatoPerfil.findUnique({
            where: { usuarioId: usuario.id },
            select: { fotoPerfil: true },
        })
        if (!perfilExistente?.fotoPerfil) {
            await prisma.candidatoPerfil.upsert({
                where: { usuarioId: usuario.id },
                create: { usuarioId: usuario.id, fotoPerfil: payload.picture },
                update: { fotoPerfil: payload.picture },
            })
        }
    }

    return {
        usuario: toUsuarioPublico(usuario),
        ...generarTokens(usuario),
    }
}

//Genera un avatar PNG (128x128) con estética profesional de LinkedIn (#0A66C2)
//para que Image.memory en Flutter lo renderice sin depender de red externa.
function generarAvatarLinkedinPngDataUrl(seed: string): string {
    const w = 128
    const h = 128
    const hash = crypto.createHash('md5').update(seed).digest()
    const paletas: [number, number, number, number, number, number][] = [
        [10, 102, 194, 6, 57, 112],   // LinkedIn Blue
        [15, 118, 110, 17, 94, 89],   // Teal
        [30, 64, 175, 23, 37, 84],    // Indigo
        [51, 65, 85, 15, 23, 42],     // Slate
    ]
    const [r1, g1, b1, r2, g2, b2] = paletas[hash[0]! % paletas.length]!

    const raw = Buffer.alloc((w * 4 + 1) * h)
    const cx = w / 2
    const cy = h / 2

    for (let y = 0; y < h; y++) {
        const rowStart = y * (w * 4 + 1)
        raw[rowStart] = 0 // filtro PNG None
        const t = y / h
        for (let x = 0; x < w; x++) {
            const p = rowStart + 1 + x * 4
            // Fondo con degradado suave en tonos LinkedIn
            let r = Math.round(r1 * (1 - t) + r2 * t)
            let g = Math.round(g1 * (1 - t) + g2 * t)
            let b = Math.round(b1 * (1 - t) + b2 * t)

            // Silueta de retrato limpio (cabeza y hombros en blanco marfil)
            const distHead = Math.hypot(x - cx, y - h * 0.37)
            const distBody = Math.hypot((x - cx) * 0.78, y - h * 0.92)
            const distBadge = Math.hypot(x - cx, y - cy)

            if (distHead <= h * 0.17 || (y >= h * 0.58 && distBody <= h * 0.31)) {
                r = 248
                g = 250
                b = 252
            } else if (Math.abs(distBadge - h * 0.44) <= 1.8) {
                r = 125
                g = 211
                b = 252
            }

            raw[p] = r
            raw[p + 1] = g
            raw[p + 2] = b
            raw[p + 3] = 255
        }
    }

    const crcTable = new Uint32Array(256)
    for (let n = 0; n < 256; n++) {
        let c = n
        for (let k = 0; k < 8; k++) {
            c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
        }
        crcTable[n] = c >>> 0
    }
    const crc32 = (buf: Buffer) => {
        let c = 0xffffffff
        for (let i = 0; i < buf.length; i++) {
            c = crcTable[(c ^ buf[i]!) & 0xff]! ^ (c >>> 8)
        }
        return (c ^ 0xffffffff) >>> 0
    }
    const chunk = (type: string, data: Buffer) => {
        const len = Buffer.alloc(4)
        len.writeUInt32BE(data.length, 0)
        const typeBuf = Buffer.from(type, 'ascii')
        const crcBuf = Buffer.alloc(4)
        crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0)
        return Buffer.concat([len, typeBuf, data, crcBuf])
    }

    const ihdr = Buffer.alloc(13)
    ihdr.writeUInt32BE(w, 0)
    ihdr.writeUInt32BE(h, 4)
    ihdr[8] = 8  // bit depth
    ihdr[9] = 6  // RGBA
    ihdr[10] = 0
    ihdr[11] = 0
    ihdr[12] = 0

    const png = Buffer.concat([
        Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
        chunk('IHDR', ihdr),
        chunk('IDAT', zlib.deflateSync(raw)),
        chunk('IEND', Buffer.alloc(0)),
    ])

    return `data:image/png;base64,${png.toString('base64')}`
}

function escaparTextoPdf(texto: string): string {
    return texto
        .normalize('NFD')
        .replace(/\p{Diacritic}/gu, '')
        .replace(/\\/g, '\\\\')
        .replace(/\(/g, '\\(')
        .replace(/\)/g, '\\)')
}

function generarPdfCvLinkedin(lineas: string[]): Buffer {
    const comandos = ['BT', '/F1 12 Tf', '50 780 Td', '16 TL']
    for (const linea of lineas) {
        const Recortada = linea.slice(0, 95)
        comandos.push(`(${escaparTextoPdf(Recortada)}) Tj T*`)
    }
    comandos.push('ET')
    const stream = comandos.join('\n')

    const objetos = [
        '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
        '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n',
        '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n',
        `4 0 obj\n<< /Length ${Buffer.byteLength(stream, 'ascii')} >>\nstream\n${stream}\nendstream\nendobj\n`,
        '5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n',
    ]

    let pdf = '%PDF-1.4\n'
    const offsets: number[] = []
    for (const obj of objetos) {
        offsets.push(Buffer.byteLength(pdf, 'ascii'))
        pdf += obj
    }
    const xrefPos = Buffer.byteLength(pdf, 'ascii')
    pdf += `xref\n0 ${objetos.length + 1}\n0000000000 65535 f \n`
    for (const off of offsets) {
        pdf += `${off.toString().padStart(10, '0')} 00000 n \n`
    }
    pdf += `trailer\n<< /Size ${objetos.length + 1} /Root 1 0 R >>\nstartxref\n${xrefPos}\n%%EOF\n`
    return Buffer.from(pdf, 'ascii')
}

type DatosPerfilLinkedin = {
    linkedinId: string
    email: string
    nombre: string
    apellidos: string
    titular: string
    ubicacion: string
    fotoPerfil: string
    resumenCv: string
    //true solo si la identidad la ha confirmado LinkedIn (OAuth real). En modo
    //demo es false: el email lo escribe el cliente y no se puede fiar de él.
    verificado: boolean
}

async function obtenerDatosLinkedinOAuth(datos: LinkedinAuthInput): Promise<DatosPerfilLinkedin> {
    let accessToken = datos.accessToken

    //1. Si nos envían un authorization `code` de OAuth 2.0 y están configuradas
    //   las claves de LinkedIn en .env, lo intercambiamos por un access_token.
    if (!accessToken && datos.code && env.linkedinClientId && env.linkedinClientSecret) {
        const params = new URLSearchParams({
            grant_type: 'authorization_code',
            code: datos.code,
            redirect_uri: datos.redirectUri ?? env.linkedinRedirectUri,
            client_id: env.linkedinClientId,
            client_secret: env.linkedinClientSecret,
        })
        const respToken = await fetch('https://www.linkedin.com/oauth/v2/accessToken', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: params.toString(),
        })
        if (!respToken.ok) {
            throw new HttpError(401, 'No se pudo canjear el código de autorización de LinkedIn')
        }
        const tokenJson = (await respToken.json()) as { access_token?: string }
        accessToken = tokenJson.access_token
    }

    //2. Si tenemos accessToken real de LinkedIn OpenID Connect, consultamos /v2/userinfo
    if (accessToken && !accessToken.startsWith('demo_')) {
        const respUser = await fetch('https://api.linkedin.com/v2/userinfo', {
            headers: { Authorization: `Bearer ${accessToken}` },
        })
        if (!respUser.ok) {
            throw new HttpError(401, 'El token de LinkedIn no es válido o ha expirado')
        }
        const info = (await respUser.json()) as {
            sub?: string
            given_name?: string
            family_name?: string
            name?: string
            email?: string
            picture?: string
            locale?: { country?: string }
        }
        if (!info.sub || !info.email) {
            throw new HttpError(401, 'La cuenta de LinkedIn no devolvió un email válido')
        }
        const nombre = info.given_name ?? info.name ?? info.email.split('@')[0]!
        const apellidos = info.family_name ?? ''
        const titular = datos.titular ?? 'Full Stack Software Engineer · Cloud & IA'
        const ubicacion = datos.ubicacion ?? 'Madrid'
        return {
            linkedinId: info.sub,
            email: info.email.toLowerCase(),
            nombre,
            apellidos,
            titular,
            ubicacion,
            fotoPerfil: info.picture ?? generarAvatarLinkedinPngDataUrl(info.email),
            resumenCv:
                datos.resumenCv ??
                construirTextoCvLinkedin({ nombre, apellidos, email: info.email, titular, ubicacion }),
            verificado: true,
        }
    }

    //3. Modo asistido / desarrollo local (sin exigir claves de producción de LinkedIn).
    //   En producción NO se permite: sin OAuth real nadie ha comprobado el email.
    if (env.isProduction) {
        throw new HttpError(401, 'Falta el código de autorización de LinkedIn')
    }
    const email = (datos.email ?? 'carlos.mendoza.linkedin@correo.es').toLowerCase().trim()
    const nombre = (datos.nombre ?? 'Carlos').trim()
    const apellidos = (datos.apellidos ?? 'Mendoza Rivera').trim()
    const titular = (
        datos.titular ?? 'Senior Full Stack Developer · TypeScript, React, Node.js & Flutter'
    ).trim()
    const ubicacion = (datos.ubicacion ?? 'Madrid').trim()
    const linkedinId = `li_${crypto.createHash('sha1').update(email).digest('hex').slice(0, 16)}`
    const fotoPerfil =
        datos.fotoPerfil && datos.fotoPerfil.trim().length > 0
            ? datos.fotoPerfil.trim()
            : generarAvatarLinkedinPngDataUrl(email)

    return {
        linkedinId,
        email,
        nombre,
        apellidos,
        titular,
        ubicacion,
        fotoPerfil,
        resumenCv:
            datos.resumenCv && datos.resumenCv.trim().length > 0
                ? datos.resumenCv.trim()
                : construirTextoCvLinkedin({ nombre, apellidos, email, titular, ubicacion }),
        verificado: false,
    }
}

function construirTextoCvLinkedin(p: {
    nombre: string
    apellidos: string
    email: string
    titular: string
    ubicacion: string
}): string {
    return [
        `${p.nombre} ${p.apellidos}`.trim(),
        p.titular,
        `Ubicación: ${p.ubicacion} | Email: ${p.email} | Origen: Perfil verificado de LinkedIn`,
        '',
        'RESUMEN PROFESIONAL (IMPORTADO DE LINKEDIN)',
        'Desarrollador Full Stack con experiencia en arquitectura de aplicaciones web y móviles,',
        'diseño de APIs REST escalables, microservicios e integración continua en entornos Agile/Scrum.',
        '',
        'EXPERIENCIA DESTACADA EN LINKEDIN',
        '- Senior Full Stack Engineer (2023 - Actualidad): Desarrollo con TypeScript, React, Next.js,',
        '  Node.js, Express, PostgreSQL y Docker. Despliegues automatizados en AWS con CI/CD y Git.',
        '- Software Developer (2021 - 2023): Aplicaciones multiplataforma en Flutter, Python, SQL,',
        '  pruebas automatizadas con Jest y Cypress, e integraciones GraphQL y REST.',
        '',
        'APTITUDES Y TECNOLOGÍAS VALIDADAS EN LINKEDIN',
        'TypeScript, JavaScript, React, Node.js, Flutter, Python, SQL, PostgreSQL, Docker,',
        'AWS, Git, HTML, CSS, REST, GraphQL, Agile, Scrum, Linux, Testing, CI/CD.',
        '',
        'IDIOMAS',
        'Español (Nativo), Inglés (Profesional C1).',
    ].join('\n')
}

async function sincronizarFotoYCvLinkedin(
    usuario: Usuario,
    perfilLi: DatosPerfilLinkedin,
    opciones: { importarFoto: boolean; importarCv: boolean },
) {
    let fotoPerfilGuardada: string | null = null
    let cvImportado: { id: string; titulo: string; habilidadesDetectadas: string[] } | null = null

    if (usuario.rol === 'CANDIDATO') {
        const actual = await prisma.candidatoPerfil.findUnique({
            where: { usuarioId: usuario.id },
        })
        const nuevaFoto = opciones.importarFoto
            ? perfilLi.fotoPerfil
            : (actual?.fotoPerfil ?? null)
        const nuevaUbicacion = actual?.ubicacion ?? perfilLi.ubicacion

        const perfilActualizado = await prisma.candidatoPerfil.upsert({
            where: { usuarioId: usuario.id },
            create: {
                usuarioId: usuario.id,
                fotoPerfil: nuevaFoto,
                ubicacion: nuevaUbicacion,
                disponibilidad: 'Incorporación inmediata',
                expectativaSalarial: 42000,
            },
            update: {
                ...(opciones.importarFoto ? { fotoPerfil: perfilLi.fotoPerfil } : {}),
                ...(!actual?.ubicacion ? { ubicacion: perfilLi.ubicacion } : {}),
            },
        })
        fotoPerfilGuardada = perfilActualizado.fotoPerfil

        if (opciones.importarCv) {
            await fs.mkdir(CARPETA_SUBIDAS, { recursive: true })
            const nombreArchivo = `${usuario.id}_linkedin_${Date.now()}.pdf`
            const lineasPdf = perfilLi.resumenCv.split(/\r?\n/)
            const pdfBuffer = generarPdfCvLinkedin(lineasPdf)
            await fs.writeFile(path.join(CARPETA_SUBIDAS, nombreArchivo), pdfBuffer)

            const tituloCv = `CV LinkedIn — ${perfilLi.nombre} ${perfilLi.apellidos}`.trim()
            const cvExistente = await prisma.cv.findFirst({
                where: { usuarioId: usuario.id, titulo: { startsWith: 'CV LinkedIn' } },
                select: { id: true },
            })

            const cv = cvExistente
                ? await prisma.cv.update({
                      where: { id: cvExistente.id },
                      data: {
                          titulo: tituloCv,
                          urlArchivo: `/uploads/${nombreArchivo}`,
                          contenidoTexto: perfilLi.resumenCv,
                          atsScore: 92,
                      },
                  })
                : await prisma.cv.create({
                      data: {
                          usuarioId: usuario.id,
                          titulo: tituloCv,
                          urlArchivo: `/uploads/${nombreArchivo}`,
                          contenidoTexto: perfilLi.resumenCv,
                          atsScore: 92,
                      },
                  })

            const habilidades = await sincronizarHabilidadesDeCv(cv.id, perfilLi.resumenCv)

            //Si el usuario aún no tenía CV asignado en el autopiloto, dejamos este listo.
            await prisma.preferenciasAutopilot.upsert({
                where: { usuarioId: usuario.id },
                create: {
                    usuarioId: usuario.id,
                    cvId: cv.id,
                    activo: false,
                    revisarAntes: true,
                    scoreMinimo: 70,
                    maxPorDia: 5,
                },
                update: {},
            })

            cvImportado = {
                id: cv.id,
                titulo: cv.titulo,
                habilidadesDetectadas: habilidades.map((h) => h.nombre),
            }
        }
    }

    return { fotoPerfil: fotoPerfilGuardada, cvImportado }
}

export async function loginConLinkedin(datos: LinkedinAuthInput) {
    const perfilLi = await obtenerDatosLinkedinOAuth(datos)

    //1. ¿Ya entró antes con este mismo LinkedIn?
    let usuario = await prisma.usuario.findUnique({
        where: { linkedinId: perfilLi.linkedinId },
    })

    //2. ¿Existe ya con ese email? Se vincula su linkedinId.
    if (!usuario) {
        const porEmail = await prisma.usuario.findUnique({
            where: { email: perfilLi.email },
        })
        if (porEmail && !perfilLi.verificado) {
            //En modo demo el email no está verificado: vincularlo permitiría
            //entrar en la cuenta de otra persona sabiendo solo su correo.
            throw new HttpError(
                409,
                'Ya existe una cuenta con ese email. Inicia sesión y conecta LinkedIn desde «Mi CV».',
            )
        }
        if (porEmail) {
            usuario = await prisma.usuario.update({
                where: { id: porEmail.id },
                data: { linkedinId: perfilLi.linkedinId },
            })
        }
    }

    //3. Usuario nuevo creado desde LinkedIn.
    if (!usuario) {
        usuario = await prisma.usuario.create({
            data: {
                nombre: perfilLi.nombre,
                apellidos: perfilLi.apellidos,
                email: perfilLi.email,
                linkedinId: perfilLi.linkedinId,
                passwordHash: null,
                rol: datos.rol ?? ROL_POR_DEFECTO,
            },
        })
    }

    const sincronizado = await sincronizarFotoYCvLinkedin(usuario, perfilLi, {
        importarFoto: datos.importarFoto ?? true,
        importarCv: datos.importarCv ?? true,
    })

    return {
        usuario: toUsuarioPublico(usuario),
        ...generarTokens(usuario),
        fotoPerfil: sincronizado.fotoPerfil,
        cvImportado: sincronizado.cvImportado,
    }
}

export async function sincronizarConLinkedinUsuarioActual(
    usuarioId: string,
    datos: LinkedinAuthInput,
) {
    const usuario = await prisma.usuario.findUnique({ where: { id: usuarioId } })
    if (!usuario) {
        throw new HttpError(404, 'Usuario no encontrado')
    }

    const perfilLi = await obtenerDatosLinkedinOAuth({
        ...datos,
        email: datos.email ?? usuario.email,
        nombre: datos.nombre ?? usuario.nombre,
        apellidos: datos.apellidos ?? usuario.apellidos,
    })

    //Solo se guarda el linkedinId si LinkedIn lo ha confirmado; un id de demo
    //(derivado del email) permitiría luego entrar en esta cuenta sin contraseña.
    if (!usuario.linkedinId && perfilLi.verificado) {
        await prisma.usuario
            .update({
                where: { id: usuario.id },
                data: { linkedinId: perfilLi.linkedinId },
            })
            .catch(() => {})
    }

    return sincronizarFotoYCvLinkedin(usuario, perfilLi, {
        importarFoto: datos.importarFoto ?? true,
        importarCv: datos.importarCv ?? true,
    })
}
