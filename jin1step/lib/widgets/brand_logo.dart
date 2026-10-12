import 'package:flutter/material.dart';

/// Identidad visual compartida por las pantallas de acceso y registro.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Logo de Jin1step',
      child: Image.asset(
        'assets/images/Logo J1S.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
