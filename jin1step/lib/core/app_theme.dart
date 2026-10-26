import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF5B3FD0);
  static const primaryLight = Color(0xFF7A5CF0);
  static const primaryDark = Color(0xFF4A2FB8);
  static const primaryTint = Color(0xFFECE8FB);
  static const ink = Color(0xFF1B1830);
  static const muted = Color(0xFF5E5A73);
  static const cardBorder = Color(0xFFE6E2F5);
  static const fieldBorder = Color(0xFFD8D3EE);
  static const iconTile = Color(0xFFF0EEF8);
  static const iconInk = Color(0xFF4A4668);
  static const pillText = Color(0xFF3B3758);
  static const barTrack = Color(0xFFE8E4F6);
  static const badge = Color(0xFFC2255C);
  static const matchHigh = Color(0xFF0F7A4F);
  static const matchMid = Color(0xFF8A5A00);
  static const matchLow = Color(0xFF6B6784);
  static const successBackground = Color(0xFFE3F4EC);
  static const successBorder = Color(0xFFBFE3D2);
  static const successText = Color(0xFF0F7A4F);
  static const warningBackground = Color(0xFFFCEFD2);
  static const warningBorder = Color(0xFFF0DBA5);
  static const warningText = Color(0xFF7A4E00);
  static const errorBackground = Color(0xFFFBE3E0);
  static const errorBorder = Color(0xFFF3C4BF);
  static const errorText = Color(0xFF8F2620);
  static const white = Color(0xFFFFFFFF);
  static const badgeBorder = white;
  static const googleBlue = Color(0xFF4285F4);
  static const googleGreen = Color(0xFF34A853);
  static const googleYellow = Color(0xFFFBBC05);
  static const googleRed = Color(0xFFEA4335);
  static const shadowCard = Color.fromRGBO(70, 50, 160, .08);
  static const shadowButton = Color.fromRGBO(91, 63, 208, .28);
  static const shadowNavigation = Color.fromRGBO(70, 50, 160, .06);

  // Alias temporales para mantener compilables las pantallas existentes
  // mientras se migran, una por una, al nuevo sistema visual.
  static const azul = primary;
  static const tinta = ink;
  static const fondo = white;
  static const menta = successBackground;
}

class AppGradients {
  AppGradients._();

  static const background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0, .38, 1],
    colors: [Color(0xFFE9E4FA), Color(0xFFF6F4FD), AppColors.white],
  );
  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.primaryLight],
  );
  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primaryDark, AppColors.primaryLight],
  );
  static const barFill = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.primary, AppColors.primaryLight],
  );
  static const googleMark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.googleBlue,
      AppColors.googleGreen,
      AppColors.googleYellow,
      AppColors.googleRed,
      AppColors.googleBlue,
    ],
    stops: [0, .28, .5, .72, 1],
  );
}

class AppRadii {
  AppRadii._();

  static const card = 20.0;
  static const authCard = 22.0;
  static const hero = 22.0;
  static const button = 16.0;
  static const field = 14.0;
  static const search = 16.0;
  static const iconTile = 12.0;
  static const pill = 99.0;
  static const progress = 9.0;
  static const chatBubble = 18.0;
  static const chatComposer = 24.0;
}

class AppSpacing {
  AppSpacing._();

  static const screenHorizontal = 18.0;
  static const authHorizontal = 24.0;
  static const screenTop = 22.0;
  static const blockGap = 12.0;
  static const authBlockGap = 14.0;
  static const authTop = 92.0;
  static const cardPadding = 14.0;
  static const cardGap = 10.0;
}

class AppDimensions {
  AppDimensions._();

  static const authLogo = 74.0;
}

class AppFontSizes {
  AppFontSizes._();

  static const authHeading = 26.0;
  static const body = 14.0;
  static const muted = 13.0;
  static const pill = 12.0;
  static const button = 15.0;
}

class AppShadows {
  AppShadows._();

  static const card = BoxShadow(
    color: AppColors.shadowCard,
    blurRadius: 12,
    offset: Offset(0, 3),
  );
  static const primaryButton = BoxShadow(
    color: AppColors.shadowButton,
    blurRadius: 16,
    offset: Offset(0, 6),
  );
  static const bottomNavigation = BoxShadow(
    color: AppColors.shadowNavigation,
    blurRadius: 14,
    offset: Offset(0, -4),
  );
}

ThemeData construirTemaApp() {
  final esquemaBase = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    surface: AppColors.white,
  );
  final esquema = esquemaBase.copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.primaryTint,
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.primaryDark,
    onSecondary: AppColors.white,
    surface: AppColors.white,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    outline: AppColors.fieldBorder,
    outlineVariant: AppColors.cardBorder,
    error: AppColors.errorText,
    onError: AppColors.white,
    errorContainer: AppColors.errorBackground,
    onErrorContainer: AppColors.errorText,
  );
  final textoBase = GoogleFonts.plusJakartaSansTextTheme(
    ThemeData.light().textTheme,
  ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  final texto = textoBase.copyWith(
    headlineSmall: GoogleFonts.plusJakartaSans(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      color: AppColors.ink,
    ),
    titleMedium: GoogleFonts.plusJakartaSans(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      height: 1.3,
      color: AppColors.ink,
    ),
    bodyMedium: GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.ink,
    ),
    bodySmall: GoogleFonts.plusJakartaSans(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.muted,
    ),
    labelLarge: GoogleFonts.plusJakartaSans(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    labelMedium: GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.pillText,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    textTheme: texto,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: texto.titleLarge?.copyWith(
        fontSize: 24,
        letterSpacing: -0.4,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
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
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        side: const BorderSide(color: AppColors.fieldBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.primaryTint,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: AppColors.pillText,
        fontWeight: FontWeight.w600,
      ),
      side: const BorderSide(color: AppColors.fieldBorder),
      shape: const StadiumBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      height: 72,
      indicatorColor: AppColors.primaryTint,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? AppColors.primaryDark
              : AppColors.muted,
        ),
      ),
    ),
  );
}

/// Superficie de vidrio discreta para paneles destacados, con blur reducido.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: const [AppShadows.card],
        ),
        child: child,
      ),
    );
  }
}

/// Fondo compartido de acceso y registro, decorativo y de bajo coste visual.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // El fondo animado vive por encima de Navigator en MaterialApp.builder,
    // así se comparte con login, registro y las demás rutas.
    return child;
  }
}

/// Fondo suave lavanda que pasa a blanco, como en las pantallas del diseño.
class AnimatedLinesBackground extends StatefulWidget {
  const AnimatedLinesBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AnimatedLinesBackground> createState() =>
      _AnimatedLinesBackgroundState();
}

class _AnimatedLinesBackgroundState extends State<AnimatedLinesBackground> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppGradients.background),
        ),
        widget.child,
      ],
    );
  }
}

class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: esquema.primary.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(19),
              ),
              child: Icon(icono, color: esquema.primary),
            ),
            const SizedBox(height: 7),
            Text(
              etiqueta,
              style: TextStyle(
                fontSize: 11,
                color: esquema.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
