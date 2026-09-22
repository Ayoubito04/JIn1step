//Valida el body contra un esquema de zod antes de llegar al controller.
//Así los controllers no repiten el .parse() y solo reciben datos ya limpios.
import type { NextFunction, Request, Response } from 'express'
import type { ZodType } from 'zod'
//validate.middlewares.ts es para validar peticiones http,no para validar datos de negocio: eso va en el service. Por eso aquí
export function validateBody(schema: ZodType) {
    return (req: Request, _res: Response, next: NextFunction): void => {
        const resultado = schema.safeParse(req.body) //Esto nos da a entener si se ha cumplido la petición parseando el body con el esquema de zod

        if (!resultado.success) {
            //El ZodError se lo pasamos al ErrorHandler, que ya lo traduce a un
            //400 con el detalle por campo.
            next(resultado.error)
            return
        }
        //En el caso de que la validación http ha sido correcta,se sustituye el body por el dato ya parseado: zod aplica aquí los
        //.trim() y .toLowerCase() del esquema, así que el controller recibe
        //el email normalizado y no lo que escribió el usuario.

        //Se sustituye el body por el dato ya parseado: zod aplica aquí los
        //.trim() y .toLowerCase() del esquema, así que el controller recibe
        //el email normalizado y no lo que escribió el usuario.
        req.body = resultado.data
        next()
    }
}
