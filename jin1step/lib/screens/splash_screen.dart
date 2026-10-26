import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/brand_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timeout;
  bool _navegando = false;

  @override
  void initState() {
    super.initState();
    // La nueva animación SVG dura un ciclo de cinco segundos.
    _timeout = Timer(const Duration(seconds: 5), _continuar);
  }

  void _continuar() {
    if (!mounted || _navegando) return;
    _navegando = true;
    _timeout?.cancel();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FD),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFEAF5FF), Color(0xFFF8FBFF), Colors.white],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AnimatedBrandLogo(size: 230),
                const SizedBox(height: 16),
                const Text(
                  'JIn1Step',
                  style: TextStyle(
                    color: Color(0xFF526A88),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Buscar trabajo en un solo paso',
                  style: TextStyle(color: Color(0xFF7F94AF), fontSize: 14),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 38,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Tu siguiente paso empieza aquí',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF526A88),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _continuar,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(
                        0xFF526A88,
                      ).withValues(alpha: 0.78),
                    ),
                    child: const Text('Omitir'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
