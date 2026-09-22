//Esto es para gestionar errores dentro del servidor
import { NextFunction,Request,Response } from "express";
import { ZodError } from "zod";
import { MulterError } from "multer";
import { HttpError } from "../lib/http-error";
//Error.middloewares es para gestionar errores de servidor o con errores 404
export function notFoundHandler(_req:Request,res:Response):void{
    res.status(404).json({
        error:"Ruta no encontrada"
    })
    //En caso de no encontrar la ruta,tendría que aparecer este error

}
export function ErrorHandler(
        err:unknown,
        _req:Request,
        res:Response,
        _next:NextFunction
    ):void{
        //Datos que no pasan la validación de zod -> 400 con el detalle por campo
        if(err instanceof ZodError){
            res.status(400).json({
                error:"Datos inválidos",
                detalles: err.issues.map((i) => ({
                    campo: i.path.join("."),
                    mensaje: i.message,
                })),
            })
            return
        }

        //Fallos al subir archivos (tamaño, campo inesperado...). Sin esto
        //salían como 500 aunque sean culpa de lo que manda el cliente.
        if(err instanceof MulterError){
            const mensaje =
                err.code === 'LIMIT_FILE_SIZE'
                    ? 'El archivo supera el tamaño máximo permitido (5 MB)'
                    : `Error al subir el archivo: ${err.message}`

            res.status(400).json({ error: mensaje })
            return
        }

        //Errores que lanzamos nosotros a propósito (401, 409...)
        if(err instanceof HttpError){
            res.status(err.statusCode).json({
                error: err.message
            })
            return
        }

        //Cualquier otra cosa es un fallo no previsto: se registra entero, pero
        //al cliente no se le envía el mensaje interno para no filtrar detalles
        console.error(err)
        res.status(500).json({
            error:"Error interno del servidor"
        })
    }
    //Esto es para gestionar errores de servidor o con errores 404
