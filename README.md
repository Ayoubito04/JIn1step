# JIn1Step

**Buscar trabajo en un solo paso.** JIn1Step es una plataforma de empleo que conecta a
candidatos y reclutadores, y que incorpora un **autopiloto de postulaciones**: el candidato
sube su CV una vez, el sistema detecta sus habilidades y se postula automáticamente a las
ofertas que encajan con su perfil, sin que tenga que revisar tablones de empleo cada día.

---

## Tabla de contenidos

- [Qué hace la app](#qué-hace-la-app)
- [Estado del proyecto](#estado-del-proyecto)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Stack tecnológico](#stack-tecnológico)
- [Base de datos](#base-de-datos)
- [API REST](#api-rest)
- [Cómo funciona el matching](#cómo-funciona-el-matching)
- [El autopiloto](#el-autopiloto)
- [Puesta en marcha](#puesta-en-marcha)
- [Tests](#tests)
- [Decisiones de diseño](#decisiones-de-diseño)
- [Pendiente](#pendiente)

---

## Qué hace la app

JIn1Step tiene tres roles (`CANDIDATO`, `RECLUTADOR`, `ADMIN`) y gira en torno a cuatro ideas:

### 1. El CV como fuente de verdad

El candidato sube su currículum en PDF. El servidor extrae el texto, lo cruza contra un
catálogo cerrado de habilidades técnicas (~70 entradas: lenguajes, frameworks, bases de
datos, cloud, testing, idiomas…) y guarda las habilidades detectadas asociadas al CV.
El candidato puede después ajustar esa lista a mano y declarar su nivel
(`BASICO` / `INTERMEDIO` / `AVANZADO`).

### 2. Ofertas con requisitos explícitos

El reclutador crea su empresa y publica ofertas (remoto / híbrido / presencial) marcando qué
habilidades pide y cuáles son **obligatorias** y cuáles **deseables**.

### 3. Match calculado, no adivinado

Cada pareja CV ↔ oferta produce una puntuación de 0 a 100 y el detalle de qué requisitos se
cubren y cuáles faltan. El candidato puede **simular el match antes de postularse**, y el
reclutador ve las postulaciones de su oferta ordenadas por puntuación.

### 4. Autopiloto (función de pago)

Con una suscripción activa, el candidato configura sus preferencias (qué CV usar, puntuación
mínima, máximo de postulaciones al día) y el sistema postula por él a las ofertas abiertas que
superan ese umbral, de mayor a menor match.

Además hay **chat directo** candidato ↔ reclutador, opcionalmente ligado a una oferta concreta,
con contador de mensajes sin leer.

---

## Estado del proyecto

| Parte | Estado |
|---|---|
| **Backend** (API REST + base de datos) | Funcional: 10 módulos, 13 tablas, 6 migraciones, autenticación y tests |
| **Frontend** (app Flutter) | Andamiaje generado por `flutter create`; la UI todavía no está implementada |
| **Pasarela de pago** | Modelada en base de datos, sin integración real con Stripe / Google Play |

El trabajo hecho hasta ahora se ha concentrado en el servidor: estructura por módulos, esquema
de datos con sus restricciones a nivel de base de datos, lógica de negocio y despliegue local
en Docker.

---

## Estructura del repositorio

```
JIn1Step/
├── jin1step/            # Aplicación móvil (Flutter · Dart)
│   ├── lib/main.dart
│   ├── android/ ios/ web/ windows/ macos/ linux/
│   └── pubspec.yaml
│
└── jin1step.server/     # API REST (Node.js · TypeScript · Express 5)
    ├── prisma/
    │   ├── schema.prisma          # 13 modelos + 8 enums
    │   ├── migrations/            # 6 migraciones
    │   └── seed-habilidades.ts    # catálogo inicial de habilidades
    ├── src/
    │   ├── app.ts                 # creación de la app Express
    │   ├── server.ts              # arranque del servidor
    │   ├── config/env.ts          # variables de entorno validadas al arrancar
    │   ├── lib/                   # cliente Prisma y HttpError
    │   ├── middlewares/           # auth (JWT + roles), validación Zod, errores
    │   ├── routes/index.ts        # punto único donde se montan los routers
    │   └── modules/               # un módulo por dominio
    │       ├── auth/              #   registro, login, login con Google
    │       ├── cv/                #   subida de PDF y extracción de habilidades
    │       ├── habilidad/         #   catálogo y habilidades de cada CV
    │       ├── empresa/           #   alta y consulta de empresas
    │       ├── ofertas/           #   publicación y búsqueda de ofertas
    │       ├── postulacion/       #   postulaciones + cálculo del match
    │       ├── preferencias_autopilot/
    │       ├── postulaciones_autopilot/
    │       ├── conversacion/      #   hilos de chat
    │       ├── mensaje/           #   mensajes y contador de no leídos
    │       └── suscripcion/       #   planes y estado de la suscripción
    ├── docker-compose.yml
    └── package.json
```

Cada módulo sigue siempre el mismo patrón: `*.routes.ts` (URLs y permisos) →
`*.controller.ts` (HTTP) → `*.service.ts` (lógica de negocio) + `*.schema.ts` (validación Zod).

---

## Stack tecnológico

**Backend**

| Pieza | Tecnología |
|---|---|
| Lenguaje | TypeScript 5.6 (Node.js, modo `strict`) |
| Framework | Express 5 |
| ORM | Prisma 6 |
| Base de datos | PostgreSQL 16 |
| Validación | Zod 4 |
| Autenticación | JWT (`jsonwebtoken`) + bcrypt + Google Identity (`google-auth-library`) |
| Subida de archivos | Multer (en memoria) + `pdf-parse` para extraer el texto |
| Seguridad | Helmet, CORS, `express-rate-limit` |
| Logs | Morgan |
| Tests | Vitest |
| Entorno | Docker Compose |

**Frontend**

| Pieza | Tecnología |
|---|---|
| Framework | Flutter (Dart SDK ^3.10.7) |
| Plataformas | Android, iOS, Web, Windows, macOS, Linux |

---

## Base de datos

**Un solo motor: PostgreSQL 16**, levantado con Docker Compose y accedido con Prisma.
No hay segunda base de datos ni caché: el esquema completo vive en
[`jin1step.server/prisma/schema.prisma`](jin1step.server/prisma/schema.prisma).

### Tablas (13)

| Tabla | Para qué sirve |
|---|---|
| `usuarios` | Cuentas. Guarda `password_hash` (bcrypt, 12 rondas) y/o `google_id`; el hash es opcional para quien entra solo con Google |
| `candidatos_perfil` | Datos extra del candidato (ubicación, disponibilidad). Relación 1:1 con `usuarios` |
| `empresas` | Empresas que publican ofertas |
| `cvs` | Currículums: título, ruta del archivo, texto ya extraído y `ats_score` |
| `habilidades` | Catálogo global de habilidades. Vocabulario cerrado y único |
| `cv_habilidades` | Puente N:M — qué habilidades tiene cada CV y con qué nivel |
| `ofertas` | Ofertas de empleo: título, descripción, modalidad y estado |
| `oferta_requisitos` | Puente N:M — qué habilidades pide cada oferta y si son obligatorias |
| `postulaciones` | Cada CV aplicado a una oferta, con su `match_score` y si lo hizo la IA |
| `conversaciones` | Hilos de chat candidato ↔ reclutador, opcionalmente sobre una oferta |
| `mensajes` | Mensajes de cada hilo, con marca de leído |
| `suscripciones` | Histórico de suscripciones al autopiloto (plan, estado, precio, fechas) |
| `preferencias_autopilot` | Configuración del autopiloto de cada usuario |

### Enums (8)

`Rol` · `Modalidad` · `EstadoOferta` · `EstadoPostulacion` · `NivelHabilidad` ·
`EstadoSuscripcion` · `ProveedorPago` · `TipoPlan`

Los campos de valores cerrados son enums de PostgreSQL, no cadenas libres: la garantía vive en
la base de datos y no solo en la capa de validación.

### Restricciones que protegen la lógica

Varias reglas de negocio están reforzadas en el propio motor, para que sigan cumpliéndose
aunque falle el código de aplicación:

- `@@unique([cv_id, oferta_id])` en `postulaciones` — un mismo CV no puede postularse dos
  veces a la misma oferta. Es la red de seguridad contra un autopiloto que se ejecute dos veces.
- **Índice único parcial** `suscripciones_una_activa_por_usuario` — un usuario solo puede
  tener una suscripción `ACTIVA` a la vez, pero sí un histórico ilimitado de canceladas o
  vencidas. Evita el cobro duplicado cuando la pasarela reenvía un webhook.
- `id_externo` único y opcional en `suscripciones` — corta en origen los webhooks repetidos
  (en PostgreSQL un índice único admite varios `NULL`, así que las altas sin pagar no chocan).
- `preferencias_autopilot.usuario_id` es clave primaria — una única configuración por usuario,
  imposible tener dos contradictorias.
- Borrados en cascada donde el dato no tiene sentido sin su dueño, y `SET NULL` donde sí lo
  tiene: si el candidato borra el CV asignado al autopiloto, conserva su configuración.

---

## API REST

Base: `http://localhost:3000/api` · Autenticación: `Authorization: Bearer <accessToken>`

| Método | Ruta | Rol | Descripción |
|---|---|---|---|
| `GET` | `/health` | — | Comprobación de vida |
| `POST` | `/auth/register` | — | Alta de usuario |
| `POST` | `/auth/login` | — | Login con email y contraseña |
| `POST` | `/auth/login/google` | — | Login con Google |
| `POST` | `/cv` | auth | Subir CV en PDF (máx. 5 MB) y detectar habilidades |
| `GET` | `/cv` | auth | Listar mis CVs |
| `GET` | `/cv/:id` | auth | Ver un CV |
| `DELETE` | `/cv/:id` | auth | Borrar un CV |
| `GET` | `/habilidades` | auth | Catálogo de habilidades |
| `GET` | `/habilidades/cv/:cvId` | candidato | Habilidades de un CV |
| `POST` | `/habilidades/cv/:cvId` | candidato | Añadir habilidad a un CV |
| `PATCH` | `/habilidades/cv/:cvId/:habilidadId` | candidato | Cambiar el nivel |
| `DELETE` | `/habilidades/cv/:cvId/:habilidadId` | candidato | Quitar habilidad |
| `POST` | `/empresas` | reclutador | Crear empresa |
| `GET` | `/empresas` | reclutador | Listar empresas |
| `GET` | `/ofertas` | auth | Buscar ofertas |
| `GET` | `/ofertas/mias` | reclutador | Mis ofertas publicadas |
| `GET` | `/ofertas/:id` | auth | Ver una oferta |
| `POST` | `/ofertas` | reclutador | Publicar oferta |
| `PATCH` | `/ofertas/:id` | reclutador | Editar oferta |
| `POST` | `/postulaciones` | candidato | Postularse a una oferta |
| `GET` | `/postulaciones/mias` | candidato | Mis postulaciones |
| `POST` | `/postulaciones/simular-match` | candidato | Ver el match **sin** postularse |
| `GET` | `/postulaciones/oferta/:ofertaId` | reclutador | Candidatos de una oferta |
| `PATCH` | `/postulaciones/:id` | reclutador | Cambiar estado (vista, entrevista, rechazada…) |
| `GET` | `/preferencias-autopilot` | candidato | Ver configuración del autopiloto |
| `PATCH` | `/preferencias-autopilot` | candidato | Cambiar configuración |
| `POST` | `/postulaciones-autopilot/ejecutar` | candidato | Lanzar una pasada del autopiloto |
| `GET` | `/conversaciones` | candidato · reclutador | Bandeja de entrada |
| `POST` | `/conversaciones` | candidato · reclutador | Abrir (o recuperar) una conversación |
| `GET` | `/conversaciones/:id/mensajes` | candidato · reclutador | Mensajes del hilo |
| `POST` | `/conversaciones/:id/mensajes` | candidato · reclutador | Enviar mensaje |
| `GET` | `/mensajes/sin-leer` | candidato · reclutador | Contador global de no leídos |

**Autenticación.** El login devuelve un `accessToken` (15 min) y un `refreshToken` (7 días).
Las rutas de `/auth` están limitadas a 10 intentos cada 15 minutos por IP.
`requireAuth` valida firma y caducidad; `requireRol` distingue el 401 (no identificado) del
403 (identificado pero sin permiso).

**Errores.** Todos pasan por un manejador único que traduce `HttpError` y errores de Prisma a
su código HTTP correspondiente, con mensajes en castellano.

---

## Cómo funciona el matching

El `matchScore` es **una fórmula, no un modelo de IA**, y es una decisión deliberada:

- **Coste** — con 1.000 CVs y 500 ofertas hay 500.000 combinaciones; a una llamada de LLM cada
  una, un recálculo completo costaría cientos de euros. Comparar dos conjuntos es SQL.
- **Explicabilidad** — se le puede decir al candidato *«te falta Docker, que era obligatorio»*.
  Un LLM devuelve un 73 y no sabe justificarlo.
- **Reproducibilidad** — el mismo CV y la misma oferta dan siempre el mismo resultado.

El cálculo compara las habilidades del CV con los requisitos de la oferta:

```
puntuación = (% requisitos obligatorios cubiertos × 0,7)
           + (% requisitos deseables cubiertos    × 0,3)
```

Con dos matices: si la oferta solo tiene requisitos de un tipo, ese tipo se lleva el 100 % del
peso (repartir 0,7/0,3 daría un máximo de 70), y una oferta sin requisitos puntúa 100 para no
penalizar al candidato por un descuido del reclutador. Junto a la nota se devuelve siempre el
desglose: obligatorias cubiertas, obligatorias que faltan, deseables cubiertas y deseables que
faltan.

La **detección de habilidades del CV** sigue el mismo criterio: busca en el texto los nombres
del catálogo, normalizando mayúsculas y tildes y admitiendo sinónimos (`js` → JavaScript,
`k8s` → Kubernetes, `postgres` → PostgreSQL…), con una expresión regular que evita falsos
positivos como detectar «JS» dentro de «Node.js». Su límite conocido es que no entiende el
contexto: *«no tengo experiencia en React»* cuenta como React. Si algún día hace falta, se
sustituye solo esa función por un LLM y el resto del sistema no se entera.

---

## El autopiloto

Una pasada de `POST /postulaciones-autopilot/ejecutar` hace esto, en orden:

1. **Comprueba la suscripción.** Sin una activa, `402 Payment Required` y no se mira nada más.
2. **Lee las preferencias.** Si están desactivadas o no hay CV asignado, `409 Conflict`.
3. **Reverifica el CV.** Entre configurarlo y ejecutar pueden pasar semanas y el usuario
   puede haberlo borrado.
4. **Aplica el tope diario.** Cuenta las postulaciones que la IA ya ha creado desde las 00:00
   de hoy, no las de la sesión, para que dos ejecuciones no se salten el límite.
5. **Busca ofertas abiertas** a las que el usuario no se haya postulado con **ninguno** de sus
   CVs.
6. **Puntúa, filtra por la nota mínima, ordena de mayor a menor** y se queda con las que caben
   en el hueco restante del día.
7. **Crea las postulaciones** con `postuladoPorIa: true`, estado `ENVIADA` y
   `skipDuplicates` como última red contra ejecuciones solapadas.

Nunca falla en silencio: si no crea nada, devuelve el motivo
(`limite_diario_alcanzado`, `sin_ofertas_disponibles`, `sin_ofertas_sobre_score_minimo`).

Valores por defecto: desactivado, puntuación mínima 70, máximo 5 postulaciones al día.
El autopiloto **nunca se activa solo**: requiere consentimiento explícito, que queda registrado
con fecha en `activado_en` / `revocado_en`.

---

## Puesta en marcha

### Requisitos

- Node.js 20 o superior
- Docker Desktop (para PostgreSQL)
- Flutter SDK (solo para la app móvil)

### Backend

```bash
cd jin1step.server

# 1. Dependencias
npm install

# 2. Variables de entorno
cp .env.example .env
# Genera los dos secretos con:
#   node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"

# 3. Base de datos en Docker
docker compose up -d postgres

# 4. Migraciones y catálogo de habilidades
npx prisma migrate dev
npx ts-node --transpile-only prisma/seed-habilidades.ts

# 5. Arrancar en desarrollo (recarga en caliente)
npm run dev
```

Comprobación: `http://localhost:3000/api/health` debe responder `{"status":"ok"}`.

**Variables de entorno**

| Variable | Obligatoria | Descripción |
|---|---|---|
| `DATABASE_URL` | Sí | Cadena de conexión a PostgreSQL |
| `JWT_SECRET` | Sí | Secreto para firmar el access token |
| `JWT_REFRESH_SECRET` | Sí | Secreto para firmar el refresh token |
| `PORT` | No | Puerto del servidor (3000 por defecto) |
| `NODE_ENV` | No | `development` por defecto |
| `GOOGLE_CLIENT_ID` | No | Necesaria solo para el login con Google |

El servidor valida estas variables **al arrancar** y falla de inmediato con un mensaje claro si
falta alguna obligatoria, en vez de reventar más tarde en la primera petición.

**Otros comandos**

```bash
npm run build     # compila a dist/
npm start         # ejecuta la versión compilada
npx prisma studio # explorador visual de la base de datos
```

### App Flutter

```bash
cd jin1step
flutter pub get
flutter run
```

---

## Tests

```bash
cd jin1step.server
npm test          # una pasada
npm run test:watch
```

Son **tests de integración**: hablan con PostgreSQL de verdad, no con un mock, porque buena
parte de las reglas que hay que verificar (el índice único parcial de «una sola suscripción
activa», las cascadas, los enums) viven en la base de datos y un mock las daría por buenas.
Por eso se ejecutan en serie: dos suites creando y borrando filas a la vez se pisarían.

Cubren, de momento, los servicios de conversaciones, mensajes y suscripciones, además del
esquema de validación de suscripciones.

---

## Decisiones de diseño

- **Un módulo por dominio, siempre con la misma forma** (`routes → controller → service`, más
  `schema` de validación). Añadir una funcionalidad es crear una carpeta y montarla en
  `routes/index.ts`, no tocar un archivo compartido de 2.000 líneas.
- **La validación se hace en el borde.** Zod valida el cuerpo antes de que llegue al
  controlador, así que los servicios reciben datos con forma garantizada.
- **El precio lo fija siempre el servidor.** El cliente elige plan (`MENSUAL` 5 € / `ANUAL`
  50 €), nunca cuánto cuesta. Y solo un webhook firmado puede poner una suscripción en
  `ACTIVA`: ni el cliente ni el endpoint de alta pueden hacerlo.
- **El importe se guarda en céntimos** (entero), nunca en euros con decimales.
- **Los PDFs se validan antes de escribirse.** Multer trabaja en memoria, el servicio extrae el
  texto primero y solo entonces guarda el archivo; si el insert falla, borra el fichero para no
  dejar huérfanos. El nombre del archivo lo genera el servidor, nunca el cliente (un
  `originalname` como `../../.env` permitiría escribir fuera de la carpeta de subidas).
- **Las habilidades se detectan al subir el CV, no al postularse**, para que el match sea una
  comparación de conjuntos y no haya que releer el texto del CV en cada oferta.

---

## Pendiente

- Implementar la interfaz en Flutter y conectarla con la API.
- Montar el router de suscripciones en `routes/index.ts`: el módulo está escrito pero todavía
  no se expone.
- Integrar la pasarela de pago real y su `POST /suscripciones/webhook`, que necesita
  `express.raw()` antes del `express.json()` global para poder verificar la firma.
- Añadir el `Dockerfile` del backend: `docker-compose.yml` ya declara el servicio `backend`
  con `build: .`, así que hoy solo se levanta el contenedor de PostgreSQL.
- Servir los CVs subidos (hoy se guardan en disco local en `uploads/`; el objetivo es
  almacenamiento externo tipo S3 o Supabase Storage).
- Programar el autopiloto con un cron en vez de dispararlo a mano.
- Calcular el `ats_score` del CV, que ya está en el modelo pero aún no se rellena.
- Ampliar la cobertura de tests a CVs, ofertas, postulaciones y matching.
