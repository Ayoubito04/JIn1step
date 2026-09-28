// Sistema de diseño de la app: Material Design 3, el lenguaje visual propio
// de Google (el mismo que usan Gmail, Drive o Google One). Nada de
// desenfoques ni degradados de fondo: M3 se apoya en SUPERFICIES TONALES
// (variaciones del mismo color en distinta intensidad) para dar profundidad
// sin sombras pesadas ni cristal.
//
// Todo lo visual vive aquí para no repetir colores sueltos por cada
// pantalla: si mañana cambia el azul de marca, se toca un archivo y cambia
// toda la app.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  /// Azul semilla: a partir de él, ColorScheme.fromSeed genera TODA la
  /// paleta tonal (primario, contenedores, superficies...) siguiendo el
  /// algoritmo de Material You. No hay que definir el resto de tonos a
  /// mano; los provee el propio Material 3.
  // Azul índigo vivo, más saturado que el azul plano anterior: es el tono
  // que se pidió al enseñar una referencia visual de una app de empleo.
  static const azul = Color(0xFF4F46E5);
}

/// El ThemeData de toda la app. Se usa en main.dart; ningún widget debería
/// escribir un color a mano si existe un equivalente en el colorScheme.
ThemeData construirTemaApp() {
  final esquemaColor = ColorScheme.fromSeed(
    seedColor: AppColors.azul,
    brightness: Brightness.light,
  );

  // Roboto es la tipografía de Google para Android y Material Design (es la
  // que usan Gmail, Drive, Maps...). google_fonts.dart es, literalmente, el
  // paquete de fuentes publicado por Google.
  final tipografia = GoogleFonts.robotoTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquemaColor,
    textTheme: tipografia,
    // El fondo de las pantallas es la superficie MÁS CLARA del esquema, no
    // blanco puro ni gris fijo: así cambia solo si cambia el azul semilla.
    scaffoldBackgroundColor: esquemaColor.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: esquemaColor.surface,
      foregroundColor: esquemaColor.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    // FilledButton y no ElevatedButton: en Material 3, el botón "relleno"
    // (fondo sólido, sin sombra) es el que Google usa para la acción
    // principal. ElevatedButton se reserva para casos con más énfasis de
    // elevación, que aquí no hace falta.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    // ElevatedButton se deja también configurado por si algún sitio lo usa,
    // para que no desentone si aparece sin querer.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      // surfaceContainerHighest: el tono que Material 3 reserva para
      // "superficie rellena dentro de una superficie", como los campos de
      // texto. Cambia solo si cambia el azul semilla, nunca un gris fijo.
      fillColor: esquemaColor.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: esquemaColor.primary, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      // Las tarjetas en M3 no se distinguen por sombra sino por un tono de
      // superficie ligeramente distinto al fondo.
      color: esquemaColor.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: esquemaColor.secondaryContainer,
      labelStyle: TextStyle(color: esquemaColor.onSecondaryContainer, fontWeight: FontWeight.w600),
      side: BorderSide.none,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: esquemaColor.surfaceContainer,
      elevation: 0,
      // La "píldora" que resalta el icono activo: es el patrón exacto que
      // usan Gmail o Google Fotos en su barra inferior.
      indicatorColor: esquemaColor.secondaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.normal,
          color: states.contains(WidgetState.selected) ? esquemaColor.onSurface : esquemaColor.onSurfaceVariant,
        ),
      ),
    ),
  );
}

/// Círculo de acción rápida con icono + etiqueta. En Material You, el
/// "contenedor tonal" (fondo primaryContainer, icono onPrimaryContainer) es
/// el patrón estándar para botones de icono destacados, el mismo que usa
/// Google Fotos para "Buscar / Crear / Compartir" en su pantalla principal.
class QuickAction extends StatelessWidget {
  const QuickAction({super.key, required this.icono, required this.etiqueta, required this.onTap});

  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: esquema.primaryContainer, shape: BoxShape.circle),
              child: Icon(icono, color: esquema.onPrimaryContainer),
            ),
            const SizedBox(height: 6),
            Text(
              etiqueta,
              style: TextStyle(fontSize: 12, color: esquema.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
