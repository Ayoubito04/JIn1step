import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/candidato.service.dart';
import '../services/chat.service.dart';
import '../widgets/design_system.dart';
import 'mensajes.dart';
import 'mis_cvs.dart';

/// Texto visible de la modalidad (los valores reales son los del enum del
/// backend: REMOTO, HIBRIDO, PRESENCIAL).
String etiquetaModalidad(String valor) => switch (valor) {
  'REMOTO' => 'Remoto',
  'HIBRIDO' => 'Híbrido',
  'PRESENCIAL' => 'Presencial',
  _ => valor,
};

/// Resultado de cruzar los requisitos de una oferta con las habilidades del
/// CV principal. Lo comparten el listado y el detalle para que ambos muestren
/// exactamente las mismas cifras.
class MatchOferta {
  const MatchOferta({
    required this.score,
    required this.obligatoriasCubiertas,
    required this.obligatoriasTotal,
    required this.deseablesCubiertas,
    required this.deseablesTotal,
    required this.cubiertos,
    required this.faltantes,
  });

  final int score;
  final int obligatoriasCubiertas;
  final int obligatoriasTotal;
  final int deseablesCubiertas;
  final int deseablesTotal;

  /// Nombres de los requisitos que el CV ya cubre (obligatorios primero).
  final List<String> cubiertos;

  /// Requisitos que faltan (obligatorios primero).
  final List<({String nombre, bool obligatorio})> faltantes;

  static String normalizar(String nombre) =>
      nombre.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Habilidades (normalizadas) del CV principal. Lanza si la API falla.
  static Future<Set<String>> cargarHabilidadesCv(
    CandidatoService service,
  ) async {
    final cvs = await service.listarCvs();
    if (cvs.isEmpty) return <String>{};
    final habilidades = await service.listarHabilidadesCv(
      cvs.first['id'] as String,
    );
    return habilidades
        .map((item) => (item['habilidad'] as Map<String, dynamic>?)?['nombre'])
        .whereType<String>()
        .map(normalizar)
        .toSet();
  }

  factory MatchOferta.calcular(
    Map<String, dynamic> oferta,
    Set<String> habilidadesCv,
  ) {
    final requisitos = (oferta['requisitos'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    String? nombreDe(Map<String, dynamic> r) =>
        (r['habilidad'] as Map<String, dynamic>?)?['nombre'] as String?;
    final obligatorias = requisitos.where((r) => r['obligatorio'] != false);
    final deseables = requisitos.where((r) => r['obligatorio'] == false);

    final cubiertos = <String>[];
    final faltantes = <({String nombre, bool obligatorio})>[];
    int procesar(Iterable<Map<String, dynamic>> lista, bool obligatorio) {
      var cubiertas = 0;
      for (final requisito in lista) {
        final nombre = nombreDe(requisito);
        if (nombre == null) continue;
        if (habilidadesCv.contains(normalizar(nombre))) {
          cubiertas++;
          cubiertos.add(nombre);
        } else {
          faltantes.add((nombre: nombre, obligatorio: obligatorio));
        }
      }
      return cubiertas;
    }

    final cubiertasO = procesar(obligatorias, true);
    final cubiertasD = procesar(deseables, false);
    final totalO = obligatorias.length, totalD = deseables.length;
    final ratioO = totalO == 0 ? 1.0 : cubiertasO / totalO;
    final ratioD = totalD == 0 ? 1.0 : cubiertasD / totalD;
    return MatchOferta(
      score: totalO + totalD == 0 ? 0 : (ratioO * 70 + ratioD * 30).round(),
      obligatoriasCubiertas: cubiertasO,
      obligatoriasTotal: totalO,
      deseablesCubiertas: cubiertasD,
      deseablesTotal: totalD,
      cubiertos: cubiertos,
      faltantes: faltantes,
    );
  }
}

class OfertaDetalle extends StatefulWidget {
  const OfertaDetalle({super.key, required this.oferta, this.habilidadesCv});

  final Map<String, dynamic> oferta;

  /// Habilidades normalizadas del CV principal, si el listado ya las tiene.
  /// Si es null, el detalle las carga por su cuenta.
  final Set<String>? habilidadesCv;

  @override
  State<OfertaDetalle> createState() => _OfertaDetalleState();
}

class _OfertaDetalleState extends State<OfertaDetalle> {
  final _service = CandidatoService();
  final _chatService = ChatService();
  bool _cargando = false;
  Map<String, dynamic>? _postulacionExistente;
  String? _error;
  late Set<String>? _habilidadesCv = widget.habilidadesCv;

  String? get _ofertaId => widget.oferta['id'] as String?;

  Future<void> _contactarReclutador() async {
    final recruiter = widget.oferta['reclutador'] as Map<String, dynamic>?;
    final recruiterId = recruiter?['id'] as String?;
    if (recruiterId == null || _ofertaId == null) {
      setState(() => _error = 'No se pudo identificar al reclutador de esta oferta.');
      return;
    }
    try {
      final conversation = await _chatService.abrir(usuarioId: recruiterId, ofertaId: _ofertaId);
      final currentUser = conversation['candidato'] as Map<String, dynamic>?;
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatThreadPage(
        conversacion: {...conversation, 'interlocutor': conversation['reclutador'] ?? recruiter},
        usuarioId: currentUser?['id'] as String? ?? '',
      )));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    _comprobarPostulacionExistente();
    if (_habilidadesCv == null) _cargarHabilidadesCv();
  }

  Future<void> _cargarHabilidadesCv() async {
    try {
      final habilidades = await MatchOferta.cargarHabilidadesCv(_service);
      if (mounted) setState(() => _habilidadesCv = habilidades);
    } catch (_) {
      // Sin CV legible se muestra el match con cero habilidades cubiertas.
      if (mounted) setState(() => _habilidadesCv = <String>{});
    }
  }

  Future<void> _comprobarPostulacionExistente() async {
    final ofertaId = _ofertaId;
    if (ofertaId == null) return;
    try {
      final postulaciones = await _service.listarPostulaciones();
      for (final postulacion in postulaciones) {
        final oferta = postulacion['oferta'] as Map<String, dynamic>?;
        if (oferta?['id'] == ofertaId) {
          if (mounted) setState(() => _postulacionExistente = postulacion);
          return;
        }
      }
    } catch (_) {
      // El detalle sigue visible aunque el historial no pueda cargarse; el
      // endpoint de creación vuelve a proteger contra duplicados.
    }
  }

  Future<void> _postularse() async {
    if (_cargando || _ofertaId == null) return;
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final cvs = await _service.listarCvs();
      Map<String, dynamic>? cvSeleccionado;
      if (cvs.isEmpty) {
        if (!mounted) return;
        cvSeleccionado = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(builder: (_) => const MisCvsPage()),
        );
        if (cvSeleccionado == null) return;
      } else {
        if (!mounted) return;
        cvSeleccionado = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.micro,
                AppSpacing.screen,
                AppSpacing.screen,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Elegir el CV para esta candidatura'),
                  const SizedBox(height: AppSpacing.gap),
                  for (final cv in cvs) ...[
                    SecondaryButton(
                      label: cv['titulo'] as String? ?? 'Currículum',
                      leading: const Icon(Icons.description_outlined, size: 20),
                      onPressed: () => Navigator.pop(context, cv),
                    ),
                    const SizedBox(height: AppSpacing.group),
                  ],
                  SecondaryButton(
                    label: 'Subir otro CV',
                    leading: const Icon(Icons.add, size: 20),
                    onPressed: () async {
                      final nuevo = await Navigator.of(context)
                          .push<Map<String, dynamic>>(
                            MaterialPageRoute(
                              builder: (_) => const MisCvsPage(),
                            ),
                          );
                      if (context.mounted && nuevo != null) {
                        Navigator.pop(context, nuevo);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
        if (cvSeleccionado == null) return;
      }

      final resultado = await _service.postular(
        ofertaId: _ofertaId!,
        cvId: cvSeleccionado['id'] as String,
      );
      if (!mounted) return;
      setState(() => _postulacionExistente = resultado);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Tu candidatura se ha enviado!')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final oferta = widget.oferta;
    final empresa = oferta['empresa'] as Map<String, dynamic>?;
    final titulo = oferta['titulo'] as String? ?? 'Oferta';
    final nombreEmpresa = empresa?['nombre'] as String?;
    final modalidad = oferta['modalidad'] as String?;
    final subtitulo = [
      ?nombreEmpresa,
      if (modalidad != null) etiquetaModalidad(modalidad),
    ].join(' · ');
    final hayRequisitos = (oferta['requisitos'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .isNotEmpty;
    final estaAbierta =
        oferta['estado'] == null || oferta['estado'] == 'ABIERTA';
    final yaPostulada = _postulacionExistente != null;
    final habilidades = _habilidadesCv;
    final match = habilidades == null
        ? null
        : MatchOferta.calcular(oferta, habilidades);

    final puedePostular =
        !_cargando && !yaPostulada && estaAbierta && hayRequisitos;
    final etiquetaPostular = yaPostulada
        ? 'Ya te has postulado'
        : !hayRequisitos
        ? 'Pendiente de requisitos'
        : !estaAbierta
        ? 'Oferta cerrada'
        : 'Postular con mi CV';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AppIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Volver a ofertas',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(height: AppSpacing.gap),
            ScreenHeader(
              title: titulo,
              subtitle: subtitulo.isEmpty ? null : subtitulo,
            ),
            const SizedBox(height: AppSpacing.gap),
            if (match == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: AppSpinner(size: 24)),
              )
            else ...[
              _bloqueMatch(match),
              const SizedBox(height: AppSpacing.gap),
              _requisitos(habilidades!, hayRequisitos),
            ],
            const SizedBox(height: AppSpacing.gap),
            if (_error != null) ...[
              Notice(message: _error!, variant: StatusVariant.error),
              const SizedBox(height: AppSpacing.gap),
            ],
            if (puedePostular || _cargando)
              PrimaryButton(
                label: etiquetaPostular,
                loading: _cargando,
                loadingLabel: 'Enviando candidatura…',
                onPressed: _postularse,
              )
            else
              SecondaryButton(label: etiquetaPostular, onPressed: null),
            const SizedBox(height: AppSpacing.group),
            SecondaryButton(
              label: 'Escribir al reclutador',
              onPressed: _contactarReclutador,
            ),
          ],
        ),
      ),
    );
  }

  /// Match grande con sus pasos y el desglose obligatorias / deseables.
  Widget _bloqueMatch(MatchOferta match) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Match del ${match.score} %',
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${match.score} %', style: AppText.display),
                const SizedBox(width: AppSpacing.gap),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.micro),
                  child: Steps(filled: pasosDeMatch(match.score), animar: true),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.group),
        Text(
          'de match con tu CV principal. Obligatorias 70 %, deseables 30 %.',
          style: AppText.mutedBody,
        ),
        const SizedBox(height: AppSpacing.gap),
        const Divider(),
        _FilaCifra(
          etiqueta: 'Obligatorias',
          cubiertas: match.obligatoriasCubiertas,
          total: match.obligatoriasTotal,
        ),
        const Divider(),
        _FilaCifra(
          etiqueta: 'Deseables',
          cubiertas: match.deseablesCubiertas,
          total: match.deseablesTotal,
        ),
      ],
    ),
  );

  /// Lista de requisitos en un solo panel: Cubierto / Falta por fila.
  Widget _requisitos(Set<String> habilidades, bool hayRequisitos) {
    if (!hayRequisitos) {
      return SizedBox(
        width: double.infinity,
        child: Panel(
          child: Text(
            'Esta oferta todavía no tiene requisitos definidos.',
            style: AppText.mutedBody,
          ),
        ),
      );
    }
    final requisitos = (widget.oferta['requisitos'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (r) => (
            nombre: (r['habilidad'] as Map<String, dynamic>?)?['nombre']
                as String?,
            obligatorio: r['obligatorio'] != false,
          ),
        )
        .where((r) => r.nombre != null)
        .toList()
      ..sort((a, b) => a.obligatorio == b.obligatorio
          ? 0
          : a.obligatorio
          ? -1
          : 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Requisitos'),
        const SizedBox(height: AppSpacing.group),
        PanelList(
          children: [
            for (final r in requisitos)
              ListRow(
                title: r.nombre!,
                lines: [r.obligatorio ? 'Obligatoria' : 'Deseable'],
                strongTitle: false,
                trailing: habilidades.contains(MatchOferta.normalizar(r.nombre!))
                    ? const StatusTag(
                        label: 'Cubierto',
                        variant: StatusVariant.success,
                      )
                    : const StatusTag(
                        label: 'Falta',
                        variant: StatusVariant.error,
                      ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Fila «Obligatorias · 3 de 4» dentro del panel del match.
class _FilaCifra extends StatelessWidget {
  const _FilaCifra({
    required this.etiqueta,
    required this.cubiertas,
    required this.total,
  });

  final String etiqueta;
  final int cubiertas;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.group),
    child: Row(
      children: [
        Expanded(child: Text(etiqueta, style: AppText.body)),
        const SizedBox(width: AppSpacing.group),
        Text('$cubiertas de $total', style: AppText.numInline),
      ],
    ),
  );
}
