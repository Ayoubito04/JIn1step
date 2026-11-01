import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'design_system.dart';

/// Explica por qué la IA puntuó así una oferta: el encaje, el motivo y las
/// palabras clave del CV que la oferta cubre y las que faltan. Solo pinta lo
/// que hay (el plan B por habilidades no trae motivo ni palabras clave).
class ValoracionIa extends StatelessWidget {
  const ValoracionIa({
    super.key,
    required this.puntuacion,
    this.motivo,
    this.cubiertas = const [],
    this.faltan = const [],
    this.titulo = 'Por qué la IA la eligió',
  });

  /// Lee los campos de una postulación del backend.
  factory ValoracionIa.deCandidatura(
    Map<String, dynamic> postulacion, {
    String titulo = 'Por qué la IA la eligió',
  }) => ValoracionIa(
    puntuacion: (postulacion['puntuacionIa'] as num?)?.round(),
    motivo: postulacion['motivoIa'] as String?,
    cubiertas: _lista(postulacion['palabrasClaveCubiertas']),
    faltan: _lista(postulacion['palabrasClaveFaltantes']),
    titulo: titulo,
  );

  static List<String> _lista(Object? valor) => valor is List
      ? valor.whereType<String>().where((s) => s.trim().isNotEmpty).toList()
      : const [];

  final int? puntuacion;
  final String? motivo;
  final List<String> cubiertas;
  final List<String> faltan;
  final String titulo;

  bool get _hayMotivo => motivo != null && motivo!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (puntuacion == null &&
        !_hayMotivo &&
        cubiertas.isEmpty &&
        faltan.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (puntuacion != null)
          PanelList(
            children: [
              ListRow(
                title: 'Encaje según la IA',
                trailing: MatchIndicator(match: puntuacion!),
              ),
            ],
          ),
        if (_hayMotivo) ...[
          const SizedBox(height: AppSpacing.gap),
          SectionTitle(titulo),
          const SizedBox(height: AppSpacing.group),
          Panel(child: Text(motivo!.trim(), style: AppText.body)),
        ],
        if (cubiertas.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.gap),
          const SectionTitle('Palabras clave cubiertas'),
          const SizedBox(height: AppSpacing.group),
          _etiquetas(cubiertas, StatusVariant.success),
        ],
        if (faltan.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.gap),
          const SectionTitle('Palabras clave que faltan'),
          const SizedBox(height: AppSpacing.group),
          _etiquetas(faltan, StatusVariant.warning),
        ],
      ],
    );
  }

  Widget _etiquetas(List<String> palabras, StatusVariant variante) => Wrap(
    spacing: AppSpacing.group,
    runSpacing: AppSpacing.group,
    children: [
      for (final palabra in palabras) StatusTag(label: palabra, variant: variante),
    ],
  );
}
