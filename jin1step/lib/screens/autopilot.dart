import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../services/candidato.service.dart';
import 'mis_cvs.dart';
import 'mis_postulaciones.dart';

class AutopilotPage extends StatefulWidget {
  const AutopilotPage({super.key});

  @override
  State<AutopilotPage> createState() => _AutopilotPageState();
}

class _AutopilotPageState extends State<AutopilotPage> {
  final _service = CandidatoService();
  bool _cargando = true;
  bool _guardando = false;
  bool _ejecutando = false;
  bool _simulando = false;
  bool _activo = false;
  bool _suscripcionActiva = false;
  bool _preferenciasGuardadas = false;
  String? _cvId;
  double _scoreMinimo = 70;
  int _maxPorDia = 5;
  List<Map<String, dynamic>> _cvs = [];
  List<Map<String, dynamic>> _ofertasSimuladas = [];
  String? _error;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resultados = await Future.wait<Object?>([
        _service.obtenerPreferenciasAutopilot(),
        _service.listarCvs(),
        _service.obtenerSuscripcionActiva(),
      ]);
      final preferencias = resultados[0] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _cvs = resultados[1] as List<Map<String, dynamic>>;
        _suscripcionActiva = resultados[2] != null;
        _activo = preferencias['activo'] as bool? ?? false;
        _cvId = preferencias['cvId'] as String?;
        _preferenciasGuardadas = _cvId != null;
        _scoreMinimo = ((preferencias['scoreMinimo'] as num?)?.toDouble() ?? 70)
            .clamp(0, 100)
            .toDouble();
        _maxPorDia = ((preferencias['maxPorDia'] as num?)?.toInt() ?? 5)
            .clamp(1, 20)
            .toInt();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _seleccionarCv() async {
    final cv = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const MisCvsPage()),
    );
    if (cv != null && mounted) {
      setState(() {
        _cvId = cv['id'] as String?;
        _preferenciasGuardadas = false;
        if (!_cvs.any((item) => item['id'] == _cvId)) _cvs = [..._cvs, cv];
      });
    }
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
      _mensaje = null;
    });
    try {
      await _service.guardarPreferenciasAutopilot({
        'cvId': _cvId,
        'scoreMinimo': _scoreMinimo.round(),
        'maxPorDia': _maxPorDia,
      });
      if (mounted) {
        setState(() {
          _preferenciasGuardadas = true;
          _mensaje = 'Preferencias guardadas.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cambiarActivacion(bool activar) async {
    if (activar && !_suscripcionActiva) {
      await _contratar();
      return;
    }
    if (activar && _cvId == null) {
      setState(
        () => _error = 'Selecciona un CV antes de activar el autopiloto.',
      );
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
      _mensaje = null;
    });
    try {
      await _service.guardarPreferenciasAutopilot({
        'activo': activar,
        'cvId': _cvId,
        'scoreMinimo': _scoreMinimo.round(),
        'maxPorDia': _maxPorDia,
      });
      if (mounted) {
        setState(() {
          _activo = activar;
          _preferenciasGuardadas = true;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _contratar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final url = await _service.iniciarSuscripcion();
      final abierta = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!abierta && mounted) {
        setState(() => _error = 'No se pudo abrir la página segura de pago.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _ejecutarAhora() async {
    setState(() {
      _ejecutando = true;
      _error = null;
      _mensaje = null;
    });
    try {
      final resultado = await _service.ejecutarAutopilot();
      final creadas = (resultado['creadas'] as num?)?.toInt() ?? 0;
      final motivo = resultado['motivo'] as String?;
      if (mounted) {
        setState(
          () => _mensaje = creadas > 0
              ? 'Se enviaron $creadas ${creadas == 1 ? 'candidatura' : 'candidaturas'} automáticamente.'
              : _textoMotivo(motivo),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _ejecutando = false);
    }
  }

  Future<void> _simularAhora() async {
    if (!_preferenciasGuardadas) {
      setState(() => _error = 'Guarda la configuración antes de simular.');
      return;
    }
    setState(() {
      _simulando = true;
      _error = null;
      _mensaje = null;
      _ofertasSimuladas = [];
    });
    try {
      final resultado = await _service.previsualizarAutopilot();
      final ofertas = (resultado['ofertas'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final motivo = resultado['motivo'] as String?;
      if (!mounted) return;
      setState(() {
        _ofertasSimuladas = ofertas;
        _mensaje = ofertas.isNotEmpty
            ? 'Simulación completada: ${ofertas.length} ${ofertas.length == 1 ? 'oferta compatible' : 'ofertas compatibles'}. No se ha enviado ninguna candidatura.'
            : _textoMotivo(motivo);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _simulando = false);
    }
  }

  String _textoMotivo(String? motivo) => switch (motivo) {
    'limite_diario_alcanzado' =>
      'Ya alcanzaste el límite diario de candidaturas automáticas.',
    'sin_ofertas_disponibles' =>
      'Ya te postulaste a todas las ofertas abiertas disponibles.',
    'sin_ofertas_sobre_score_minimo' =>
      'No hay nuevas ofertas que alcancen tu compatibilidad mínima.',
    _ => 'No hay candidaturas nuevas para enviar.',
  };

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Autopiloto')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: esquema.primary, size: 30),
                const SizedBox(height: 12),
                Text(
                  'Tu búsqueda, en piloto automático',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enviaremos candidaturas a ofertas abiertas que alcancen tu compatibilidad mínima, usando el CV que elijas.',
                  style: TextStyle(
                    color: esquema.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              value: _activo,
              onChanged: _guardando ? null : _cambiarActivacion,
              title: const Text(
                'Autopiloto activado',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                _suscripcionActiva
                    ? 'Se ejecuta automáticamente cada día.'
                    : 'Requiere una suscripción mensual activa.',
              ),
              secondary: Icon(
                _activo ? Icons.autorenew : Icons.pause_circle_outline,
                color: esquema.primary,
              ),
            ),
          ),
          if (!_suscripcionActiva) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _guardando ? null : _contratar,
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('Activar plan mensual'),
            ),
            TextButton(
              onPressed: _cargar,
              child: const Text('Ya completé el pago · comprobar estado'),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Configuración',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: Icon(Icons.description_outlined, color: esquema.primary),
              title: const Text('CV para postular'),
              subtitle: Text(_tituloCv ?? 'Selecciona o sube tu CV'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _seleccionarCv,
            ),
          ),
          Card(
            margin: const EdgeInsets.only(top: 10),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Compatibilidad mínima',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${_scoreMinimo.round()}%',
                        style: TextStyle(
                          color: esquema.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _scoreMinimo,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${_scoreMinimo.round()}%',
                    onChanged: (value) => setState(() {
                      _scoreMinimo = value;
                      _preferenciasGuardadas = false;
                    }),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Máximo de candidaturas al día',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DropdownButton<int>(
                        value: _maxPorDia,
                        items: [
                          for (var i = 1; i <= 20; i++)
                            DropdownMenuItem(value: i, child: Text('$i')),
                        ],
                        onChanged: (value) => setState(() {
                          _maxPorDia = value ?? _maxPorDia;
                          _preferenciasGuardadas = false;
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _guardando || _cvId == null ? null : _guardar,
            child: Text(_guardando ? 'Guardando…' : 'Guardar configuración'),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            Card(
              color: esquema.secondaryContainer.withValues(alpha: .62),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Prueba segura',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Simula la selección con tu CV y tus filtros. No necesita suscripción y no crea candidaturas.',
                      style: TextStyle(color: esquema.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _simulando || _cvId == null
                          ? null
                          : _simularAhora,
                      icon: _simulando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.science_outlined),
                      label: Text(
                        _simulando ? 'Simulando…' : 'Simular sin postular',
                      ),
                    ),
                    for (final oferta in _ofertasSimuladas)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.work_outline,
                          color: esquema.primary,
                        ),
                        title: Text(oferta['titulo'] as String? ?? 'Oferta'),
                        subtitle: Text(
                          [
                            oferta['empresa'] as String? ?? '',
                            oferta['ubicacion'] as String? ?? '',
                          ].where((parte) => parte.isNotEmpty).join(' · '),
                        ),
                        trailing: Text(
                          '${((oferta['score'] as num?) ?? 0).round()}%',
                          style: TextStyle(
                            color: esquema.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (_activo && _suscripcionActiva) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _ejecutando ? null : _ejecutarAhora,
              icon: _ejecutando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(_ejecutando ? 'Buscando ofertas…' : 'Ejecutar ahora'),
            ),
          ],
          if (_mensaje != null) ...[
            const SizedBox(height: 12),
            _aviso(_mensaje!, esquema.primary, esquema.primaryContainer),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _aviso(_error!, esquema.error, esquema.errorContainer),
          ],
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MisPostulacionesPage()),
            ),
            icon: const Icon(Icons.list_alt),
            label: const Text('Ver mis candidaturas'),
          ),
        ],
      ),
    );
  }

  String? get _tituloCv {
    for (final cv in _cvs) {
      if (cv['id'] == _cvId) return cv['titulo'] as String? ?? 'Currículum';
    }
    return null;
  }

  Widget _aviso(String texto, Color color, Color fondo) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(texto, style: TextStyle(color: color)),
  );
}
