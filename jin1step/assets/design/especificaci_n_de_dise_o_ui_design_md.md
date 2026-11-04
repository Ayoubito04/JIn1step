# DESIGN.md — Interfaz de JIn1Step (Flutter)

Documento para la IA que implementa la UI. Complementa a `/design/screens/*.dc.html` (valores exactos) y `/design/png/*.png` (referencia visual).
**Orden de prioridad si hay conflicto:** HTML de la pantalla > este documento > PNG. Si algo no está definido, pregunta: no lo inventes.

> **Cambios de esta versión:** estilo "libro de cuentas" del taste skill (`achromatic-ledger`) aplicado sobre tu versión anterior + coreografía de datos **Autonomous Ops**. El azul de marca deja de ir en la estructura y pasa a los datos; el botón principal es casi negro y plano; se eliminan degradados, resplandores, recuadros de color en los iconos y sombras en reposo. Una sola familia tipográfica (Bricolage Grotesque) más una monoespaciada solo para cifras. Nuevo elemento propio: los **pasos** (ver 3.1). Incluye la pantalla **Mi perfil** y el componente **`InlineNotice`** para avisos contextuales.

## 1. Producto
JIn1Step: plataforma de empleo con autopiloto de postulaciones. Lema: "Buscar trabajo en un solo paso".
Roles de la API: `CANDIDATO`, `RECLUTADOR`, `ADMIN`. **Solo está diseñada la experiencia del candidato.** Las pantallas de reclutador no existen todavía: no las inventes (si el usuario selecciona `Reclutador/a` en Registro, muestra un `InlineNotice` informativo indicando que esa vista está en desarrollo).
Backend en `/jin1step.server` (Express + Prisma). No se modifica. Los datos del diseño son de ejemplo ("Demo", nombres ficticios) pero **cuadran entre pantallas** (ver sección 10).

## 2. Tokens

### Colores (presupuesto: menos del 1 % de píxeles con color)
| Token | Valor | Uso |
|---|---|---|
| `ground` | `#F2F4F7` | Fondo de pantalla (gris azulado, tomado del mundo del producto) |
| `surface` | `#FFFFFF` | Paneles, filas, campos |
| `active` | `#EEEEEE` | Pestaña activa, fila o celda presionada, botón secundario (`#E5E5E5`), etiqueta neutra |
| `border` | `#E5E7EB` | Borde de paneles (1 px) y de la barra inferior |
| `rule` | `#F0F0F0` | Separadores de fila (1 px) |
| `control` | `#D1D5DB` | Borde de campos y chips, pista del interruptor, escalón vacío |
| `text` | `#111111` | Texto principal |
| `muted` | `#5F6368` | Texto secundario (4.5:1 sobre blanco) |
| `placeholder` | `#6B6B6B` | Marcadores de ejemplo |
| `ink` | `#1D1F20` | Botón principal (relleno plano, texto blanco), chip activo, borde de campo enfocado, burbuja enviada, tooltips |
| `data` | `#0A66BF` | **Único color de marca en la interfaz: solo en los datos** (escalones llenos, enlaces). Es el azul del logo |
| `positive` | `#247B50` | Texto positivo. Etiqueta: fondo `#DCFAE5`, texto `#04250E` |
| `negative` | `#C4242A` | "Falta", contadores no leídos, borde de error. Etiqueta/Aviso: fondo `#FFEDEA`, texto `#831C1E` |
| `warning` | texto `#92400E` | Etiqueta y aviso contextual: fondo `#FFFBEB`, borde `#FDE68A` |
| Tinte de persona | `#DDEFE6`, `#F5E8D3`, `#DCE7F5`, `#F3DDE4` | Fondo pálido del avatar de cada persona (identidad, nunca datos) |

Prohibido: degradados (salvo los del logo), resplandores, desenfoque de fondo, sombras en reposo, iconos dentro de cuadrados de color, violeta o índigo, más de un matiz de marca.
Umbrales de match: no hay colores por umbral. El match se muestra con cifra en tinta y **pasos** en `data`.

### Fondo
`ground` plano más líneas finas y orgánicas decorativas (trazo `#0A66BF` al 14 % de opacidad, 1.2 px; ver sección 8). Las líneas van detrás del contenido, no reciben toques y nunca bajan el contraste del texto.

### Tipografía
**Familia de texto: Bricolage Grotesque** (`google_fonts`, variable, tamaño óptico automático), solo pesos **400, 500 y 600**.
**Segunda familia con un único trabajo: Geist Mono** (400) para **todas las cifras** (porcentajes, contadores, importes), con cifras tabulares (`FontFeature.tabularFigures()`). Decisión de estilo: las cifras se leen como columnas de un libro de cuentas.
| Estilo | Fuente | Tamaño | Peso | Interlineado |
|---|---|---|---|---|
| `display` (match en Detalle) | Mono | 2.07rem (33 px) | 400 | 1.1 |
| `h1` título de pantalla | Bricolage | 1.44rem (23 px) | 600 | 1.2 |
| `kpi` | Mono | 1.44rem (23 px) | 400 | 1.2 |
| `h2` título de fila o sección | Bricolage | 16 px | 600 | 1.25 |
| `body` | Bricolage | 14 px (16 px en campos de texto) | 400/500 | 1.5 |
| `meta` | Bricolage | 12 px | 400/500 | 1.4 |
| `numInline` (porcentajes en filas) | Mono | 14 px | 400 | 1.5 |
Letter-spacing normal (solo −0.015em en el wordmark del splash). El 700 no se usa. Nada por debajo de 12 px.

### Espaciado, radios, elevación y estados táctiles
- Rejilla de 8 px (4 px en microespacios). Márgenes laterales 16, relleno de panel 16, hueco entre bloques 16, entre elementos de un grupo 8.
- Radios (par ajustado): panel 8, control y botón 6, etiqueta 4, avatar y contadores redondos. Anidados bajan, nunca suben.
- Elevación: **solo borde de 1 px** o cambio de tono, nunca los dos. Sombra únicamente en lo que flota: el compositor del chat (`0 2 8 rgba(0,0,0,.06)`) y los tooltips.
- Áreas táctiles mínimas: 44 px (botones y campos 48).
- **Estados de interacción (sin efecto *ripple* de Material):** desactiva `splashFactory` (`NoSplash.splashFactory`).
  - `ListRow`, celdas interactivas de `KpiGrid` e `IconButton`: al presionar o pasar el ratón, el fondo cambia de `surface` (`#FFFFFF`) a `active` (`#EEEEEE`).
  - `AppTextField`: borde en reposo `control` (`#D1D5DB`), enfocado `ink` (`#1D1F20`, 1 px), con error `negative` (`#C4242A`, 1 px).
  - `PrimaryButton`: al presionar o mientras carga una petición, opacidad `0.88` con indicador lineal o spinner monocromo blanco de 16 px a la izquierda del verbo.

## 3. Componentes reutilizables (crear primero)

### 3.1 El elemento propio: `Steps` (pasos)
Inspirado en la flecha del 1 del logo y en "un solo paso". Una escalera de barras ascendentes de 4 px de ancho, 2 px de hueco, radio 1, alturas de 4 a 16 px (`[4, 7, 10, 13, 16]` en 5 barras; `[6, 11, 16]` en 3 barras).
- **Match:** 5 pasos; llenos = `ceil(match / 20)`. 94 % → 5, 68 % → 4, 54 % → 3, 30 % → 2, 15 % → 1, 0 % → 0. Llenos en `data`, vacíos en `control`.
- **Nivel de habilidad:** 3 pasos (Básico 1, Intermedio 2, Avanzado 3).
- **Cupo diario del autopiloto:** 5 pasos (3 llenos = 3 de 5 hoy).
- **Completado de perfil:** 5 pasos (5 llenos = 100 %).
Siempre va acompañado de la cifra o el texto: nunca es lo único que transmite el dato.

### 3.2 Resto
1. **`AppBackground`**: `ground` más las líneas decorativas de la sección 8.
2. **`Panel`**: fondo `surface`, borde `border` 1 px, radio 8. Lista de filas dentro de **un solo panel** con separadores `rule` (no una tarjeta por oferta).
3. **`ListRow`**: relleno 16, texto a la izquierda (`h2` + 1 o 2 líneas `muted`), a la derecha cifra mono y `Steps`, y un chevron de 16 px como indicio de que se puede tocar.
4. **`KpiGrid`**: un contenedor dividido por líneas `rule` de 1 px, 2×2 en móvil. Etiqueta `meta` sobre valor `kpi`. Cuando una celda navega a una vista de detalle (ej. "Candidaturas 12" → `Mis candidaturas`), incluye un chevron de 16 px arriba a la derecha y estado presionado `active`. Sin iconos decorativos, sin deltas, sin minigráficos.
5. **`StatusTag`**: 12/500, relleno 2×8, radio 4, par pálido (neutra, éxito, aviso, error). Solo dentro de filas o cabeceras de estado. Una sola marca de estado por fila.
6. **`InlineNotice`**: bloque de aviso contextual a nivel de pantalla (radio 8, relleno 12×16, borde de 1 px). Variantes: `warning` (fondo `#FFFBEB`, borde `#FDE68A`, texto `#92400E`), `negative` (fondo `#FFEDEA`, borde `#F5C2C0`, texto `#831C1E`) y `positive` (fondo `#DCFAE5`, borde `#A7F3D0`, texto `#04250E`). Se usa para los estados `402` y `409` del autopiloto, el aviso de rol Reclutador en Registro y confirmaciones de guardado.
7. **`FilterChip`**: alto 44, radio 6, borde `control`; activo: fondo `ink`, texto blanco. Incluye recuento en `Geist Mono` cuando aporta (`Todas 12`).
8. **`PrimaryButton`**: relleno plano `ink`, texto blanco 14/600, alto 48, radio 6. **`SecondaryButton`**: `#E5E5E5`, texto `text`. Botón de Google: `SecondaryButton` con el logo multicolor oficial.
9. **`AppTextField`**: etiqueta visible encima (14/500) enlazada al campo, campo de 48 px, radio 6, borde `control`, texto 16. El marcador solo muestra un ejemplo de formato (`nombre@correo.com`), nunca el nombre del campo. Sin iconos decorativos dentro. La búsqueda puede llevar lupa.
10. **`IconButton`**: 44×44 cuadrado, borde `border`, radio 6, etiqueta accesible y **tooltip real** (al pasar el ratón y con foco) con el mismo texto verbal ("Ver notificaciones", "Editar mi perfil", "Volver a ofertas", "Enviar mensaje").
11. **`NotificationBell`** (solo en Inicio): `IconButton` con campana de 20 px y contador `negative` (círculo de 20 px, texto 12/600 en `Geist Mono`, borde de 2 px del color `ground`). Distinto del contador de la pestaña Chat.
12. **`BottomNav`**: 5 pestañas (Inicio, Ofertas, Autopiloto, Chat, Mi CV), fondo `surface`, borde superior `border`, sin sombra ni desenfoque. Icono de 20 px en trazo de 1.5 y etiqueta 12/500. Activa: texto 600 y píldora neutra `active` de 48×28 tras el icono. Contador de no leídos sobre Chat.
13. **`Switch`**: 40×24, pista `control`, activa `ink`, mando blanco; la transición dura 150 ms y se desactiva con movimiento reducido. **`Slider`**: nativo con color `ink`, etiqueta visible y valor en `Geist Mono` a la derecha.
14. **`ChatBubble`**: ancho máximo 80 %, relleno 12, radio 8. Recibido: `surface` con borde `border`. Enviado: `ink` con texto blanco. **`Composer`**: panel flotante con la única sombra permitida (`0 2 8 rgba(0,0,0,.06)`); lleva una etiqueta visible ("Mensaje para Lucía").
15. **`Avatar`**: círculo de 40 px (48 px en cabecera de Mi perfil) con el tinte pálido de la persona e iniciales en `text`. **`UnreadBadge`**: círculo de 20 px `negative`, texto blanco 12/600; el nombre de una conversación sin leer va en 600.

Iconos: un solo juego, trazo de 1.5 px, 16 a 20 px, color `text` o `muted`. Nunca en cuadrados de color. Logo de Google: SVG multicolor oficial.

## 4. Navegación
- Antes de entrar: **Splash** → **Login** ⇄ **Registro**. Tras autenticarse: **Inicio**.
- Barra inferior (5 pestañas, `go_router` con `StatefulShellRoute`): **Inicio, Ofertas, Autopiloto, Chat, Mi CV**.
- **Pantallas que se apilan, sin barra inferior y con flecha atrás (`IconButton`):**
  - **Detalle y match** (desde Ofertas, Inicio, Mis candidaturas, Autopiloto o Conversación).
  - **Mis candidaturas** (desde las celdas de Candidaturas/Entrevista del `KpiGrid` en Inicio o tras postular).
  - **Conversación** (desde Mensajes o desde "Escribir al reclutador" en Detalle).
  - **Centro de notificaciones** (desde `NotificationBell` en Inicio).
  - **Mi perfil** (desde el avatar de usuario en la cabecera de Inicio o desde el enlace "Editar mi perfil" en Mi CV).
- Volver devuelve a la lista anterior en la misma posición de scroll.

## 5. Pantallas y datos (API en `http://localhost:3000/api`, token `Bearer`)
Cada pantalla responde a **una pregunta** y la muestra primero.
| Pantalla (patrón) | Pregunta | Contenido | Endpoints |
|---|---|---|---|
| **Login** (Formulario) | — | Logo, título, correo, contraseña, "Entrar en mi cuenta", "Entrar con Google", enlace a "Crear cuenta nueva" | `POST /auth/login`, `POST /auth/login/google` |
| **Registro** (Formulario) | — | Selector Candidato/a · Reclutador/a, nombre completo, correo, contraseña, "Crear cuenta", "Registrarme con Google" | `POST /auth/register` |
| **Inicio** (Resumen) | ¿Qué pasó hoy y qué toca ahora? | Marca, avatar a Mi perfil y campana; título "Hoy"; frase con lo más importante; `KpiGrid` con 4 cifras interactivas; 2 mejores matches con enlace "Ver todas las ofertas" | `GET /postulaciones/mias`, `GET /preferencias-autopilot`, `GET /ofertas`, `GET /mensajes/sin-leer` |
| **Ofertas** (Lista) | ¿Qué oferta encaja mejor? | Búsqueda con etiqueta, chips de modalidad, un panel con filas ordenadas por match | `GET /ofertas` |
| **Detalle y match** (Detalle) | ¿Merece la pena postularme? | Match grande con pasos, el hallazgo ("Con Docker pasarías de 68 % a 85 %"), obligatorias y deseables, lista de requisitos (Cubierto / Falta), "Postular con mi CV" y "Escribir al reclutador" | `GET /ofertas/:id`, `POST /postulaciones/simular-match`, `POST /postulaciones`, `POST /conversaciones` |
| **Mis candidaturas** (Lista) | ¿Dónde espero respuesta? | Frase resumen, chips (Todas 12, Manuales 7, Por IA 5), filas con estado, origen y CV usado | `GET /postulaciones/mias` |
| **Autopiloto** (Ajustes) | ¿Qué postula por mí hoy y puedo pararlo? | Plan, frase del día, avisos `InlineNotice` (`402`/`409` si aplican), interruptor con consentimiento, CV, puntuación mínima, máximo diario, panel "Hoy" con pasos y últimas postuladas, "Ejecutar autopiloto ahora" | `GET`/`PATCH /preferencias-autopilot`, `POST /postulaciones-autopilot/ejecutar` |
| **Mi CV** (Ajustes) | ¿Qué ve el autopiloto en mi CV? | Enlace a "Editar mi perfil", CV principal, "Subir PDF nuevo" (máx. 5 MB), habilidades con nivel en pasos, enlace "Ver las 14", "Añadir habilidad" | `POST`/`GET /cv`, `GET /habilidades`, `GET`/`POST`/`PATCH`/`DELETE /habilidades/cv/:cvId...` |
| **Mensajes** (Bandeja) | ¿Quién espera mi respuesta? | Búsqueda con etiqueta, filas de dos a tres líneas: nombre y hora, último mensaje, oferta asociada (o "Sin oferta asociada") y contador | `GET /conversaciones`, `GET /mensajes/sin-leer` |
| **Conversación** (Detalle) | — | Reclutador, oferta con su match, burbujas, "Leído", compositor flotante | `GET`/`POST /conversaciones/:id/mensajes` |
| **Notificaciones** (Lista) | ¿Qué novedades requieren mi atención? | Contador de no leídas, enlace "Marcar todas como leídas", filas con evento, oferta, fecha y etiqueta (`Nueva` / `Leída`), estados vacío y error con "Reintentar carga" | Pendiente de contrato (ver sección 9) |
| **Mi perfil** (Ajustes) | ¿Cómo me ven las empresas y qué busco? | Avatar e identidad con `Steps` de completado (100 %), ubicación, chips de modalidad e incorporación, expectativa salarial en `Geist Mono`, estado de suscripción (5 €/mes), interruptores de avisos push FCM y movimiento reducido, "Guardar cambios de perfil" y "Cerrar sesión en este dispositivo" | `GET`/`PATCH /usuarios/me` (o repositorio de perfil local hasta cierre de endpoint) |

Reglas de negocio visibles en la UI:
- `matchScore = (% obligatorias cubiertas × 0,7) + (% deseables cubiertas × 0,3)`. Se calcula en el servidor: la app solo lo muestra, no lo recalcula (el hallazgo "con Docker pasarías a 85 %" también debe venir del servidor o de `simular-match`).
- El autopiloto **nunca se activa solo**: requiere consentimiento explícito. Sin suscripción activa la API responde `402`, y sin CV asignado o desactivado, `409`. Muestra esos casos con un `InlineNotice` claro, no con un error genérico.
- Planes: mensual 5 €, anual 50 €. El precio lo fija siempre el servidor.
- Login: máximo 10 intentos cada 15 minutos por IP. El `accessToken` dura 15 min y el `refreshToken` 7 días: implementa renovación.
- Los valores exactos de `EstadoPostulacion` están en `prisma/schema.prisma`. Revísalos antes de mapear los textos de las etiquetas.

Formularios (Login, Registro y Mi perfil): el botón de envío nunca está desactivado; si faltan datos, muestra el error junto al campo. No marques un campo como inválido mientras se escribe en él por primera vez: valida al salir del campo y limpia el error al volver a enfocarlo. Usa `autofillHints` (correo, contraseña actual o nueva, nombre).

Texto de la interfaz: frases en español con mayúscula inicial solo en la primera palabra. Todo botón y enlace de acción empieza por un verbo en infinitivo ("Postular con mi CV", "Entrar con Google", "Guardar cambios de perfil"). No uses "Continuar", "Aceptar" ni "Enviar" sin objeto.

## 6. Reglas para la IA
1. Copia el diseño exacto. No añadas, quites ni "mejores" elementos.
2. Ningún color, tamaño ni radio suelto: todo sale de `ThemeData` o de las constantes de tema.
3. Componentes primero, pantallas después, y las pantallas solo se componen con ellos.
4. Datos mock en una capa de repositorios; la UI no conoce la API directamente.
5. Una pantalla por iteración; compara con su PNG/HTML y lista las diferencias antes de seguir.
6. Responsive sin overflow, con scroll donde el contenido pueda crecer.
7. Accesibilidad: etiqueta visible en cada campo, tooltip y etiqueta accesible en cada botón de icono, áreas táctiles ≥ 44 px, contraste ≥ 4.5:1 en todo texto.
8. Ni degradados, ni sombras en reposo, ni desenfoques. Si algo pide esos efectos, pregunta.
9. Si el diseño es ambiguo o contradictorio, pregunta.

## 7. Fuera de alcance (aún sin diseñar)
- Pantallas de reclutador: crear empresa, publicar oferta, ranking de postulaciones.
- Pasarela de pago de suscripción (el estado activo/inactivo y el precio de 5 €/mes sí se muestran en Autopiloto y Mi perfil, pero sin checkout bancario).
- Contrato de persistencia/API para notificaciones: no hay endpoint de notificaciones definido. La campana y los flujos se especifican en la sección 9; no reutilizar `GET /mensajes/sin-leer` como contador de notificaciones ni inventar rutas.
- Ilustraciones en estados vacíos: un estado vacío debe mantener únicamente el marco del `Panel` y una frase descriptiva, sin dibujos ni iconos grandes.

## 8. Fondo y movimiento (`Autonomous Ops`)
- Todas las pantallas llevan `ground` (`#F2F4F7`) con las líneas finas y orgánicas (`#0A66BF` al 14 % de opacidad, grosor 1.2 px). El fondo no puede ser blanco plano ni quedar limitado a Login y Registro: también aparece en las pantallas autenticadas del candidato.
- `AppBackground` es el único componente responsable del fondo y las líneas. Tarjetas, textos, campos, botones y navegación quedan por encima y conservan contraste y áreas táctiles. No uses desenfoque (`BackdropFilter`).
- **Coreografía oficial de datos (`Autonomous Ops`):** inspirada en el patrón *Autonomous Ops* de MotionSites.ai y adaptada estrictamente a `achromatic-ledger`:
  1. **Barrido técnico horizontal de bloques y filas:** al entrar en una pantalla, los bloques principales y las filas (`ListRow`) entran con un desplazamiento horizontal corto de `-8 px` a `0 px` y opacidad `0 → 1` en `150–160 ms` con curva `Cubic(0.16, 1, 0.3, 1)`, escalonando cada elemento entre `25 ms` y `30 ms` para transmitir velocidad de autopiloto sin bloquear el toque.
  2. **Subida cuantizada de `Steps`:** los escalones llenos (`#0A66BF`) crecen verticalmente desde su base (`scaleY` de `0.15` a `1.0`) en `180 ms` usando una curva escalonada discreta de 4 pasos (`StepTween` / `steps(4, end)`), reforzando la estética de instrumento de medición contable.
  3. **Pulso sutil de estado activo:** las etiquetas positivas (`tag-positive`, como "En entrevista", "CV principal activo" o "Activa") modulan únicamente su opacidad (`1.0 → 0.55 → 1.0` cada `2,8 s`) sin usar sombras ni resplandores exteriores.
  4. **Deriva de fondo y Movimiento reducido:** las curvas de `AppBackground` pueden desplazarse con `Transform.translate` muy lento (`22 s` por ciclo). Si `MediaQuery.disableAnimationsOf(context)` está activo o el usuario activa el interruptor **"Reducir movimiento en la interfaz"** en **Mi perfil**, todas las duraciones pasan a `0 ms` y el fondo queda completamente estático.
- **Splash:** el logo transparente (sin lienzo blanco ni marca de agua) se reproduce **una sola vez**: la J entra desde la izquierda, la flecha del 1 crece desde abajo con un retraso de 150 ms, la S entra desde la derecha con 300 ms y aparece el wordmark con 600 ms. Cada pieza dura 300 ms con salida suave (`Curves.easeOut`) y sin rebote. Después continúa a Login o a la ruta inicial. Con movimiento reducido, se muestra el logo sin animar.

## 9. Sistema de notificaciones
- **Eventos requeridos:** cuando un candidato se postula a una oferta, avisar al reclutador propietario de la oferta; cuando el reclutador marca a un candidato para entrevista, avisar al candidato. El cuerpo identifica el evento y la oferta, sin incluir el CV ni otros datos sensibles.
- **Campana e historial:** tocar la campana abre la pantalla apilada **Notificaciones** con elementos nuevos (`Nueva` en `tag-negative`) y leídos (`Leída` en `tag-neutral`), texto del evento, oferta relacionada y fecha en `Geist Mono`. El contador de la campana representa notificaciones no leídas (4); el de la pestaña Chat, mensajes no leídos (3), y se alimenta por separado.
- **Navegación:** al tocar una notificación, abrir la candidatura u oferta correspondiente según el rol. Si el usuario no ha iniciado sesión, conservar el destino y continuar tras el login. Marcar como leída al abrirla y actualizar el contador.
- **Firebase Cloud Messaging (FCM):** úsalo para entregar avisos push y gestionar la recepción con la app en primer plano, segundo plano y cerrada; al tocar el aviso, navegar al destino. Registra y refresca el token del dispositivo para la cuenta autenticada y permite gestionar el permiso desde **Mi perfil** ("Avisos push de entrevistas (FCM)") o con una explicación contextual, nunca al arrancar en frío. El envío lo hace un entorno de confianza (API existente o Cloud Functions con Firebase Admin SDK); nunca incluyas credenciales de servidor en Flutter. Guías oficiales: [recepción de FCM](https://firebase.google.com/docs/cloud-messaging/receive-messages) y [entorno de servidor](https://firebase.google.com/docs/cloud-messaging/server-environment).
- **Fuente de verdad pendiente:** FCM transporta mensajes, pero este diseño no define dónde se guardan el historial, el estado leído/no leído ni el contador persistente. Elige el origen (API existente o almacenamiento seguro en Firebase) y su contrato antes de implementar. No sustituyas esos datos con mocks en producción ni los infieras de mensajes.
- **Estados de UI:** incluye estado de carga, lista vacía (un `Panel` con el texto *"No tienes notificaciones pendientes. Te avisaremos cuando haya cambios en tus candidaturas."*, sin ilustración), error con botón `SecondaryButton` ("Reintentar carga") y notificación ya leída, con el mismo fondo, espaciado y componentes del resto de la app.

## 10. Datos de ejemplo que deben cuadrar
- **Perfil de candidata:** Marina Serrano (`marina.serrano@correo.es`), Madrid, España · Modalidad: Remoto o Híbrido · Incorporación inmediata · Expectativa: `28.000 €` brutos/año · Completado: `100 %` (5/5 pasos) · Plan activo: `5 €/mes`.
- **Candidaturas:** 12 candidaturas = 7 manuales + 5 por IA. 1 en entrevista (Vértice, 94 %). 6 pendientes de revisión.
- **Mensajes sin leer:** 3 = 2 (Lucía Marín · Vértice Digital) + 1 (Marcos Vidal · Krono Labs). Es el contador de la pestaña Chat y la cifra de Inicio.
- **Notificaciones sin leer:** 4 (contador de la campana en Inicio).
- **Autopiloto hoy:** 3 de 5 (React Junior 94 %, Angular Junior 81 %, Node.js Junior 76 %), mínimo 70 %.
- **Matches (obligatorias 70 % + deseables 30 %):** React Junior 94 (5/5 y 4/5), Full Stack .NET 68 (3/4 y 1/2; con Docker sube a 85), Backend Java 54 (3/5 y 2/5), QA Automation 30 (3/7 y 0/3).
- **Habilidades en Mi CV:** 14 detectadas en `CV_Marina_Serrano_2026.pdf` (1,4 MB).
- **Escalones:** `ceil(match / 20)`.