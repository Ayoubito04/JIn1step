//Aquí ira el nucelo de nuestro servidor
import cors from 'cors'
import express, {type Express} from 'express';
import helmet from 'helmet'
import morgan from  'morgan'
import {env} from './config/env'
import { router } from './routes';
import { ErrorHandler,notFoundHandler } from './middlewares/error.middlewares';

export function CreateApp():Express{
  const app=express();
app.use(helmet())
app.use(cors())
app.use(express.json())
app.use(morgan(env.isProduction ? "combined" : "dev"))

//Las rutas van antes del 404, si no todo caería en "Ruta no encontrada"
app.use('/api', router)

app.use(notFoundHandler)
app.use(ErrorHandler);
  return app;
}
