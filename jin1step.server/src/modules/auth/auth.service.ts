//Lógica de registro y login: hash de contraseña, consultas a BD y firma de tokens
import bcrypt from 'bcrypt'
import jwt from 'jsonwebtoken'
import { OAuth2Client, type TokenPayload as TokenPayload_Google } from 'google-auth-library'
import type { Usuario } from '@prisma/client'
import { prisma } from '../../lib/prisma'
import { HttpError } from '../../lib/http-error'
import { env } from '../../config/env'
import type { GoogleAuthInput, LoginInput, RegisterInput } from './auth.schema'

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

    //passwordHash es null en las cuentas creadas con Google: esas no pueden
    //entrar por aquí, y hay que cortar antes de llamar a bcrypt.compare.
    if (!usuario.passwordHash) {
        throw new HttpError(
            409,
            'Esta cuenta se creó con Google. Inicia sesión con Google.',
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

    return {
        usuario: toUsuarioPublico(usuario),
        ...generarTokens(usuario),
    }
}
