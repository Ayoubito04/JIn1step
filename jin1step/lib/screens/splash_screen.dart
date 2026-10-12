import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../widgets/brand_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _video;
  Timer? _timeout;
  bool _listo = false;
  bool _navegando = false;

  @override
  void initState() {
    super.initState();
    _video = VideoPlayerController.asset(
      'assets/videos/Animación de carga app.mp4',
    )..addListener(_alCambiarVideo);
    unawaited(_iniciarVideo());
    // Si una plataforma tarda en abrir el vídeo, la app sigue siendo usable.
    _timeout = Timer(const Duration(seconds: 12), _continuar);
  }

  Future<void> _iniciarVideo() async {
    try {
      await _video.initialize().timeout(const Duration(seconds: 8));
      if (!mounted) return;
      await _video.setVolume(0);
      await _video.setLooping(false);
      setState(() => _listo = true);
      await _video.play();
    } catch (_) {
      // El logo de respaldo y el botón Omitir siguen disponibles si el
      // navegador o el dispositivo no puede reproducir el MP4.
      if (mounted) setState(() => _listo = false);
    }
  }

  void _alCambiarVideo() {
    if (!_video.value.isInitialized) return;
    if (_video.value.position >= _video.value.duration &&
        !_video.value.isPlaying) {
      _continuar();
    }
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
    _video
      ..removeListener(_alCambiarVideo)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071A33),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.15),
                  radius: 1.1,
                  colors: [Color(0xFF123D68), Color(0xFF071A33)],
                ),
              ),
            ),
          ),
          Center(
            child: _listo && _video.value.isInitialized
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final videoSize = _video.value.size;
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                          maxHeight: constraints.maxHeight,
                        ),
                        child: AspectRatio(
                          aspectRatio: videoSize.width / videoSize.height,
                          child: VideoPlayer(_video),
                        ),
                      );
                    },
                  )
                : const BrandLogo(size: 112),
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
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _continuar,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.78),
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
