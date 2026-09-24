//Aquí ira el nucelo de nuestro servidor
import cors from 'cors'
import express, {type Express} from 'express';
import helmet from 'helmet'
import morgan from  'morgan'
import {env} from './config/env'
import { router } from './routes';
import { ErrorHandler,notFoundHandler } from './middlewares/error.middlewares';
import { suscripcionWebhookRouter } from './modules/suscripcion/suscripcion.webhook';

export function CreateApp():Express{
  const app=express();
app.use(helmet())
app.use(cors())
//El webhook de Stripe va ANTES del express.json() y no despues.
//constructEvent recalcula la firma sobre el cuerpo CRUDO; si json() lo
//parsea primero, el body deja de coincidir con lo que Stripe firmo y todos
//los eventos se rechazan con "no signatures found matching the payload".
app.use('/api/suscripciones/webhook', suscripcionWebhookRouter)

app.use(express.json())
app.use(morgan(env.isProduction ? "combined" : "dev"))

//Las rutas van antes del 404, si no todo caería en "Ruta no encontrada"
app.use('/api', router)

app.use(notFoundHandler)
app.use(ErrorHandler);
  return app;
}
