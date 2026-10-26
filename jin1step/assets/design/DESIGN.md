# DESIGN.md — Interfaz de JIn1Step (Flutter)

Documento para la IA que implementa la UI. Complementa a `/design/screens/*.dc.html` (valores exactos) y `/design/png/*.png` (referencia visual).
**Orden de prioridad si hay conflicto:** HTML de la pantalla > este documento > PNG. Si algo no está definido, pregunta: no lo inventes.

## 1. Producto
JIn1Step: plataforma de empleo con autopiloto de postulaciones. Lema: "Buscar trabajo en un solo paso".
Roles de la API: `CANDIDATO`, `RECLUTADOR`, `ADMIN`. **Solo está diseñada la experiencia del candidato.** Las pantallas de reclutador no existen todavía: no las inventes.
Backend en `/jin1step.server` (Express + Prisma). No se modifica. Los datos del diseño son de ejemplo ("Empresa demo", nombres ficticios).

## 2. Tokens

### Colores
| Token | Valor | Uso |
|---|---|---|
| `bgGradient` | 180°: `#E9E4FA` 0% → `#F6F4FD` 38% → `#FFFFFF` 100% | Fondo de todas las pantallas |
| `ink` | `#1B1830` | Texto principal |
| `muted` | `#5E5A73` | Texto secundario (13 px) |
| `primary` | `#5B3FD0` | Botones, chips activos |
| `primaryLight` | `#7A5CF0` | Final de degradados |
| `primaryDark` | `#4A2FB8` | Texto de acento, porcentajes, pestaña activa |
| `primaryTint` | `#ECE8FB` | Fondo de la pestaña activa y de la etiqueta de oferta |
| `cardBorder` | `#E6E2F5` | Borde de tarjetas y de la barra inferior |
| `fieldBorder` | `#D8D3EE` | Borde de campos, chips y píldoras |
| `iconTile` | fondo `#F0EEF8`, icono `#4A4668` | Recuadro de icono de 40×40 |
| `pillText` | `#3B3758` | Texto de las píldoras |
| `barTrack` | `#E8E4F6` | Fondo de barras de progreso |
| `badge` | `#C2255C` (texto blanco) | Contador de no leídos |
| `matchHigh` | `#0F7A4F` | Match alto |
| `matchMid` | `#8A5A00` | Match medio |
| `matchLow` | `#6B6784` | Match bajo |
| Estado éxito | fondo `#E3F4EC`, borde `#BFE3D2`, texto `#0F7A4F` | |
| Estado aviso | fondo `#FCEFD2`, borde `#F0DBA5`, texto `#7A4E00` | |
| Estado error | fondo `#FBE3E0`, borde `#F3C4BF`, texto `#8F2620` | |

Degradados:
- `primaryGradient`: 135°, `#5B3FD0` → `#7A5CF0` (botón primario, avatares, burbujas propias).
- `heroGradient`: 135°, `#4A2FB8` → `#7A5CF0` (bloques destacados).
- `barFill`: 90°, `#5B3FD0` → `#7A5CF0`.

Umbrales de color del match (decisión de diseño, confirmar): `>= 80` verde, `60–79` ámbar, `< 60` gris.

> Nota de marca: el logo es azul/cian/azul marino (`#0A66BF`, `#083F7E`, `#00B4E0`, `#0B6FD0`, `#1D406E`, `#101E38`), pero la interfaz usa violeta. Si se migra la UI al azul, solo cambia este bloque de tokens.

### Tipografía
Familia: **Plus Jakarta Sans** (`google_fonts`), pesos 400, 600, 800.
| Estilo | Tamaño | Peso | Extra |
|---|---|---|---|
| `h1` | 24 (26 en Login y Registro) | 800 | letterSpacing −0.4 a −0.5 |
| `h2` (título de tarjeta) | 15 | 800 | height 1.3 |
| `body` | 14 | 400/600 | |
| `muted` | 13 | 400 | color `muted` |
| `pill` | 12 | 600 | |
| `chip` | 13 | 600 | |
| `button` | 15 | 800 | |
| `percent` | 15 | 800 | color según match |
| `navLabel` | 11 | 600 (800 si activa) | |
| `statNumber` | 24 | 800 | color `primaryDark` |

### Espaciado, radios y sombras
- Pantalla: 390×844 de base. Padding lateral 18 (24 en Login/Registro), superior 22. Separación vertical entre bloques: 12 (14 en auth).
- Radios: tarjeta 20 (22 en auth), hero 22, botón 16, campo 14, campo de búsqueda 16, icono 12, píldora/chip 99 (totalmente redondeado), barra 9, burbuja 18 (esquina del emisor 6), campo del chat 24.
- Sombra de tarjeta: `0 3 12 rgba(70,50,160,.08)`.
- Sombra de botón primario: `0 6 16 rgba(91,63,208,.28)`.
- Sombra de barra inferior: `0 -4 14 rgba(70,50,160,.06)`.
- Áreas táctiles mínimas: 44 px (botones 50, campos 48).

## 3. Componentes reutilizables (crear primero)
1. **`AppBackground`**: envuelve la pantalla con `bgGradient`.
2. **`JCard`**: fondo blanco, borde `cardBorder` 1 px, radio 20, padding 14, gap 10, sombra de tarjeta.
3. **`IconTile`**: 40×40, radio 12, fondo `iconTile`, icono SVG 18 px trazo 1.8.
4. **`StatusPill`**: píldora con borde `fieldBorder`, radio 99, padding 6×12, texto 12/600, icono opcional de 18 px. Variantes: neutra, éxito, aviso, error.
5. **`MatchBadge`**: texto `NN%` en 15/800, color según umbral.
6. **`FilterChip`**: radio 99, borde `fieldBorder`, padding 8×14, alto mínimo 44. Activo: fondo `primary`, texto blanco.
7. **`PrimaryButton`**: `primaryGradient`, radio 16, alto 50, texto blanco 15/800, sombra de botón.
8. **`SecondaryButton`**: fondo blanco. En pantallas internas: borde 1.5 `primary` y texto `primaryDark`. En Login/Registro (botón de Google): borde 1 `fieldBorder` y texto `ink`.
9. **`AppTextField`**: alto 48, radio 14, borde `fieldBorder`, texto 14/600, etiqueta superior 13/600.
10. **`ProgressBar`**: alto 8, pista `barTrack`, relleno `barFill`. Sobre `heroGradient`: pista blanca al 28 % y relleno blanco.
11. **`HeroCard`**: `heroGradient`, radio 22, padding 18, texto blanco.
12. **`OfferCard`**: `JCard` con `IconTile` + título (`h2`) + empresa·modalidad (`muted`) + `MatchBadge` a la derecha, y debajo `StatusPill`s.
13. **`BottomNav`**: 5 pestañas, fondo blanco, borde superior `cardBorder`, padding 8/6/16, icono 22 px (trazo 1.9) y etiqueta debajo. Pestaña activa: píldora 52×30 `primaryTint` tras el icono y texto `primaryDark` en negrita. Insignia de no leídos sobre el icono de Chat (círculo 17 px `badge`, borde blanco 2, texto 10.5/800).
14. **`ChatBubble`**: ancho máximo 78 %, padding 10×14, radio 18. Recibido: blanco con borde `cardBorder`, alineado a la izquierda, esquina inferior izquierda 6. Enviado: `primaryGradient`, texto blanco, alineado a la derecha, esquina inferior derecha 6.
15. **`Avatar`**: círculo 46 px con `primaryGradient` e inicial en blanco 17/800 (40 px en la cabecera del chat).
16. **`UnreadBadge`**: círculo 22 px, `badge`, texto blanco 12/800.
17. **`OfferTag`**: píldora `primaryTint`, texto `primaryDark` 11.5/600, padding 3×10 (por ejemplo "Sobre: Full Stack .NET + React").

Iconos (SVG, trazo, 24×24, esquinas redondeadas): inicio, maletín, rayo, burbuja de chat, persona, flecha atrás, portapapeles con check, documento, bandera, enviar. Logo de Google: SVG multicolor oficial en el botón de Google.

## 4. Navegación
- Antes de entrar: **Login** ⇄ **Registro**. Tras autenticarse: **Inicio**.
- Barra inferior (5 pestañas, `go_router` con `StatefulShellRoute`): **Inicio, Ofertas, Autopiloto, Chat, Mi CV**.
- Sin barra inferior (pantallas secundarias con flecha atrás): **Detalle y match** (desde una oferta), **Mis candidaturas** (desde Inicio) y **Conversación** (desde Mensajes). En el diseño, Detalle muestra la barra con Ofertas activa; tómalo como referencia visual, pero decide con el equipo si debe ocultarse.
- Logo animado: pantalla de arranque (splash), 5 s en bucle en el diseño; en la app, una sola pasada y entrar.

## 5. Pantallas y datos (API en `http://localhost:3000/api`, token `Bearer`)
| Pantalla | Contenido | Endpoints |
|---|---|---|
| **Login** | Logo, "Bienvenido de nuevo", correo, contraseña, Entrar, Continuar con Google, enlace a Crear cuenta | `POST /auth/login`, `POST /auth/login/google` |
| **Registro** | Selector Candidato/a · Reclutador/a, nombre, correo, contraseña, Crear cuenta, Registrarme con Google | `POST /auth/register` |
| **Inicio** | Saludo, bloque de autopiloto (estado, mínimo, progreso del día), 3 cifras (candidaturas, entrevistas, match medio), 2 mejores matches, actividad reciente | `GET /postulaciones/mias`, `GET /preferencias-autopilot`, `GET /ofertas`, `GET /mensajes/sin-leer` |
| **Ofertas** | Título, búsqueda, chips (Todas, Remoto, Híbrido, Presencial), lista de `OfferCard` con requisitos cubiertos o faltantes | `GET /ofertas` |
| **Detalle y match** | Porcentaje grande en `HeroCard`, barras de obligatorias (70 %) y deseables (30 %), requisitos cubiertos y faltantes, botones Postularme y Escribir al reclutador | `GET /ofertas/:id`, `POST /postulaciones/simular-match`, `POST /postulaciones`, `POST /conversaciones` |
| **Mis candidaturas** | Filtros (Todas, Manuales, Por IA), tarjetas con estado, origen (manual o IA) y CV usado | `GET /postulaciones/mias` |
| **Autopiloto** | Estado de suscripción, interruptor con consentimiento, CV usado, puntuación mínima (70 por defecto), máximo diario (5 por defecto), contador de hoy, últimas enviadas por IA, botón Ejecutar ahora | `GET`/`PATCH /preferencias-autopilot`, `POST /postulaciones-autopilot/ejecutar` |
| **Mi CV** | CV principal, subida de PDF (máx. 5 MB), habilidades detectadas con nivel (Básico, Intermedio, Avanzado), añadir habilidad | `POST`/`GET /cv`, `GET /habilidades`, `GET`/`POST`/`PATCH`/`DELETE /habilidades/cv/:cvId...` |
| **Mensajes** | Bandeja con avatar, nombre, empresa, oferta asociada (opcional), último mensaje, hora y contador de no leídos | `GET /conversaciones`, `GET /mensajes/sin-leer` |
| **Conversación** | Cabecera con reclutador, tarjeta de la oferta con su match, burbujas, "Leído", campo de escritura y botón de enviar | `GET`/`POST /conversaciones/:id/mensajes` |

Reglas de negocio visibles en la UI:
- `matchScore = (% obligatorias cubiertas × 0,7) + (% deseables cubiertas × 0,3)`. Se calcula en el servidor: la app solo lo muestra, no lo recalcula.
- El autopiloto **nunca se activa solo**: requiere consentimiento explícito. Sin suscripción activa la API responde `402`, y sin CV asignado o desactivado, `409`. Muestra esos casos con un mensaje claro, no con un error genérico.
- Planes: mensual 5 €, anual 50 €. El precio lo fija siempre el servidor.
- Login: máximo 10 intentos cada 15 minutos por IP (limitación del servidor). El `accessToken` dura 15 min y el `refreshToken` 7 días: implementa renovación.
- Los valores exactos de `EstadoPostulacion` (por ejemplo "Pendiente de revisión", "Entrevista", "Rechazada") están en `prisma/schema.prisma`. Revísalos antes de mapear los textos de las píldoras.

## 6. Reglas para la IA
1. Copia el diseño exacto. No añadas, quites ni "mejores" elementos.
2. Ningún color, tamaño ni radio suelto: todo sale de `ThemeData` o de las constantes de tema.
3. Componentes primero, pantallas después, y las pantallas solo se componen con ellos.
4. Datos mock en una capa de repositorios; la UI no conoce la API directamente.
5. Una pantalla por iteración; compara con su PNG y lista las diferencias antes de seguir.
6. Responsive sin overflow en pantallas pequeñas, con scroll donde el contenido pueda crecer.
7. Semántica y accesibilidad: etiquetas en iconos sin texto, contraste del diseño intacto, áreas táctiles ≥ 44 px.
8. Si el diseño es ambiguo o contradictorio, pregunta.

## 7. Fuera de alcance (aún sin diseñar)
- Pantallas de reclutador: crear empresa, publicar oferta, ranking de postulaciones.
- Suscripción y pago (modelado en base de datos, sin pasarela).
- Edición del perfil de candidato (ubicación, disponibilidad) y ajustes.
- Estados vacíos, de carga y de error (salvo los mensajes de `402` y `409` del autopiloto).
