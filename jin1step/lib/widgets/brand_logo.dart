import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Marca vectorial J1S, dibujada con los mismos trazados y degradados del SVG.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Logo de Jin1step',
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: const J1sLogoPainter(),
        ),
      ),
    );
  }
}

/// Entrada del logo en UNA sola pasada (animation.md): la J entra desde la
/// izquierda (8 px) sin retraso, la flecha del 1 crece desde abajo (escala
/// 0.6→1) a los 150 ms y la S entra desde la derecha a los 300 ms. Cada pieza
/// dura `Motion.slow` con `easeOut`. Lo dirige quien lo usa con [animation]
/// (0→1 durante [duracion]), para que el wordmark vaya en el mismo reloj.
class AnimatedBrandLogo extends StatelessWidget {
  const AnimatedBrandLogo({
    super.key,
    required this.animation,
    this.size = 220,
  });

  /// Duración total: la última pieza (la S) termina a los 600 ms. El wordmark
  /// de la pantalla de inicio entra a los 600 ms y acaba a los 900 ms.
  static const duracion = Duration(milliseconds: 900);

  final Animation<double> animation;
  final double size;

  /// Progreso (0..1, ya con `easeOut`) de una pieza que empieza en [retraso].
  static double _pieza(double t, Duration retraso) {
    final ms = t * duracion.inMilliseconds;
    final local = ((ms - retraso.inMilliseconds) / Motion.slow.inMilliseconds)
        .clamp(0.0, 1.0);
    return Motion.easeOut.transform(local);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Logo de Jin1step',
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) => CustomPaint(
          size: Size.square(size),
          painter: J1sLogoPainter(
            j: _pieza(animation.value, Duration.zero),
            one: _pieza(animation.value, const Duration(milliseconds: 150)),
            s: _pieza(animation.value, const Duration(milliseconds: 300)),
          ),
        ),
      ),
    ),
  );
}

/// Trazados y degradados basados en assets/videos/logo-jin1step-animado.svg.
/// Los degradados del logo son los únicos permitidos.
class J1sLogoPainter extends CustomPainter {
  /// [j], [one] y [s] son el progreso (0..1, ya suavizado) de cada pieza. Por
  /// defecto el logo está completo.
  const J1sLogoPainter({this.j = 1, this.one = 1, this.s = 1});

  final double j;
  final double one;
  final double s;

  static final Path _j = Path()
    ..moveTo(335, 460)
    ..lineTo(555, 460)
    ..lineTo(555, 790)
    ..cubicTo(555, 900, 470, 985, 360, 985)
    ..cubicTo(290, 985, 215, 945, 178, 868)
    ..lineTo(278, 808)
    ..cubicTo(295, 850, 330, 878, 365, 878)
    ..cubicTo(415, 878, 446, 845, 446, 790)
    ..lineTo(446, 562)
    ..lineTo(335, 562)
    ..close();

  static final Path _one = Path()
    ..moveTo(720, 197)
    ..lineTo(720, 830)
    ..lineTo(596, 957)
    ..lineTo(596, 420)
    ..lineTo(383, 420)
    ..close();

  static final Path _s = Path()
    ..moveTo(720, 470)
    ..cubicTo(780, 430, 860, 417, 920, 418)
    ..cubicTo(980, 420, 1030, 445, 1063, 468)
    ..lineTo(1010, 567)
    ..cubicTo(960, 540, 910, 523, 870, 523)
    ..cubicTo(820, 523, 790, 545, 790, 578)
    ..cubicTo(790, 610, 830, 625, 900, 640)
    ..cubicTo(1000, 665, 1090, 690, 1090, 800)
    ..cubicTo(1090, 920, 990, 985, 870, 985)
    ..cubicTo(790, 985, 720, 970, 660, 945)
    ..lineTo(748, 857)
    ..cubicTo(790, 872, 830, 880, 870, 880)
    ..cubicTo(930, 880, 975, 860, 975, 815)
    ..cubicTo(975, 775, 940, 765, 850, 742)
    ..cubicTo(790, 727, 750, 712, 720, 695)
    ..close();

  static const _jGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A66BF), Color(0xFF083F7E)],
  );
  static const _oneGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF00B4E0), Color(0xFF0B6FD0)],
  );
  static const _sGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1D406E), Color(0xFF101E38)],
  );

  void _draw(
    Canvas canvas,
    Path path,
    LinearGradient gradient,
    double opacity,
  ) {
    if (opacity <= 0) return;
    final paint = Paint()
      ..isAntiAlias = true
      ..shader = gradient.createShader(path.getBounds())
      ..color = Colors.white.withValues(alpha: opacity);
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = size.shortestSide / 1050;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-635, -591);

    // Los desplazamientos están en píxeles lógicos; el lienzo está escalado.
    final px = 1 / scale;

    canvas.save();
    canvas.translate(-8 * px * (1 - j), 0);
    _draw(canvas, _j, _jGradient, j);
    canvas.restore();

    final oneBounds = _one.getBounds();
    canvas.save();
    canvas.translate(oneBounds.center.dx, oneBounds.bottom);
    canvas.scale(1, .6 + .4 * one);
    canvas.translate(-oneBounds.center.dx, -oneBounds.bottom);
    _draw(canvas, _one, _oneGradient, one);
    canvas.restore();

    canvas.save();
    canvas.translate(8 * px * (1 - s), 0);
    _draw(canvas, _s, _sGradient, s);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant J1sLogoPainter oldDelegate) =>
      oldDelegate.j != j || oldDelegate.one != one || oldDelegate.s != s;
}
