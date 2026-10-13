import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const azul = Color(0xFF5546E8);
  static const tinta = Color(0xFF17213B);
  static const fondo = Color(0xFFF3F2FC);
  static const menta = Color(0xFFB8F1DB);
}

ThemeData construirTemaApp() {
  final esquema = ColorScheme.fromSeed(
    seedColor: AppColors.azul,
    brightness: Brightness.light,
    surface: AppColors.fondo,
  );
  final texto = GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
    bodyColor: AppColors.tinta,
    displayColor: AppColors.tinta,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    textTheme: texto,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.tinta,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: texto.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide(color: esquema.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .82),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: esquema.outlineVariant.withValues(alpha: .6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: esquema.outlineVariant.withValues(alpha: .6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: esquema.primary, width: 1.6),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white.withValues(alpha: .88),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: esquema.outlineVariant.withValues(alpha: .55)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: esquema.secondaryContainer.withValues(alpha: .65),
      selectedColor: esquema.primary,
      labelStyle: TextStyle(color: esquema.onSecondaryContainer, fontWeight: FontWeight.w600),
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withValues(alpha: .94),
      elevation: 0,
      indicatorColor: esquema.primary.withValues(alpha: .12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
        fontSize: 11,
        fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        color: states.contains(WidgetState.selected) ? esquema.primary : esquema.onSurfaceVariant,
      )),
    ),
  );
}

/// Superficie de vidrio discreta para paneles destacados, con blur reducido.
class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .76),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: .85)),
            boxShadow: [BoxShadow(color: AppColors.tinta.withValues(alpha: .06), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: child,
        ),
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

/// Líneas orgánicas animadas para dar profundidad al fondo de todas las
/// pantallas. El painter repinta solo el canvas, sin reconstruir los formularios.
class AnimatedLinesBackground extends StatefulWidget {
  const AnimatedLinesBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AnimatedLinesBackground> createState() =>
      _AnimatedLinesBackgroundState();
}

class _AnimatedLinesBackgroundState extends State<AnimatedLinesBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  )..repeat();

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEAE8FF), Color(0xFFF7F8FF), Color(0xFFE6F6F2)],
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _FlowLinesPainter(progress: _motion),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _FlowLinesPainter extends CustomPainter {
  _FlowLinesPainter({required this.progress}) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final phase = progress.value * math.pi * 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;

    for (var row = 0; row < 15; row++) {
      final baseY = size.height * (row / 14);
      final amplitude = 13 + (row % 4) * 3.5;
      final path = Path();
      for (var step = 0; step <= 48; step++) {
        final x = size.width * (step / 48);
        final wave = math.sin(
          (x / size.width * math.pi * 2) + phase + row * 0.34,
        );
        final crossWave = math.sin(
          (x / size.width * math.pi) - phase * 0.42 + row * 0.18,
        );
        final y = baseY + wave * amplitude + crossWave * 7;
        if (step == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      paint.color = (row.isEven ? AppColors.azul : const Color(0xFF20A88A))
          .withValues(alpha: row % 3 == 0 ? 0.14 : 0.085);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlowLinesPainter oldDelegate) => false;
}

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
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: esquema.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(19)),
            child: Icon(icono, color: esquema.primary),
          ),
          const SizedBox(height: 7),
          Text(etiqueta, style: TextStyle(fontSize: 11, color: esquema.onSurfaceVariant, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
