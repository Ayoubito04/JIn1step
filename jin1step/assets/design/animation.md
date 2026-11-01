# ANIMATIONS.md — Movimiento de JIn1Step (Flutter)

Criterio: la filosofía de animación de Emil Kowalski (skill `animate`), con las curvas y duraciones de sus tablas, traducidas a Flutter. Complementa a `DESIGN.md`: allí manda el diseño, aquí el movimiento. En las pantallas HTML de referencia puedes ver cada animación funcionando.

## 1. Reglas
1. Primero se decide **si** se anima. Lo que se usa decenas de veces al día lleva movimiento casi imperceptible o ninguno.
2. Cada animación tiene un propósito: **feedback**, **estado**, **continuidad espacial** o **explicación**. Si no se puede nombrar, no se hace.
3. Solo `transform` (escala, traslación) y opacidad. Nunca animes ancho, alto, márgenes ni posición.
4. Nunca `scale` desde 0: se parte de 0.97 con opacidad 0. Nunca curva `easeIn` en la interfaz. Nunca rebote (salvo gestos).
5. Ninguna animación de interfaz supera los 300 ms.
6. Movimiento reducido: menos y más suave, no cero. Se quitan los desplazamientos y escalas; se mantienen los fundidos de 150 ms.
7. Los valores salen de los tokens de abajo. No inventes curvas.

## 2. Tokens (Dart)
```dart
class Motion {
  static const easeOut = Cubic(0.23, 1, 0.32, 1);      // entradas, salidas, feedback
  static const easeInOut = Cubic(0.77, 0, 0.175, 1);   // movimiento en pantalla
  static const easeDrawer = Cubic(0.32, 0.72, 0, 1);   // paneles que se apilan

  static const press = Duration(milliseconds: 120);
  static const fast = Duration(milliseconds: 150);     // color, interruptor, tooltip
  static const base = Duration(milliseconds: 200);     // entradas, pasos, burbujas
  static const slow = Duration(milliseconds: 300);     // splash, transición de pantalla
  static const stagger = Duration(milliseconds: 40);   // escalonado entre pasos
}

// Movimiento reducido:
bool reduce(BuildContext c) => MediaQuery.of(c).disableAnimations;
```

## 3. Qué se anima y qué no
| Interacción | Frecuencia | Propósito | Cómo |
|---|---|---|---|
| Pulsar botón, chip o botón de icono | Alta | Feedback | Escala a 0.97, `Motion.press`, `easeOut` (`AnimatedScale`). Con movimiento reducido, sin escala |
| Cambio de color o fondo (chip activo, fila pulsada) | Alta | Estado | `Motion.fast`, curva `ease`; en filas, 100 ms |
| Interruptor del autopiloto | Media | Estado | Desliza el mando 16 px, `Motion.fast`, `easeOut` |
| Tooltip de botón de icono | Media | Explicación | Opacidad 0→1 y escala 0.97→1, `Motion.fast`, `easeOut`, origen en el botón |
| **Pasos del match (Detalle y cupo del Autopiloto)** | Ocasional | Explicación del elemento propio | Cada barra crece desde la base (escala vertical 0.25→1 y opacidad), `Motion.base`, `easeOut`, escalonado de 40 ms por barra. Solo en el glifo grande y en el cupo; **no** en las filas de las listas |
| Después de "Ejecutar autopiloto" | Rara | Estado | El siguiente paso del cupo se llena con la misma animación |
| Burbuja de chat nueva | Ocasional | Continuidad | Entra con traslación vertical de 8 px, escala 0.97→1 y opacidad, `Motion.base`, `easeOut`. Con movimiento reducido, solo fundido |
| Indicador de pestaña activa (barra inferior) | Alta | Continuidad espacial | La píldora se desliza al nuevo icono, `Motion.base`, `easeInOut`. El contenido de la pestaña **no** se anima |
| Pantallas que se apilan (Detalle, Mis candidaturas, Mi CV, Conversación) | Alta | Continuidad espacial | Transición nativa de la plataforma (Cupertino en iOS), con `easeDrawer` y `Motion.slow` como máximo |
| Splash | Rara (una vez por arranque) | Delight permitido | La J entra desde la izquierda (8 px) sin retraso, la flecha crece desde abajo (escala 0.6→1) a los 150 ms, la S entra desde la derecha a los 300 ms y el wordmark sube 8 px a los 600 ms. Cada pieza dura `Motion.slow`, `easeOut`, **una sola pasada**. Con movimiento reducido, el logo estático |

**No se anima:** el cambio de contenido al cambiar de pestaña, el desplazamiento de listas, los contadores (campana y Chat), las cifras, la aparición de las filas de las listas, el fondo de líneas (queda estático; ver `DESIGN.md`, sección 8) ni nada que se repita decenas de veces al día con más movimiento que un cambio de color.

## 4. Fragmentos útiles
```dart
// Pulsación (botón, chip, botón de icono)
AnimatedScale(
  scale: pressed && !reduce(context) ? 0.97 : 1,
  duration: Motion.press,
  curve: Motion.easeOut,
  child: child,
)

// Pasos que se llenan, con escalonado
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0, end: 1),
  duration: Motion.base,
  curve: Motion.easeOut,
  builder: (_, t, __) => Opacity(
    opacity: t,
    child: Transform.scale(scaleY: 0.25 + 0.75 * t, alignment: Alignment.bottomCenter, child: bar),
  ),
)
// Retraso de la barra i: Future.delayed(Motion.stagger * i) antes de iniciar.
```

## 5. Comprobar a mano
Antes de dar una animación por buena: reprodúcela a cámara lenta (2 a 5 veces la duración), pruébala en un móvil real y vuélvela a mirar al día siguiente. Los pasos escalonados y la burbuja nueva son los que más dependen de la sensación y no se pueden juzgar solo desde el código.