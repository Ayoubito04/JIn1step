import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/candidato.service.dart';
import '../widgets/design_system.dart';
import '../widgets/valoracion_ia.dart';

class MisPostulacionesPage extends StatefulWidget {
  const MisPostulacionesPage({
    super.key,
    this.postulacionId,
    this.filtroInicial = 'Todas',
    this.service,
  });

  /// Opcional para poder inyectar un servicio falso en los tests.
  final CandidatoService? service;

  final String? postulacionId;

  /// 'Todas', 'Manuales' o 'Por IA'.
  final String filtroInicial;

  @override
  State<MisPostulacionesPage> createState() => _MisPostulacionesPageState();
}

class _MisPostulacionesPageState extends State<MisPostulacionesPage> {
  late final CandidatoService _service = widget.service ?? CandidatoService();
  late String _filtro = widget.filtroInicial;
  late Future<List<Map<String, dynamic>>> _postulaciones = _service
      .listarPostulaciones();

  Future<void> _recargar() async {
    final actualizadas = _service.listarPostulaciones();
    setState(() {
      _postulaciones = actualizadas;
    });
    try {
      await actualizadas;
    } catch (_) {
      // El error se muestra en pantalla a través del FutureBuilder.
    }
  }

  /// Abre el detalle de una candidatura; si se retira, recarga la lista.
  Future<void> _abrirDetalle(Map<String, dynamic> postulacion) async {
    final retirada = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DetalleCandidatura(
        postulacion: postulacion,
        service: _service,
      ),
    );
    if (retirada != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Candidatura retirada.')),
    );
    await _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _recargar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.screen),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: AppIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Volver',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: AppSpacing.gap),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _postulaciones,
                builder: (context, snapshot) => _contenido(snapshot),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contenido(AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(title: 'Mis candidaturas'),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: AppSpinner(size: 24)),
          ),
        ],
      );
    }
    if (snapshot.hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenHeader(title: 'Mis candidaturas'),
          const SizedBox(height: AppSpacing.gap),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(snapshot.error.toString(), style: AppText.body),
                const SizedBox(height: AppSpacing.gap),
                SecondaryButton(label: 'Reintentar', onPressed: _recargar),
              ],
            ),
          ),
        ],
      );
    }

    // Las propuestas del autopiloto sin decidir y las descartadas no son
    // candidaturas: se revisan en la pantalla del Autopiloto.
    final candidaturas = (snapshot.data ?? [])
        .where(esCandidaturaEnviada)
        .toList();
    if (candidaturas.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenHeader(title: 'Mis candidaturas'),
          const SizedBox(height: AppSpacing.gap),
          SizedBox(
            width: double.infinity,
            child: Panel(
              child: Text(
                'Todavía no tienes candidaturas. Cuando te postules, '
                'podrás seguir aquí su estado.',
                style: AppText.mutedBody,
              ),
            ),
          ),
        ],
      );
    }

    final seleccionadas = widget.postulacionId == null
        ? candidaturas
        : candidaturas
              .where((item) => item['id'] == widget.postulacionId)
              .toList();
    final base = seleccionadas.isEmpty ? candidaturas : seleccionadas;
    bool porIa(Map<String, dynamic> item) => item['postuladoPorIa'] == true;
    final filtradas = base.where((item) {
      if (_filtro == 'Manuales') return !porIa(item);
      if (_filtro == 'Por IA') return porIa(item);
      return true;
    }).toList();
    final opciones = <(String, int)>[
      ('Todas', base.length),
      ('Manuales', base.where((i) => !porIa(i)).length),
      ('Por IA', base.where(porIa).length),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenHeader(title: 'Mis candidaturas', subtitle: _resumen(base)),
        const SizedBox(height: AppSpacing.gap),
        Wrap(
          spacing: AppSpacing.group,
          runSpacing: AppSpacing.group,
          children: [
            for (final (filtro, cuenta) in opciones)
              FilterChipButton(
                label: filtro,
                count: cuenta,
                selected: _filtro == filtro,
                onTap: () => setState(() => _filtro = filtro),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.gap),
        if (filtradas.isEmpty)
          SizedBox(
            width: double.infinity,
            child: Panel(
              child: Text(
                'No hay candidaturas en esta categoría.',
                style: AppText.mutedBody,
              ),
            ),
          )
        else
          PanelList(
            children: [
              for (final postulacion in filtradas)
                _FilaCandidatura(
                  postulacion: postulacion,
                  onTap: () => _abrirDetalle(postulacion),
                ),
            ],
          ),
      ],
    );
  }

  /// Frase con lo importante: cuántas hay, en entrevista y pendientes.
  String _resumen(List<Map<String, dynamic>> lista) {
    final entrevistas = lista.where((i) => i['estado'] == 'ENTREVISTA').length;
    final pendientes = lista
        .where((i) => i['estado'] == 'PENDIENTE' || i['estado'] == 'ENVIADA')
        .length;
    final total = lista.length;
    final partes = [
      if (entrevistas > 0) '$entrevistas en entrevista',
      if (pendientes > 0)
        '$pendientes ${pendientes == 1 ? 'pendiente' : 'pendientes'} de revisión',
    ];
    final base = '$total ${total == 1 ? 'candidatura' : 'candidaturas'}';
    return partes.isEmpty ? base : '$base: ${partes.join(' y ')}';
  }
}

/// ENVIADA es el estado con el que el autopiloto crea la candidatura y
/// equivale, de cara al candidato, a «pendiente de revisión».
(String, StatusVariant) _estadoCandidatura(String? estado) => switch (estado) {
  'PENDIENTE' ||
  'ENVIADA' => ('Pendiente de revisión', StatusVariant.warning),
  'VISTA' => ('Vista por la empresa', StatusVariant.neutral),
  'ENTREVISTA' => ('Entrevista', StatusVariant.success),
  'RECHAZADA' => ('Rechazada', StatusVariant.error),
  'RETIRADA' => ('Retirada', StatusVariant.neutral),
  _ => (estado ?? 'Enviada', StatusVariant.neutral),
};

/// Solo se puede retirar mientras la empresa no la haya revisado.
bool _sePuedeRetirar(String? estado) =>
    estado == 'PENDIENTE' || estado == 'ENVIADA';

String _antiguedad(DateTime fecha) {
  final ahora = DateTime.now();
  final diferencia = ahora.difference(fecha);
  final dias = DateTime(
    ahora.year,
    ahora.month,
    ahora.day,
  ).difference(DateTime(fecha.year, fecha.month, fecha.day)).inDays;
  if (diferencia.inMinutes < 1) return 'Hace un momento';
  if (diferencia.inMinutes < 60) return 'Hace ${diferencia.inMinutes} min';
  if (diferencia.inHours < 24 && dias == 0) {
    return 'Hace ${diferencia.inHours} h';
  }
  if (dias <= 1) return 'Ayer';
  if (dias < 7) return 'Hace $dias días';
  if (dias < 30) {
    final semanas = dias ~/ 7;
    return 'Hace $semanas ${semanas == 1 ? 'semana' : 'semanas'}';
  }
  if (dias < 365) {
    final meses = dias ~/ 30;
    return 'Hace $meses ${meses == 1 ? 'mes' : 'meses'}';
  }
  final anios = dias ~/ 365;
  return 'Hace $anios ${anios == 1 ? 'año' : 'años'}';
}

class _FilaCandidatura extends StatelessWidget {
  const _FilaCandidatura({required this.postulacion, required this.onTap});

  final Map<String, dynamic> postulacion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final oferta = postulacion['oferta'] as Map<String, dynamic>? ?? {};
    final empresa = oferta['empresa'] as Map<String, dynamic>? ?? {};
    final modalidad = switch (oferta['modalidad']) {
      'REMOTO' => 'Remoto',
      'HIBRIDO' => 'Híbrido',
      'PRESENCIAL' => 'Presencial',
      _ => '',
    };
    final cv = postulacion['cv'];
    final tituloCv = cv is Map<String, dynamic>
        ? cv['titulo'] as String?
        : null;
    final porIa = postulacion['postuladoPorIa'] == true;
    final estado = postulacion['estado'] as String?;
    final (etiquetaEstado, varianteEstado) = _estadoCandidatura(estado);
    final fecha = DateTime.tryParse(
      postulacion['fechaPostulacion'] as String? ?? '',
    )?.toLocal();

    return ListRow(
      title: oferta['titulo'] as String? ?? 'Oferta',
      strongTitle: estado != 'RETIRADA',
      onTap: onTap,
      lines: [
        (empresa['nombre'] as String? ?? 'Empresa') +
            (modalidad.isEmpty ? '' : ' · $modalidad'),
        [
          porIa ? 'Por IA' : 'Manual',
          if (tituloCv != null) 'CV usado: $tituloCv',
          if (fecha != null) _antiguedad(fecha),
        ].join(' · '),
      ],
      trailing: StatusTag(label: etiquetaEstado, variant: varianteEstado),
    );
  }
}

/// Detalle de una candidatura. Aquí se ve por qué la IA la eligió y, si la
/// empresa aún no la ha revisado, se puede retirar. Se cierra con true si se
/// retiró.
class _DetalleCandidatura extends StatefulWidget {
  const _DetalleCandidatura({required this.postulacion, required this.service});

  final Map<String, dynamic> postulacion;
  final CandidatoService service;

  @override
  State<_DetalleCandidatura> createState() => _DetalleCandidaturaState();
}

class _DetalleCandidaturaState extends State<_DetalleCandidatura> {
  bool _retirando = false;
  String? _error;

  Future<void> _retirar() async {
    setState(() {
      _retirando = true;
      _error = null;
    });
    try {
      await widget.service.retirarPostulacion(
        widget.postulacion['id'] as String,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _retirando = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final postulacion = widget.postulacion;
    final oferta = postulacion['oferta'] as Map<String, dynamic>? ?? {};
    final empresa = oferta['empresa'] as Map<String, dynamic>? ?? {};
    final cv = postulacion['cv'];
    final tituloCv = cv is Map<String, dynamic> ? cv['titulo'] as String? : null;
    final estado = postulacion['estado'] as String?;
    final (etiqueta, variante) = _estadoCandidatura(estado);
    final porIa = postulacion['postuladoPorIa'] == true;
    final fecha = DateTime.tryParse(
      postulacion['fechaPostulacion'] as String? ?? '',
    )?.toLocal();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.micro,
          AppSpacing.screen,
          AppSpacing.screen,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(oferta['titulo'] as String? ?? 'Oferta', style: AppText.h1),
            const SizedBox(height: AppSpacing.micro),
            Text(
              empresa['nombre'] as String? ?? 'Empresa',
              style: AppText.mutedBody,
            ),
            const SizedBox(height: AppSpacing.gap),
            PanelList(
              children: [
                ListRow(
                  title: 'Estado',
                  trailing: StatusTag(label: etiqueta, variant: variante),
                ),
                ListRow(
                  title: 'Origen',
                  trailing: Text(
                    porIa ? 'Por IA' : 'Manual',
                    style: AppText.bodyStrong,
                  ),
                ),
                if (tituloCv != null)
                  ListRow(
                    title: 'CV usado',
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        tituloCv,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyStrong,
                      ),
                    ),
                  ),
                if (fecha != null)
                  ListRow(
                    title: 'Enviada',
                    trailing: Text(_antiguedad(fecha), style: AppText.bodyStrong),
                  ),
              ],
            ),
            if (porIa) ValoracionIa.deCandidatura(postulacion),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.gap),
              Notice(message: _error!, variant: StatusVariant.error),
            ],
            if (_sePuedeRetirar(estado)) ...[
              const SizedBox(height: AppSpacing.gap),
              Text(
                'Si la retiras, la empresa dejará de verla y el autopiloto no '
                'volverá a postular a esta oferta.',
                style: AppText.mutedBody,
              ),
              const SizedBox(height: AppSpacing.group),
              SecondaryButton(
                label: _retirando ? 'Retirando…' : 'Retirar candidatura',
                onPressed: _retirando ? null : _retirar,
              ),
            ] else if (estado != 'RETIRADA') ...[
              const SizedBox(height: AppSpacing.gap),
              Text(
                'La empresa ya ha revisado esta candidatura, así que no se '
                'puede retirar.',
                style: AppText.mutedBody,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
