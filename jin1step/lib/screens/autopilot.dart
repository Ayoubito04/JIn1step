import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../services/candidato.service.dart';
import '../widgets/design_system.dart';
import '../widgets/valoracion_ia.dart';
import 'mis_cvs.dart';
import 'mis_postulaciones.dart';

/// Autopiloto: consentimiento, ajustes, propuestas por revisar (modo
/// «Revisar antes de enviar»), cupo diario, historial de ejecuciones y las
/// últimas candidaturas enviadas por IA.
class AutopilotPage extends StatefulWidget {
  const AutopilotPage({super.key, this.mostrarAtras = false, this.service});

  final bool mostrarAtras;

  /// Opcional para poder inyectar un servicio falso en los tests.
  final CandidatoService? service;

  @override
  State<AutopilotPage> createState() => _AutopilotPageState();
}

/// Cuántas ejecuciones se ven de entrada y cuántas al desplegar el historial.
const _historialVisible = 5;

class _AutopilotPageState extends State<AutopilotPage> {
  late final CandidatoService _service = widget.service ?? CandidatoService();
  final _scrollController = ScrollController();
  bool _cargando = true;
  bool _guardando = false;
  bool _ejecutando = false;
  bool _enviandoTodas = false;
  bool _activo = false;
  // Modo por defecto: el autopiloto propone y el usuario decide.
  bool _revisarAntes = true;
  bool _suscripcionActiva = false;
  String? _plan;
  String? _cvId;
  double _scoreMinimo = 70;
  int _maxPorDia = 5;
  List<Map<String, dynamic>> _cvs = [];
  // Todas las candidaturas creadas por la IA (propuestas incluidas).
  List<Map<String, dynamic>> _postulacionesIa = [];
  List<Map<String, dynamic>> _historial = [];
  bool _historialCompleto = false;
  // Error del interruptor y de los ajustes: se pinta junto a ellos, no al final.
  String? _errorAjustes;
  // Resultado de resolver propuestas: se pinta bajo la lista de propuestas.
  String? _avisoPropuestas;
  StatusVariant _varianteAviso = StatusVariant.success;
  // Resultado de «Ejecutar autopiloto»: se pinta encima del botón.
  String? _error;
  String? _mensaje;
  bool _mostrarEnlaceEnviadasEnMensaje = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorAjustes = null;
    });
    try {
      final resultados = await Future.wait<Object?>([
        _service.obtenerPreferenciasAutopilot(),
        _service.listarCvs(),
        _service.obtenerSuscripcionActiva(),
        _service.listarPostulaciones().catchError(
          (_) => <Map<String, dynamic>>[],
        ),
        _service.obtenerHistorialAutopilot().catchError(
          (_) => <Map<String, dynamic>>[],
        ),
      ]);
      final preferencias = resultados[0] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _cvs = resultados[1] as List<Map<String, dynamic>>;
        _suscripcionActiva = resultados[2] != null;
        _plan = (resultados[2] as Map<String, dynamic>?)?['tipoPlan'] as String?;
        _postulacionesIa = _soloIa(resultados[3] as List<Map<String, dynamic>>);
        _historial = resultados[4] as List<Map<String, dynamic>>;
        _activo = preferencias['activo'] as bool? ?? false;
        _revisarAntes = preferencias['revisarAntes'] as bool? ?? true;
        _cvId = preferencias['cvId'] as String?;
        _scoreMinimo = ((preferencias['scoreMinimo'] as num?)?.toDouble() ?? 70)
            .clamp(0, 100)
            .toDouble();
        _maxPorDia = ((preferencias['maxPorDia'] as num?)?.toInt() ?? 5)
            .clamp(1, 20)
            .toInt();
      });
    } catch (error) {
      if (mounted) setState(() => _errorAjustes = _textoError(error));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<Map<String, dynamic>> _soloIa(List<Map<String, dynamic>> todas) {
    final ia = todas.where((item) => item['postuladoPorIa'] == true).toList();
    ia.sort((a, b) => _fecha(b).compareTo(_fecha(a)));
    return ia;
  }

  DateTime _fecha(Map<String, dynamic> postulacion) =>
      DateTime.tryParse(postulacion['fechaPostulacion'] as String? ?? '')
          ?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  bool _esDeHoy(Map<String, dynamic> postulacion) {
    final ahora = DateTime.now();
    final medianoche = DateTime(ahora.year, ahora.month, ahora.day);
    return !_fecha(postulacion).isBefore(medianoche);
  }

  /// Candidaturas que el autopiloto creó hoy (sin contar propuestas descartadas).
  int get _cupoHoy => _postulacionesIa
      .where((p) => _esDeHoy(p) && p['estado'] != 'DESCARTADA')
      .length;

  /// Valor mostrado sobre el límite diario actual: evita fracciones incoherentes
  /// como «20 / 10» cuando el usuario reduce «Máximo al día» después de haber
  /// ejecutado el autopiloto.
  int get _cupoHoyMostrado => _cupoHoy.clamp(0, _maxPorDia);

  /// Enviadas de verdad hoy (sin propuestas pendientes ni descartadas).
  int get _enviadasHoy => _postulacionesIa
      .where((p) => _esDeHoy(p) && esCandidaturaEnviada(p))
      .length;

  /// Propuestas esperando decisión, de mayor a menor encaje.
  List<Map<String, dynamic>> get _propuestas {
    final lista = _postulacionesIa
        .where((p) => p['estado'] == 'PROPUESTA')
        .toList();
    lista.sort((a, b) => _encaje(b).compareTo(_encaje(a)));
    return lista;
  }

  num _encaje(Map<String, dynamic> p) =>
      (p['puntuacionIa'] as num?) ?? (p['matchScore'] as num?) ?? 0;

  /// Pasos llenos del cupo diario: proporcional al máximo configurado
  /// (3 llenos de 5 = 3 de 5 hoy cuando el máximo es 5).
  int get _pasosCupo =>
      _maxPorDia <= 0 ? 0 : (_cupoHoy * 5 / _maxPorDia).ceil().clamp(0, 5);

  /// Las retiradas siguen contando para el tope diario (así lo cuenta el
  /// servidor), pero ya no son «enviadas»: no salen en la lista.
  List<Map<String, dynamic>> get _enviadasVigentes => _postulacionesIa
      .where((p) => esCandidaturaEnviada(p) && p['estado'] != 'RETIRADA')
      .toList();

  Future<void> _verCandidaturaEnviada(Map<String, dynamic> postulacion) async {
    final id = postulacion['id'];
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MisPostulacionesPage(
          postulacionId: id is String ? id : null,
          filtroInicial: 'Por IA',
        ),
      ),
    );
    await _refrescarTodo();
  }

  void _desplazarArriba() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (reduce(context)) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(
          0,
          duration: Motion.slow,
          curve: Motion.easeOut,
        );
      }
    });
  }

  Future<void> _verTodasPorIa() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const MisPostulacionesPage(filtroInicial: 'Por IA'),
      ),
    );
    // Puede haber retirado alguna: se vuelve a leer.
    await _refrescarTodo();
  }

  Future<void> _refrescarPostulaciones() async {
    try {
      final todas = await _service.listarPostulaciones();
      if (mounted) setState(() => _postulacionesIa = _soloIa(todas));
    } catch (_) {
      // El contador es informativo: si falla, se conserva el último valor.
    }
  }

  Future<void> _refrescarHistorial() async {
    try {
      final historial = await _service.obtenerHistorialAutopilot();
      if (mounted) setState(() => _historial = historial);
    } catch (_) {
      // El historial es informativo: si falla, se conserva el último.
    }
  }

  /// Propuestas, cupo e historial tras ejecutar o resolver propuestas.
  Future<void> _refrescarTodo() async {
    await _refrescarPostulaciones();
    await _refrescarHistorial();
  }

  Future<void> _seleccionarCv() async {
    final cv = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const MisCvsPage()),
    );
    if (cv != null && mounted) {
      setState(() {
        _cvId = cv['id'] as String?;
        if (!_cvs.any((item) => item['id'] == _cvId)) _cvs = [..._cvs, cv];
      });
      await _guardar();
    }
  }

  Future<void> _guardar() async {
    if (_cvId == null) {
      setState(() => _errorAjustes = 'Elige un CV para guardar estos ajustes.');
      return;
    }
    setState(() {
      _guardando = true;
      _errorAjustes = null;
    });
    try {
      await _service.guardarPreferenciasAutopilot({
        'cvId': _cvId,
        'scoreMinimo': _scoreMinimo.round(),
        'maxPorDia': _maxPorDia,
      });
    } catch (error) {
      if (mounted) setState(() => _errorAjustes = _textoError(error));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cambiarRevision(bool revisar) async {
    setState(() {
      _guardando = true;
      _errorAjustes = null;
    });
    try {
      await _service.guardarPreferenciasAutopilot({'revisarAntes': revisar});
      if (mounted) setState(() => _revisarAntes = revisar);
    } catch (error) {
      if (mounted) setState(() => _errorAjustes = _textoError(error));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cambiarActivacion(bool activar) async {
    if (activar && !_suscripcionActiva) {
      setState(
        () => _errorAjustes =
            'Necesitas una suscripción activa para usar el autopiloto.',
      );
      return;
    }
    if (activar && _cvId == null) {
      setState(
        () => _errorAjustes = 'Elige un CV antes de activar el autopiloto.',
      );
      return;
    }
    setState(() {
      _guardando = true;
      _errorAjustes = null;
    });
    try {
      await _service.guardarPreferenciasAutopilot({
        'activo': activar,
        'cvId': _cvId,
        'scoreMinimo': _scoreMinimo.round(),
        'maxPorDia': _maxPorDia,
      });
      if (mounted) setState(() => _activo = activar);
    } catch (error) {
      if (mounted) setState(() => _errorAjustes = _textoError(error));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _ejecutarAhora() async {
    if (!_suscripcionActiva) {
      setState(() {
        _mensaje = null;
        _mostrarEnlaceEnviadasEnMensaje = false;
        _error = 'Necesitas una suscripción activa para usar el autopiloto.';
      });
      return;
    }
    if (!_activo) {
      setState(() {
        _mensaje = null;
        _mostrarEnlaceEnviadasEnMensaje = false;
        _error = 'Activa «Postular por mí» para ejecutar el autopiloto.';
      });
      return;
    }
    setState(() {
      _ejecutando = true;
      _error = null;
      _mensaje = null;
      _mostrarEnlaceEnviadasEnMensaje = false;
    });
    try {
      final resultado = await _service.ejecutarAutopilot();
      final creadas = (resultado['creadas'] as num?)?.toInt() ?? 0;
      final motivo = resultado['motivo'] as String?;
      // El modo lo dice el servidor; si no viniera, el de los ajustes.
      final revision = resultado['modo'] != null
          ? resultado['modo'] == 'REVISION'
          : _revisarAntes;
      await _refrescarTodo();
      if (mounted) {
        setState(() {
          _mostrarEnlaceEnviadasEnMensaje = creadas > 0 && !revision;
          _mensaje = creadas > 0
              ? (revision
                    ? 'Hay $creadas ${creadas == 1 ? 'propuesta nueva' : 'propuestas nuevas'} para revisar. Toca cada oferta en «Propuestas para revisar» para leer la carta y enviarla, o pulsa «Enviar todas».'
                    : 'Se enviaron $creadas ${creadas == 1 ? 'candidatura' : 'candidaturas'} automáticamente. Toca cualquiera en «Últimas enviadas por IA» para seguir su estado.')
              : _textoMotivo(motivo);
        });
        if (creadas > 0 && revision) {
          _desplazarArriba();
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = _textoError(error));
    } finally {
      if (mounted) setState(() => _ejecutando = false);
    }
  }

  Future<void> _abrirPropuesta(Map<String, dynamic> propuesta) async {
    final resultado = await showModalBottomSheet<_ResultadoPropuesta>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _DetallePropuesta(postulacion: propuesta, service: _service),
    );
    // Aunque se cierre sin decidir, el servidor puede haberla cerrado (oferta
    // cerrada): se vuelve a leer.
    await _refrescarTodo();
    if (resultado == null || !mounted) return;
    if (resultado == _ResultadoPropuesta.enviada) {
      setState(() {
        _varianteAviso = StatusVariant.success;
        _avisoPropuestas =
            'Candidatura enviada. Puedes consultar su estado o retirarla desde «Últimas enviadas por IA» o en «Mis candidaturas».';
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado == _ResultadoPropuesta.enviada
              ? 'Candidatura enviada.'
              : 'Propuesta descartada.',
        ),
      ),
    );
  }

  Future<void> _enviarTodas() async {
    final pendientes = _propuestas;
    setState(() {
      _enviandoTodas = true;
      _avisoPropuestas = null;
    });
    var enviadas = 0;
    var fallos = 0;
    String? primerMotivo;
    for (final propuesta in pendientes) {
      try {
        await _service.aprobarPostulacion(propuesta['id'] as String);
        enviadas++;
      } catch (error) {
        fallos++;
        primerMotivo ??= error.toString();
      }
    }
    await _refrescarTodo();
    if (!mounted) return;
    setState(() {
      _enviandoTodas = false;
      if (fallos == 0) {
        _varianteAviso = StatusVariant.success;
        _avisoPropuestas =
            'Se enviaron $enviadas ${enviadas == 1 ? 'candidatura' : 'candidaturas'}.';
      } else {
        _varianteAviso = enviadas == 0
            ? StatusVariant.error
            : StatusVariant.warning;
        _avisoPropuestas =
            '${enviadas == 0 ? 'No se envió ninguna' : 'Se enviaron $enviadas'}. '
            'No se pudieron enviar $fallos: $primerMotivo';
      }
    });
  }

  String _textoMotivo(String? motivo) => switch (motivo) {
    'limite_diario_alcanzado' => 'Ya alcanzaste el límite diario del autopiloto.',
    'propuestas_pendientes' =>
      'Tienes propuestas sin revisar. Revísalas antes de buscar más.',
    'sin_ofertas_disponibles' =>
      'Ya te postulaste a todas las ofertas abiertas disponibles.',
    'sin_ofertas_sobre_score_minimo' =>
      'No hay nuevas ofertas que alcancen tu compatibilidad mínima.',
    _ => 'No hay ofertas nuevas que proponer.',
  };

  String _textoError(Object error) {
    if (error is ApiException) {
      if (error.status == 402) {
        return 'Necesitas una suscripción activa para usar el autopiloto.';
      }
      if (error.status == 409) {
        return 'Selecciona un CV activo para el autopiloto.';
      }
    }
    return error.toString();
  }

  String get _textoSuscripcion {
    if (!_suscripcionActiva) return 'Sin suscripción';
    return switch (_plan) {
      'MENSUAL' => 'Plan mensual',
      'ANUAL' => 'Plan anual',
      _ => 'Suscripción activa',
    };
  }

  String? get _tituloCv {
    for (final cv in _cvs) {
      if (cv['id'] == _cvId) return cv['titulo'] as String? ?? 'Currículum';
    }
    return null;
  }

  String _hace(DateTime fecha) {
    final diferencia = DateTime.now().difference(fecha);
    if (diferencia.inMinutes < 1) return 'hace un momento';
    if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
    if (diferencia.inHours < 24) return 'hace ${diferencia.inHours} h';
    return 'hace ${diferencia.inDays} d';
  }

  /// «Hoy 09:00», «Ayer 09:00» o «3/11 09:00».
  String _cuando(DateTime fecha) {
    final ahora = DateTime.now();
    final dias = DateTime(ahora.year, ahora.month, ahora.day)
        .difference(DateTime(fecha.year, fecha.month, fecha.day))
        .inDays;
    final hora =
        '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    if (dias == 0) return 'Hoy $hora';
    if (dias == 1) return 'Ayer $hora';
    return '${fecha.day}/${fecha.month} $hora';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _cargando
            ? const Center(child: AppSpinner(size: 24))
            : ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSpacing.screen),
                children: [
                  _cabecera(),
                  const SizedBox(height: AppSpacing.gap),
                  _panelConsentimiento(),
                  if (_errorAjustes != null) ...[
                    const SizedBox(height: AppSpacing.group),
                    Notice(message: _errorAjustes!, variant: StatusVariant.error),
                  ],
                  if (_propuestas.isNotEmpty || _avisoPropuestas != null) ...[
                    const SizedBox(height: AppSpacing.gap),
                    _seccionPropuestas(),
                  ],
                  const SizedBox(height: AppSpacing.gap),
                  _panelAjustes(),
                  const SizedBox(height: AppSpacing.gap),
                  _panelHoy(),
                  const SizedBox(height: AppSpacing.gap),
                  const SectionTitle('Historial'),
                  const SizedBox(height: AppSpacing.group),
                  _listaHistorial(),
                  const SizedBox(height: AppSpacing.gap),
                  const SectionTitle('Últimas enviadas por IA'),
                  const SizedBox(height: AppSpacing.group),
                  _listaUltimas(),
                  if (_mensaje != null) ...[
                    const SizedBox(height: AppSpacing.gap),
                    Notice(message: _mensaje!, variant: StatusVariant.success),
                    if (_mostrarEnlaceEnviadasEnMensaje) ...[
                      const SizedBox(height: AppSpacing.micro),
                      LinkAction(
                        label: 'Ver mis candidaturas enviadas por IA',
                        onTap: _verTodasPorIa,
                      ),
                    ],
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.gap),
                    Notice(message: _error!, variant: StatusVariant.error),
                  ],
                  const SizedBox(height: AppSpacing.gap),
                  _botonEjecutar(),
                ],
              ),
      ),
    );
  }

  Widget _botonEjecutar() {
    final usadas = _cupoHoyMostrado;
    final restantes = (_maxPorDia - _cupoHoy).clamp(0, _maxPorDia);
    final sinCupo = restantes == 0;

    final etiqueta = sinCupo
        ? (_maxPorDia >= 20
              ? 'Límite máximo de 20 ofertas/día alcanzado'
              : 'Cupo diario completado ($usadas/$_maxPorDia)')
        : usadas == 0
        ? 'Ejecutar autopiloto (hasta $_maxPorDia hoy)'
        : 'Buscar hasta $restantes ${restantes == 1 ? 'oferta más' : 'ofertas más'} hoy ($usadas/$_maxPorDia usadas)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(
          label: etiqueta,
          loading: _ejecutando,
          loadingLabel: 'Buscando ofertas…',
          onPressed: sinCupo ? null : _ejecutarAhora,
        ),
        const SizedBox(height: AppSpacing.micro),
        Text(
          sinCupo
              ? (_maxPorDia >= 20
                    ? 'Ya has utilizado las 20 candidaturas máximas permitidas hoy. Mañana se renovará tu cupo.'
                    : 'Ya has alcanzado tu tope de $_maxPorDia hoy (el límite máximo del sistema es de 20 ofertas en total por día).')
              : 'Recuerda: el tope total es de $_maxPorDia ${ _maxPorDia == 1 ? 'oferta' : 'ofertas'} al día (máx. 20/día en el sistema). Hoy te ${restantes == 1 ? 'queda 1 candidatura disponible' : 'quedan $restantes candidaturas disponibles'}.',
          textAlign: TextAlign.center,
          style: AppText.meta,
        ),
      ],
    );
  }

  Widget _cabecera() {
    final pendientes = _propuestas.length;
    final hoy = _enviadasHoy;
    final usadas = _cupoHoyMostrado;
    final restantes = (_maxPorDia - _cupoHoy).clamp(0, _maxPorDia);
    final frase = restantes == 0
        ? 'Has completado tu cupo de hoy ($usadas/$_maxPorDia · máx. 20 ofertas/día).'
        : pendientes > 0
        ? 'Llevas $usadas de $_maxPorDia hoy ($pendientes por revisar · te ${restantes == 1 ? 'queda 1 disponible' : 'quedan $restantes disponibles'}).'
        : hoy == 0
        ? 'Hoy tienes hasta $_maxPorDia candidaturas disponibles (máximo 20 ofertas por día).'
        : 'Hoy llevas $hoy ${hoy == 1 ? 'enviada' : 'enviadas'} de $_maxPorDia · Te ${restantes == 1 ? 'queda 1 disponible' : 'quedan $restantes disponibles'} hoy.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.mostrarAtras) ...[
          AppIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: AppSpacing.group),
        ],
        ScreenHeader(
          title: 'Autopiloto',
          subtitle: frase,
          trailing: StatusTag(
            label: _textoSuscripcion,
            variant: _suscripcionActiva
                ? StatusVariant.success
                : StatusVariant.warning,
          ),
        ),
      ],
    );
  }

  Widget _panelConsentimiento() => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Postular por mí', style: AppText.h2)),
            AppSwitch(
              value: _activo,
              label: 'Postular por mí',
              // Sin suscripción no se puede activar: se explica aquí mismo en
              // vez de dejar un interruptor que falla al tocarlo.
              onChanged: _guardando || (!_suscripcionActiva && !_activo)
                  ? null
                  : _cambiarActivacion,
            ),
          ],
        ),
        Text(
          'Autorizas al autopiloto a enviar candidaturas en tu nombre con el CV que elijas. Puedes apagarlo cuando quieras.',
          style: AppText.mutedBody,
        ),
        if (!_suscripcionActiva) ...[
          const SizedBox(height: AppSpacing.group),
          Text(
            'Necesitas una suscripción activa para activarlo.',
            style: AppText.bodyStrong,
          ),
        ],
      ],
    ),
  );

  Widget _seccionPropuestas() {
    final propuestas = _propuestas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (propuestas.isNotEmpty) ...[
          SectionTitle(
            'Propuestas para revisar',
            trailing: Text('${propuestas.length}', style: AppText.numInline),
          ),
          const SizedBox(height: AppSpacing.micro),
          Text(
            'Toca una oferta para leer la carta de la IA y decidir si enviarla, o envíalas todas en un paso.',
            style: AppText.mutedBody,
          ),
          const SizedBox(height: AppSpacing.group),
          PanelList(
            children: [
              for (final propuesta in propuestas) _filaPropuesta(propuesta),
            ],
          ),
          if (propuestas.length > 1) ...[
            const SizedBox(height: AppSpacing.group),
            SecondaryButton(
              label: _enviandoTodas
                  ? 'Enviando…'
                  : 'Enviar todas (${propuestas.length})',
              onPressed: _enviandoTodas ? null : _enviarTodas,
            ),
          ],
        ],
        if (_avisoPropuestas != null) ...[
          const SizedBox(height: AppSpacing.group),
          Notice(message: _avisoPropuestas!, variant: _varianteAviso),
          if (_varianteAviso != StatusVariant.error) ...[
            const SizedBox(height: AppSpacing.micro),
            LinkAction(
              label: 'Ver mis candidaturas enviadas por IA',
              onTap: _verTodasPorIa,
            ),
          ],
        ],
      ],
    );
  }

  Widget _filaPropuesta(Map<String, dynamic> propuesta) {
    final oferta = propuesta['oferta'] as Map<String, dynamic>? ?? {};
    final empresa = oferta['empresa'] as Map<String, dynamic>?;
    final salario = (oferta['salario'] as String?)?.trim();
    final motivo = (propuesta['motivoIa'] as String?)?.trim();
    final lineaEmpresa = [
      empresa?['nombre'] as String? ?? 'Empresa',
      if (salario != null && salario.isNotEmpty) salario,
    ].join(' · ');
    return ListRow(
      title: oferta['titulo'] as String? ?? 'Oferta',
      lines: [
        lineaEmpresa,
        if (motivo != null && motivo.isNotEmpty)
          motivo.length > 110 ? '${motivo.substring(0, 107)}…' : motivo,
      ],
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const StatusTag(label: 'Revisar', variant: StatusVariant.warning),
          const SizedBox(width: AppSpacing.group),
          MatchIndicator(match: _encaje(propuesta)),
        ],
      ),
      onTap: () => _abrirPropuesta(propuesta),
    );
  }

  Widget _panelAjustes() => PanelList(
    children: [
      ListRow(
        title: 'CV que se usa',
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            _tituloCv ?? 'Elegir',
            overflow: TextOverflow.ellipsis,
            style: AppText.bodyStrong.copyWith(color: AppColors.data),
          ),
        ),
        onTap: _seleccionarCv,
      ),
      ListRow(
        title: 'Revisar antes de enviar',
        lines: const [
          'El autopiloto te propone ofertas y tú decides cuáles se envían.',
        ],
        trailing: AppSwitch(
          value: _revisarAntes,
          label: 'Revisar antes de enviar',
          onChanged: _guardando ? null : _cambiarRevision,
        ),
      ),
      _AjusteDeslizable(
        etiqueta: 'Puntuación mínima',
        valor: '${_scoreMinimo.round()} %',
        slider: _scoreMinimo,
        min: 0,
        max: 100,
        divisiones: 20,
        onChanged: (v) => setState(() => _scoreMinimo = v),
        onChangeEnd: (_) => _guardar(),
      ),
      _AjusteDeslizable(
        etiqueta: 'Límite total diario (máx. 20 ofertas)',
        valor: '$_maxPorDia / día',
        subtitulo:
            'Tope absoluto de 20 ofertas por día en total (incluye enviadas y propuestas de hoy; no se suman 20 nuevas en cada ejecución).',
        slider: _maxPorDia.toDouble(),
        min: 1,
        max: 20,
        divisiones: 19,
        onChanged: (v) => setState(() => _maxPorDia = v.round()),
        onChangeEnd: (_) => _guardar(),
      ),
    ],
  );

  Widget _panelHoy() {
    final usadas = _cupoHoyMostrado;
    final restantes = (_maxPorDia - _cupoHoy).clamp(0, _maxPorDia);
    final pendientes = _propuestas.length;
    final enviadasHoy = _enviadasHoy;
    final textoHoy = restantes == 0
        ? (_maxPorDia >= 20
              ? 'Has alcanzado el tope máximo de 20 ofertas de empleo por hoy. El sistema solo permite hasta 20 candidaturas diarias en total; mañana a las 00:00 volverás a tener cupo disponible.'
              : 'Has completado tu límite configurado de $_maxPorDia ${_maxPorDia == 1 ? 'candidatura' : 'candidaturas'} de hoy. El tope máximo del sistema es de 20 ofertas totales al día (puedes subir el deslizador hasta 20 para disponer de ${20 - _cupoHoy} más hoy).')
        : usadas == 0
        ? 'Puedes postular como máximo a $_maxPorDia ${_maxPorDia == 1 ? 'oferta' : 'ofertas'} en total durante todo el día de hoy (el límite máximo del sistema es de 20 al día).'
        : 'De tu tope de $_maxPorDia ofertas para hoy ya has utilizado $usadas (${enviadasHoy > 0 ? '$enviadasHoy ${enviadasHoy == 1 ? 'enviada' : 'enviadas'}' : ''}${enviadasHoy > 0 && pendientes > 0 ? ' y ' : ''}${pendientes > 0 ? '$pendientes en revisión' : ''}). Solo puedes generar hasta $restantes ${restantes == 1 ? 'oferta más' : 'ofertas más'} en lo que queda de día.';

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Cupo de hoy (máx. 20/día)', style: AppText.h2),
              ),
              Semantics(
                label: '$usadas de $_maxPorDia del cupo de hoy',
                excludeSemantics: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$usadas / $_maxPorDia usadas',
                      style: AppText.numInline,
                    ),
                    const SizedBox(width: AppSpacing.group),
                    Steps(filled: _pasosCupo, animar: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.group),
          Wrap(
            spacing: AppSpacing.group,
            runSpacing: AppSpacing.group,
            children: [
              StatusTag(
                label:
                    'Restantes hoy: $restantes de $_maxPorDia',
                variant: restantes == 0
                    ? StatusVariant.warning
                    : StatusVariant.success,
              ),
              StatusTag(label: 'Enviadas hoy: $enviadasHoy'),
              if (pendientes > 0)
                StatusTag(
                  label: 'Por revisar: $pendientes',
                  variant: StatusVariant.warning,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.group),
          Text(textoHoy, style: AppText.mutedBody),
        ],
      ),
    );
  }

  Widget _listaHistorial() {
    if (_historial.isEmpty) {
      return Panel(
        child: Text(
          'Todavía no se ha ejecutado el autopiloto.',
          style: AppText.mutedBody,
        ),
      );
    }
    final visibles = _historialCompleto
        ? _historial
        : _historial.take(_historialVisible).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PanelList(children: [for (final e in visibles) _filaHistorial(e)]),
        if (_historial.length > _historialVisible) ...[
          const SizedBox(height: AppSpacing.group),
          LinkAction(
            label: _historialCompleto
                ? 'Ver menos historial'
                : 'Ver todo el historial',
            onTap: () => setState(() => _historialCompleto = !_historialCompleto),
          ),
        ],
      ],
    );
  }

  Widget _filaHistorial(Map<String, dynamic> ejecucion) {
    final fecha = DateTime.tryParse(ejecucion['fecha'] as String? ?? '')
        ?.toLocal();
    final origen = ejecucion['origen'] == 'DIARIA' ? 'Diaria' : 'Manual';
    final evaluadas = (ejecucion['evaluadas'] as num?)?.toInt() ?? 0;
    final propuestas = (ejecucion['propuestas'] as num?)?.toInt() ?? 0;
    final enviadas = (ejecucion['enviadas'] as num?)?.toInt() ?? 0;
    final motivo = ejecucion['motivo'] as String?;
    final via = ejecucion['via'] as String?;
    return ListRow(
      title: fecha == null ? origen : '${_cuando(fecha)} · $origen',
      lines: [
        [
          'Evaluó $evaluadas',
          if (propuestas > 0) 'Propuso $propuestas',
          if (enviadas > 0) 'Envió $enviadas',
        ].join(' · '),
        if (propuestas == 0 && enviadas == 0 && motivo != null)
          _textoMotivo(motivo),
      ],
      trailing: via == null
          ? null
          : StatusTag(label: via == 'ia' ? 'IA' : 'Por habilidades'),
    );
  }

  Widget _listaUltimas() {
    final vigentes = _enviadasVigentes;
    if (vigentes.isEmpty) {
      return Panel(
        child: Text(
          'Aún no hay candidaturas enviadas por IA.',
          style: AppText.mutedBody,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Toca una candidatura para ver su estado, la valoración de la IA o retirarla.',
          style: AppText.mutedBody,
        ),
        const SizedBox(height: AppSpacing.group),
        PanelList(
          children: [
            for (final postulacion in vigentes.take(3)) _filaEnviada(postulacion),
          ],
        ),
        const SizedBox(height: AppSpacing.group),
        LinkAction(
          label: 'Ver todas las enviadas por IA',
          onTap: _verTodasPorIa,
        ),
      ],
    );
  }

  Widget _filaEnviada(Map<String, dynamic> postulacion) {
    final oferta = postulacion['oferta'] as Map<String, dynamic>? ?? {};
    final empresa = oferta['empresa'] as Map<String, dynamic>?;
    final nombreEmpresa = empresa?['nombre'] as String?;
    final cuando = _hace(_fecha(postulacion));
    return ListRow(
      title: oferta['titulo'] as String? ?? 'Oferta',
      lines: [nombreEmpresa == null ? cuando : '$nombreEmpresa · $cuando'],
      trailing: MatchIndicator(match: _encaje(postulacion)),
      onTap: () => _verCandidaturaEnviada(postulacion),
    );
  }
}

enum _ResultadoPropuesta { enviada, descartada }

/// Hoja de detalle de una propuesta: por qué la IA la propone, la carta de
/// presentación y la decisión («Enviar candidatura» o «Descartar»).
class _DetallePropuesta extends StatefulWidget {
  const _DetallePropuesta({required this.postulacion, required this.service});

  final Map<String, dynamic> postulacion;
  final CandidatoService service;

  @override
  State<_DetallePropuesta> createState() => _DetallePropuestaState();
}

class _DetallePropuestaState extends State<_DetallePropuesta> {
  bool _enviando = false;
  bool _descartando = false;
  String? _error;

  Future<void> _resolver({required bool aprobar}) async {
    setState(() {
      if (aprobar) {
        _enviando = true;
      } else {
        _descartando = true;
      }
      _error = null;
    });
    final id = widget.postulacion['id'] as String;
    try {
      if (aprobar) {
        await widget.service.aprobarPostulacion(id);
      } else {
        await widget.service.descartarPostulacion(id);
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        aprobar ? _ResultadoPropuesta.enviada : _ResultadoPropuesta.descartada,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _descartando = false;
        _error = error is ApiException ? error.mensaje : error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final propuesta = widget.postulacion;
    final oferta = propuesta['oferta'] as Map<String, dynamic>? ?? {};
    final empresa = oferta['empresa'] as Map<String, dynamic>? ?? {};
    final carta = (propuesta['cartaIa'] as String?)?.trim();
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(oferta['titulo'] as String? ?? 'Oferta', style: AppText.h1),
            const SizedBox(height: AppSpacing.micro),
            Text(
              empresa['nombre'] as String? ?? 'Empresa',
              style: AppText.mutedBody,
            ),
            const SizedBox(height: AppSpacing.group),
            Text(
              'La empresa no la verá hasta que la envíes.',
              style: AppText.mutedBody,
            ),
            ValoracionIa.deCandidatura(
              propuesta,
              titulo: 'Por qué la IA te lo propone',
            ),
            if (carta != null && carta.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.gap),
              const SectionTitle('Carta de presentación'),
              const SizedBox(height: AppSpacing.group),
              Panel(child: Text(carta, style: AppText.body)),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.gap),
              Notice(message: _error!, variant: StatusVariant.error),
            ],
            const SizedBox(height: AppSpacing.gap),
            PrimaryButton(
              label: 'Enviar candidatura',
              loading: _enviando,
              loadingLabel: 'Enviando…',
              onPressed: _descartando ? null : () => _resolver(aprobar: true),
            ),
            const SizedBox(height: AppSpacing.group),
            SecondaryButton(
              label: _descartando ? 'Descartando…' : 'Descartar propuesta',
              onPressed: _enviando || _descartando
                  ? null
                  : () => _resolver(aprobar: false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de ajuste: etiqueta visible, valor mono a la derecha y slider nativo.
class _AjusteDeslizable extends StatelessWidget {
  const _AjusteDeslizable({
    required this.etiqueta,
    required this.valor,
    required this.slider,
    required this.min,
    required this.max,
    required this.divisiones,
    required this.onChanged,
    required this.onChangeEnd,
    this.subtitulo,
  });

  final String etiqueta;
  final String valor;
  final String? subtitulo;
  final double slider;
  final double min;
  final double max;
  final int divisiones;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.gap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(etiqueta, style: AppText.label)),
            Text(valor, style: AppText.numInline),
          ],
        ),
        if (subtitulo != null) ...[
          const SizedBox(height: AppSpacing.micro),
          Text(subtitulo!, style: AppText.meta),
        ],
        Slider(
          value: slider,
          min: min,
          max: max,
          divisions: divisiones,
          semanticFormatterCallback: (v) => '$etiqueta: ${v.round()}',
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    ),
  );
}
