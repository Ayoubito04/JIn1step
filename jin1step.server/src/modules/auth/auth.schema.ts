//Validación de lo que llega por el body. Nada entra al service sin pasar por aquí.
import { z } from 'zod'

//El trim y el toLowerCase van ANTES del check de email: si se encadenan
//después, zod valida el texto en crudo y un " ayoub@x.com " copiado y pegado
//con espacios se rechazaría como email inválido.
const emailSchema = z
    .string()
    .trim()
    .toLowerCase()
    .pipe(z.email('Email no válido'))

//Los roles se escriben a mano en vez de importar el enum de Prisma porque
//ADMIN no debe poder crearse desde un registro público.
export const registerSchema = z.object({
    nombre: z.string().trim().min(1, 'El nombre es obligatorio').max(100),
    apellidos: z.string().trim().min(1, 'Los apellidos son obligatorios').max(150),
    email: emailSchema,
    password: z
        .string()
        .min(8, 'La contraseña debe tener al menos 8 caracteres')
        .max(72, 'La contraseña no puede superar los 72 caracteres'),
    rol: z.enum(['CANDIDATO', 'RECLUTADOR']),
}).strict()

export const loginSchema = z.object({
    email: emailSchema,
    password: z.string().min(1, 'La contraseña es obligatoria'),
}).strict()

//En el login con Google NO se manda email ni contraseña: lo único que se acepta
//es el idToken firmado por Google. El email sale de ese token una vez verificado,
//nunca de lo que diga el cliente.
//El rol solo hace falta la primera vez, cuando hay que crear el usuario; si ya
//existe se ignora y manda el que tenga en la base de datos.
export const googleAuthSchema = z.object({
    idToken: z.string().min(1, 'Falta el idToken de Google'),
    rol: z.enum(['CANDIDATO', 'RECLUTADOR']).optional(),
}).strict()

export type RegisterInput = z.infer<typeof registerSchema>
export type LoginInput = z.infer<typeof loginSchema>
export type GoogleAuthInput = z.infer<typeof googleAuthSchema>
