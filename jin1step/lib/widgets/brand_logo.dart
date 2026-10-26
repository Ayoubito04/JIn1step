import 'package:flutter/material.dart';

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
          painter: const J1sLogoPainter(progress: .72),
        ),
      ),
    );
  }
}

/// Reproduce la entrada escalonada J → 1 → S del SVG nuevo en todas las
/// plataformas Flutter, incluidas Android y Web.
class AnimatedBrandLogo extends StatefulWidget {
  const AnimatedBrandLogo({super.key, this.size = 220});

  final double size;

  @override
  State<AnimatedBrandLogo> createState() => _AnimatedBrandLogoState();
}

class _AnimatedBrandLogoState extends State<AnimatedBrandLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Animación del logo de Jin1step',
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: J1sLogoPainter(progress: _motion.value),
        ),
      ),
    ),
  );
}

/// Trazados, degradados y tiempos basados en assets/videos/logo-jin1step-animado.svg.
class J1sLogoPainter extends CustomPainter {
  const J1sLogoPainter({required this.progress});

  final double progress;

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

  double _between(double value, double start, double end) =>
      ((value - start) / (end - start)).clamp(0.0, 1.0);

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

    final jOpacity = progress < .2
        ? Curves.easeOut.transform(_between(progress, 0, .2))
        : progress < .88
        ? 1.0
        : 1 - Curves.easeIn.transform(_between(progress, .88, 1));
    final jOffset = progress < .2
        ? -70 * (1 - Curves.easeOut.transform(_between(progress, 0, .2)))
        : progress > .88
        ? -20 * _between(progress, .88, 1)
        : 0.0;
    canvas.save();
    canvas.translate(jOffset, 0);
    _draw(canvas, _j, _jGradient, jOpacity);
    canvas.restore();

    var oneOpacity = 0.0;
    var oneScaleY = .05;
    var oneOffsetY = 0.0;
    if (progress < .35) {
      final t = Curves.easeOut.transform(_between(progress, .1, .35));
      oneOpacity = t;
      oneScaleY = .05 + (.99 * t);
    } else if (progress < .42) {
      final t = _between(progress, .35, .42);
      oneOpacity = 1;
      oneScaleY = 1.04 - (.04 * t);
    } else if (progress < .55) {
      oneOpacity = 1;
      oneScaleY = 1;
      oneOffsetY = -14 * _between(progress, .42, .55);
    } else if (progress < .65) {
      oneOpacity = 1;
      oneScaleY = 1;
      oneOffsetY = -14 * (1 - _between(progress, .55, .65));
    } else {
      oneOpacity = 1;
      oneScaleY = 1;
    }
    oneOpacity *= 1 - Curves.easeIn.transform(_between(progress, .88, 1));
    final oneBounds = _one.getBounds();
    canvas.save();
    canvas.translate(oneBounds.center.dx, oneBounds.bottom);
    canvas.scale(1, oneScaleY);
    canvas.translate(-oneBounds.center.dx, -oneBounds.bottom);
    canvas.translate(0, oneOffsetY);
    _draw(canvas, _one, _oneGradient, oneOpacity);
    canvas.restore();

    final sOpacity = progress < .45
        ? Curves.easeOut.transform(_between(progress, .22, .45))
        : progress < .88
        ? 1.0
        : 1 - Curves.easeIn.transform(_between(progress, .88, 1));
    final sOffset = progress < .45
        ? 70 * (1 - Curves.easeOut.transform(_between(progress, .22, .45)))
        : progress > .88
        ? 20 * _between(progress, .88, 1)
        : 0.0;
    canvas.save();
    canvas.translate(sOffset, 0);
    _draw(canvas, _s, _sGradient, sOpacity);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant J1sLogoPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
