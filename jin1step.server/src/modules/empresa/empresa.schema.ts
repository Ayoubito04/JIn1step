//Validación del alta de una empresa. No hay schema de actualización a propósito:
//las empresas son un registro compartido y su edición se hace desde admin, no
//por API (ver comentario en empresa.service.ts).
import { z } from 'zod'

//.strict() y no el strip por defecto de Zod.
//
//Con el comportamiento normal, una errata del frontend como "sitoWeb" pasa la
//validación, el campo se descarta en silencio y la empresa se crea sin web sin
//que nadie se entere. Con strict devuelve 400 diciendo qué clave sobra.
//Mismo criterio que en el resto de schemas del proyecto.
export const crearEmpresaSchema = z
    .object({
        nombre: z
            .string()
            .trim()
            .min(1, 'El nombre de la empresa es obligatorio')
            .max(150, 'El nombre no puede superar los 150 caracteres'),

        //Los tres opcionales aceptan null explícitamente para que el frontend
        //pueda desasignar un valor (mandando null) sin tener que omitir el campo.
        sector: z
            .string()
            .trim()
            .min(1, 'El sector no puede estar vacío')
            .max(100, 'El sector no puede superar los 100 caracteres')
            .nullish(),

        ubicacion: z
            .string()
            .trim()
            .min(1, 'La ubicación no puede estar vacía')
            .max(150, 'La ubicación no puede superar los 150 caracteres')
            .nullish(),

        //protocol restringido a http/https A PROPÓSITO.
        //
        //z.url() a secas acepta CUALQUIER esquema válido, incluido
        //"javascript:alert(document.cookie)" y "data:text/html,<script>...".
        //Ese valor se guarda en BD y el frontend lo pinta como
        //<a href={empresa.sitioWeb}>, así que un reclutador podría robar la
        //sesión de cualquiera que mire su ficha. Es XSS almacenado.
        //
        //hostname no vacío descarta además "http://" y "https://" pelados,
        //que z.url() da por buenos.
        sitioWeb: z
            .url({
                protocol: /^https?$/,
                hostname: /.+/,
                error: 'El sitio web debe ser una URL http o https válida',
            })
            .max(300, 'El sitio web no puede superar los 300 caracteres')
            .nullish(),
    })
    .strict()

export type CrearEmpresaInput = z.infer<typeof crearEmpresaSchema>
