
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens de color de DESIGN.md (estilo "libro de cuentas"): casi todo es
/// neutro y el azul de marca solo aparece en los datos (`data`).
class AppColors {
  AppColors._();

  static const ground = Color(0xFFF2F4F7);
  static const surface = Color(0xFFFFFFFF);
  static const active = Color(0xFFEEEEEE);
  static const activeButton = Color(0xFFE5E5E5);
  static const border = Color(0xFFE5E7EB);
  static const rule = Color(0xFFF0F0F0);
  static const control = Color(0xFFD1D5DB);
  static const text = Color(0xFF111111);
  static const muted = Color(0xFF5F6368);
  static const placeholder = Color(0xFF6B6B6B);
  static const ink = Color(0xFF1D1F20);
  static const data = Color(0xFF0A66BF);
  static const positive = Color(0xFF247B50);
  static const negative = Color(0xFFC4242A);
  static const white = Color(0xFFFFFFFF);

  static const tagNeutralBg = active;
  static const tagNeutralText = text;
  static const tagSuccessBg = Color(0xFFDCFAE5);
  static const tagSuccessBorder = Color(0xFFA7F3D0);
  static const tagSuccessText = Color(0xFF04250E);
  static const tagWarningBg = Color(0xFFFFFBEB);
  static const tagWarningBorder = Color(0xFFFDE68A);
  static const tagWarningText = Color(0xFF92400E);
  static const tagErrorBg = Color(0xFFFFEDEA);
  static const tagErrorBorder = Color(0xFFF5C2C0);
  static const tagErrorText = Color(0xFF831C1E);

  /// Fondos pálidos de avatar: identidad de la persona, nunca datos.
  static const personTints = [
    Color(0xFFDDEFE6),
    Color(0xFFF5E8D3),
    Color(0xFFDCE7F5),
    Color(0xFFF3DDE4),
  ];

  static const googleBlue = Color(0xFF4285F4);
  static const googleGreen = Color(0xFF34A853);
  static const googleYellow = Color(0xFFFBBC05);
  static const googleRed = Color(0xFFEA4335);

  // Alias de las pantallas de reclutador, que quedan fuera del rediseño.
  static const primary = ink;
  static const azul = data;
  static const tinta = text;
  static const fondo = ground;
  static const menta = tagSuccessBg;
}

class AppRadii {
  AppRadii._();

  static const panel = 8.0;
  static const control = 6.0;
  static const tag = 4.0;
}

class AppSpacing {
  AppSpacing._();

  static const screen = 16.0;
  static const gap = 16.0;
  static const group = 8.0;
  static const micro = 4.0;
  static const tap = 44.0;
  static const field = 48.0;
}

/// Estilos de texto. Bricolage Grotesque en 400/500/600; Geist Mono solo
/// para cifras, con cifras tabulares.
class AppText {
  AppText._();

  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _bricolage(
    double size,
    FontWeight weight,
    double height, {
    Color color = AppColors.text,
  }) => GoogleFonts.bricolageGrotesque(
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: color,
  );

  static TextStyle _mono(double size, double height, {Color color = AppColors.text}) =>
      GoogleFonts.geistMono(
        fontSize: size,
        fontWeight: FontWeight.w400,
        height: height,
        color: color,
        fontFeatures: _tabular,
      );

  static TextStyle get display => _mono(33, 1.1);
  static TextStyle get kpi => _mono(23, 1.2);
  static TextStyle get numInline => _mono(14, 1.5);
  static TextStyle get badgeMono => GoogleFonts.geistMono(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1,
    color: AppColors.white,
    fontFeatures: _tabular,
  );
  static TextStyle get metaMono =>
      _mono(12, 1.4, color: AppColors.muted);
  static TextStyle get h1 => _bricolage(23, FontWeight.w600, 1.2);
  static TextStyle get h2 => _bricolage(16, FontWeight.w600, 1.25);
  static TextStyle get body => _bricolage(14, FontWeight.w400, 1.5);
  static TextStyle get bodyStrong => _bricolage(14, FontWeight.w500, 1.5);
  static TextStyle get field => _bricolage(16, FontWeight.w400, 1.5);
  static TextStyle get label => _bricolage(14, FontWeight.w500, 1.5);
  static TextStyle get button => _bricolage(14, FontWeight.w600, 1.5);
  static TextStyle get meta =>
      _bricolage(12, FontWeight.w400, 1.4, color: AppColors.muted);
  static TextStyle get metaStrong =>
      _bricolage(12, FontWeight.w500, 1.4, color: AppColors.muted);
  static TextStyle get mutedBody =>
      _bricolage(14, FontWeight.w400, 1.5, color: AppColors.muted);
}

class AppShadows {
  AppShadows._();

  /// Única sombra permitida: lo que flota (compositor del chat, tooltips).
  static const floating = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, .06),
    blurRadius: 8,
    offset: Offset(0, 2),
  );
}

ThemeData construirTemaApp() {
  final esquema = ColorScheme.fromSeed(
    seedColor: AppColors.ink,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.ink,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.active,
    onPrimaryContainer: AppColors.text,
    secondary: AppColors.ink,
    onSecondary: AppColors.white,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.muted,
    outline: AppColors.control,
    outlineVariant: AppColors.border,
    error: AppColors.negative,
    onError: AppColors.white,
    errorContainer: AppColors.tagErrorBg,
    onErrorContainer: AppColors.tagErrorText,
  );

  final texto = GoogleFonts.bricolageGrotesqueTextTheme(
    ThemeData.light().textTheme,
  ).apply(bodyColor: AppColors.text, displayColor: AppColors.text).copyWith(
    headlineSmall: AppText.h1,
    titleLarge: AppText.h1,
    titleMedium: AppText.h2,
    titleSmall: AppText.h2,
    bodyLarge: AppText.field,
    bodyMedium: AppText.body,
    bodySmall: AppText.meta,
    labelLarge: AppText.label,
    labelMedium: AppText.metaStrong,
    labelSmall: AppText.meta,
  );

  OutlineInputBorder borde(Color color, [double ancho = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: color, width: ancho),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    textTheme: texto,
    scaffoldBackgroundColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
    iconTheme: const IconThemeData(color: AppColors.text, size: 20),
    dividerTheme: const DividerThemeData(
      color: AppColors.rule,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: AppText.h1,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
      },
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSpacing.field),
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        textStyle: AppText.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSpacing.field),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.control),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        textStyle: AppText.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.data,
        textStyle: AppText.button,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: AppText.field.copyWith(color: AppColors.placeholder),
      errorStyle: AppText.meta.copyWith(color: AppColors.negative),
      border: borde(AppColors.control),
      enabledBorder: borde(AppColors.control),
      focusedBorder: borde(AppColors.ink, 1),
      errorBorder: borde(AppColors.negative, 1),
      focusedErrorBorder: borde(AppColors.negative, 1),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.panel),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.ink,
      labelStyle: AppText.label,
      side: const BorderSide(color: AppColors.control),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.ink,
      inactiveTrackColor: AppColors.control,
      thumbColor: AppColors.ink,
      overlayColor: AppColors.ink.withValues(alpha: .08),
      trackHeight: 4,
      valueIndicatorColor: AppColors.ink,
      valueIndicatorTextStyle: AppText.meta.copyWith(color: AppColors.white),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.ink,
      linearTrackColor: AppColors.control,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadii.control),
        boxShadow: const [AppShadows.floating],
      ),
      textStyle: AppText.meta.copyWith(color: AppColors.white),
      waitDuration: const Duration(milliseconds: 400),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: AppText.body.copyWith(color: AppColors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.panel),
        side: const BorderSide(color: AppColors.border),
      ),
      titleTextStyle: AppText.h2,
      contentTextStyle: AppText.body,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.panel)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      height: 64,
      indicatorColor: AppColors.active,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => AppText.metaStrong.copyWith(
          color: AppColors.text,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
        ),
      ),
    ),
  );
}

/// Tokens de movimiento de animation.md y Autonomous Ops. Solo `transform` y
/// opacidad; nada supera los 300 ms y nunca se usa `easeIn` en la interfaz.
class Motion {
  Motion._();

  static const easeOut = Cubic(0.23, 1, 0.32, 1); // entradas, salidas, feedback
  static const easeOps = Cubic(0.16, 1, 0.3, 1); // barrido técnico Autonomous Ops
  static const easeInOut = Cubic(0.77, 0, 0.175, 1); // movimiento en pantalla
  static const easeDrawer = Cubic(0.32, 0.72, 0, 1); // paneles que se apilan

  static const press = Duration(milliseconds: 120);
  static const fast = Duration(milliseconds: 150); // color, interruptor, tooltip
  static const sweep = Duration(milliseconds: 160); // barrido horizontal
  static const sweepStagger = Duration(milliseconds: 28); // escalonado de filas
  static const base = Duration(milliseconds: 200); // entradas, pasos, burbujas
  static const slow = Duration(milliseconds: 300); // splash, transición de pantalla
  static const stagger = Duration(milliseconds: 40); // escalonado entre pasos
}

/// Preferencia manual de reducción de movimiento configurable desde Mi perfil.
final ValueNotifier<bool> reducirMovimientoManual = ValueNotifier<bool>(false);

/// Movimiento reducido del sistema o activado por el usuario en Mi perfil.
bool reduce(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) || reducirMovimientoManual.value;
