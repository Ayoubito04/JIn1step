//Aquí es dónde la app escuchará al servidor
//Aquí escuchamos el servidor
import { CreateApp } from "./app";

import { env } from "./config/env"

const App=CreateApp();

App.listen(env.port, () => {
  console.log(`Servidor escuchando en http://localhost:${env.port}/api/health`);
});