import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../widgets/brand_logo.dart';

/// Splash: el logo entra en una sola pasada (nunca en bucle) y se continúa.
/// Con movimiento reducido se muestra el logo estático.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Pausa con el logo ya completo antes de pasar a la siguiente pantalla.
  static const _pausa = Duration(milliseconds: 500);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AnimatedBrandLogo.duracion,
  );
  Timer? _siguiente;
  bool _arrancado = false;
  bool _navegando = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_arrancado) return;
    _arrancado = true;
    if (reduce(context)) {
      _controller.value = 1;
      _siguiente = Timer(_pausa, _continuar);
    } else {
      _controller.forward().whenComplete(() {
        if (mounted) _siguiente = Timer(_pausa, _continuar);
      });
    }
  }

  void _continuar() {
    if (!mounted || _navegando) return;
    _navegando = true;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  void dispose() {
    _siguiente?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// El wordmark sube 8 px y aparece a los 600 ms (animation.md).
  Widget _wordmark(Widget hijo) => AnimatedBuilder(
    animation: _controller,
    child: hijo,
    builder: (context, child) {
      final total = AnimatedBrandLogo.duracion.inMilliseconds;
      final local =
          ((_controller.value * total - 600) / Motion.slow.inMilliseconds)
              .clamp(0.0, 1.0);
      final t = Motion.easeOut.transform(local);
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, reduce(context) ? 0 : 8 * (1 - t)),
          child: child,
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBrandLogo(animation: _controller, size: 230),
            const SizedBox(height: AppSpacing.gap),
            _wordmark(
              Column(
                children: [
                  Text(
                    'JIn1Step',
                    style: AppText.h1.copyWith(letterSpacing: -0.015 * 23),
                  ),
                  const SizedBox(height: AppSpacing.micro),
                  Text(
                    'Buscar trabajo en un solo paso',
                    style: AppText.mutedBody,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
