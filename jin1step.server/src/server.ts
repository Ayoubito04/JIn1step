//Aquí es dónde la app escuchará al servidor
//Aquí escuchamos el servidor
import { CreateApp } from "./app";

import { env } from "./config/env"
import { ejecutarAutopilotsActivos } from "./modules/postulaciones_autopilot/postulaciones_autopilot.service"

const App=CreateApp();

const UN_DIA_MS = 24 * 60 * 60 * 1000

async function procesarAutopilotsDelDia() {
  try {
    const resultado = await ejecutarAutopilotsActivos()
    console.log(
      `Autopiloto diario: ${resultado.usuariosProcesados} usuarios, ` +
        `${resultado.candidaturasCreadas} candidaturas, ${resultado.fallos} fallos.`,
    )
  } catch (error) {
    console.error('No se pudo iniciar la pasada diaria del autopiloto:', error)
  }
}

App.listen(env.port, () => {
  console.log(`Servidor escuchando en http://localhost:${env.port}/api/health`);
  // No disparar postulaciones reales automáticamente mientras se desarrolla
  // o prueba localmente; el modo de simulación está disponible en desarrollo.
  if (env.isProduction) {
    void procesarAutopilotsDelDia()
    setInterval(() => void procesarAutopilotsDelDia(), UN_DIA_MS)
  }
});
