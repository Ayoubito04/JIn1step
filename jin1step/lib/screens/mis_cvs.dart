import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/candidato.service.dart';
import '../services/habilidades.service.dart';
import '../widgets/design_system.dart';
import 'cv_preview.dart';

const _maxBytesPdf = 5 * 1024 * 1024;

/// Habilidades que se ven de entrada; el resto, tras «Ver las N».
const _habilidadesVisibles = 5;

class MisCvsPage extends StatefulWidget {
  const MisCvsPage({super.key, this.seleccionable = true});

  final bool seleccionable;

  @override
  State<MisCvsPage> createState() => _MisCvsPageState();
}

/// CVs del candidato y habilidades del CV principal (el más reciente, el mismo
/// que usan Inicio y Ofertas para calcular el match).
class _DatosCv {
  const _DatosCv({required this.cvs, required this.habilidades});

  final List<Map<String, dynamic>> cvs;
  final List<Map<String, dynamic>> habilidades;
}

class _MisCvsPageState extends State<MisCvsPage> {
  final _service = CandidatoService();
  late Future<_DatosCv> _datos = _cargar();
  bool _subiendo = false;
  bool _verTodas = false;
  String? _error;

  Future<_DatosCv> _cargar() async {
    final cvs = await _service.listarCvs();
    var habilidades = const <Map<String, dynamic>>[];
    final principal = cvs.isEmpty ? null : cvs.first['id'] as String?;
    if (principal != null) {
      try {
        habilidades = await _service.listarHabilidadesCv(principal);
      } catch (_) {
        // Las habilidades son informativas: si fallan, el CV sigue usable.
      }
    }
    return _DatosCv(cvs: cvs, habilidades: habilidades);
  }

  void _recargar() {
    setState(() {
      _datos = _cargar();
    });
  }

  Future<void> _subirCv() async {
    try {
      final archivos = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (archivos.isEmpty || !mounted) return;

      final archivo = archivos.first;
      final bytes = await archivo.readAsBytes();
      if (bytes.isEmpty) {
        setState(() => _error = 'No se pudo leer el archivo seleccionado.');
        return;
      }
      if (bytes.length > _maxBytesPdf) {
        setState(() => _error = 'El PDF supera el máximo de 5 MB.');
        return;
      }

      final titulo = archivo.name
          .replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '')
          .trim();
      setState(() {
        _subiendo = true;
        _error = null;
      });

      final cv = await _service.subirCv(
        titulo: titulo.isEmpty ? 'Mi CV' : titulo,
        nombreArchivo: archivo.name,
        bytes: bytes,
      );
      if (!mounted) return;
      if (widget.seleccionable) {
        Navigator.of(context).pop(cv);
      } else {
        _recargar();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<void> _anadirHabilidad(
    String cvId,
    List<Map<String, dynamic>> actuales,
  ) async {
    final existentes = {
      for (final item in actuales) item['habilidadId'] as String? ?? '',
    };
    final eleccion = await showModalBottomSheet<({String id, String nivel})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _HojaAnadirHabilidad(existentes: existentes),
    );
    if (eleccion == null || !mounted) return;
    try {
      setState(() => _error = null);
      await _service.asignarHabilidadCv(cvId, eleccion.id, eleccion.nivel);
      if (mounted) _recargar();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _editarNivel(String cvId, Map<String, dynamic> item) async {
    final habilidadId = item['habilidadId'] as String?;
    if (habilidadId == null) return;
    final eleccion = await showModalBottomSheet<({String? nivel})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _HojaNivel(nombre: _nombreDe(item), actual: item['nivel'] as String?),
    );
    if (eleccion == null || eleccion.nivel == item['nivel'] || !mounted) return;
    try {
      setState(() => _error = null);
      await _service.actualizarNivelHabilidadCv(
        cvId,
        habilidadId,
        eleccion.nivel,
      );
      if (mounted) _recargar();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_DatosCv>(
          future: _datos,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: AppSpinner(size: 24));
            }
            if (snapshot.hasError) {
              return _EstadoError(
                mensaje: snapshot.error.toString(),
                onReintentar: _recargar,
              );
            }
            final datos = snapshot.data!;
            return _contenido(context, datos);
          },
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context, _DatosCv datos) {
    final cvs = datos.cvs;
    final principalId = cvs.isEmpty ? null : cvs.first['id'] as String?;
    final habilidades = _ordenarHabilidades(datos.habilidades);
    final visibles = _verTodas || habilidades.length <= _habilidadesVisibles
        ? habilidades
        : habilidades.take(_habilidadesVisibles).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        Row(
          children: [
            if (Navigator.of(context).canPop()) ...[
              AppIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Volver',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: AppSpacing.group),
            ],
            const Expanded(child: ScreenHeader(title: 'Mi CV')),
          ],
        ),
        const SizedBox(height: AppSpacing.gap),
        if (cvs.isEmpty)
          Panel(
            child: Text(
              'Todavía no has subido ningún CV.',
              style: AppText.mutedBody,
            ),
          )
        else
          PanelList(
            children: [
              for (var i = 0; i < cvs.length; i++)
                _FilaCv(
                  cv: cvs[i],
                  enUso: i == 0,
                  onVer: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CvPreviewPage(
                        cvId: cvs[i]['id'] as String,
                        titulo: cvs[i]['titulo'] as String? ?? 'Currículum',
                      ),
                    ),
                  ),
                  onElegir: widget.seleccionable
                      ? () => Navigator.of(context).pop(cvs[i])
                      : null,
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.gap),
        SecondaryButton(
          label: _subiendo
              ? 'Subiendo…'
              : '${cvs.isEmpty ? 'Subir PDF' : 'Subir otro PDF'} (máx. 5 MB)',
          onPressed: _subiendo ? null : _subirCv,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.gap),
          Notice(message: _error!, variant: StatusVariant.error),
        ],
        if (principalId != null) ...[
          const SizedBox(height: AppSpacing.gap),
          const SectionTitle('Habilidades detectadas'),
          const SizedBox(height: AppSpacing.group),
          if (habilidades.isEmpty)
            Panel(
              child: Text(
                'Aún no hay habilidades detectadas en este CV.',
                style: AppText.mutedBody,
              ),
            )
          else
            PanelList(
              children: [
                for (final item in visibles)
                  _FilaHabilidad(
                    item: item,
                    onTap: () => _editarNivel(principalId, item),
                  ),
              ],
            ),
          if (habilidades.length > _habilidadesVisibles)
            LinkAction(
              label: _verTodas
                  ? 'Ver menos habilidades'
                  : 'Ver las ${habilidades.length}',
              onTap: () => setState(() => _verTodas = !_verTodas),
            ),
          const SizedBox(height: AppSpacing.group),
          SecondaryButton(
            label: 'Añadir habilidad',
            onPressed: () => _anadirHabilidad(principalId, datos.habilidades),
          ),
        ],
      ],
    );
  }

  List<Map<String, dynamic>> _ordenarHabilidades(
    List<Map<String, dynamic>> lista,
  ) {
    final copia = [...lista];
    copia.sort((a, b) {
      final porNivel = _nivelDe(b).compareTo(_nivelDe(a));
      if (porNivel != 0) return porNivel;
      return _nombreDe(a).toLowerCase().compareTo(_nombreDe(b).toLowerCase());
    });
    return copia;
  }
}

String _nombreDe(Map<String, dynamic> item) =>
    (item['habilidad'] as Map<String, dynamic>?)?['nombre'] as String? ??
    'Habilidad';

/// 0 = sin nivel, 1 = Básico, 2 = Intermedio, 3 = Avanzado.
int _nivelDe(Map<String, dynamic> item) => switch (item['nivel']) {
  'BASICO' => 1,
  'INTERMEDIO' => 2,
  'AVANZADO' => 3,
  _ => 0,
};

const _etiquetasNivel = ['Sin nivel', 'Básico', 'Intermedio', 'Avanzado'];

String _pluralizar(int n, String singular, String plural) =>
    '$n ${n == 1 ? singular : plural}';

String _hace(DateTime fecha) {
  final diferencia = DateTime.now().difference(fecha);
  if (diferencia.inMinutes < 1) return 'hace un momento';
  if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
  if (diferencia.inHours < 24) return 'hace ${diferencia.inHours} h';
  final dias = diferencia.inDays;
  if (dias < 7) return 'hace ${_pluralizar(dias, 'día', 'días')}';
  if (dias < 30) return 'hace ${_pluralizar(dias ~/ 7, 'semana', 'semanas')}';
  if (dias < 365) return 'hace ${_pluralizar(dias ~/ 30, 'mes', 'meses')}';
  return 'hace ${_pluralizar(dias ~/ 365, 'año', 'años')}';
}

String _nombreArchivo(Map<String, dynamic> cv) {
  final ruta = cv['urlArchivo'] as String? ?? '';
  final nombre = ruta.split(RegExp(r'[/\\]')).last;
  if (nombre.toLowerCase().endsWith('.pdf')) return nombre;
  return '${cv['titulo'] as String? ?? 'cv'}.pdf';
}

/// Fila de un CV: título, archivo y antigüedad, y la etiqueta «En uso» en el
/// CV principal. Si recibe [onElegir] (selección desde Autopiloto u Ofertas),
/// la fila es pulsable y devuelve ese CV.
class _FilaCv extends StatelessWidget {
  const _FilaCv({
    required this.cv,
    required this.enUso,
    required this.onVer,
    required this.onElegir,
  });

  final Map<String, dynamic> cv;
  final bool enUso;
  final VoidCallback onVer;
  final VoidCallback? onElegir;

  @override
  Widget build(BuildContext context) {
    final creado = DateTime.tryParse(cv['createdAt'] as String? ?? '');
    return ListRow(
      title: cv['titulo'] as String? ?? 'Currículum',
      lines: [
        _nombreArchivo(cv),
        if (creado != null) 'Subido ${_hace(creado.toLocal())}',
      ],
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (enUso) ...[
            const StatusTag(label: 'En uso', variant: StatusVariant.success),
            const SizedBox(width: AppSpacing.group),
          ],
          AppIconButton(
            icon: Icons.visibility_outlined,
            tooltip: 'Ver CV ${cv['titulo'] ?? 'Currículum'}',
            onPressed: onVer,
          ),
        ],
      ),
      onTap: onElegir,
    );
  }
}

class _FilaHabilidad extends StatelessWidget {
  const _FilaHabilidad({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nivel = _nivelDe(item);
    return ListRow(
      title: _nombreDe(item),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_etiquetasNivel[nivel], style: AppText.meta),
          const SizedBox(width: AppSpacing.group),
          Steps(filled: nivel, total: 3),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Hoja para cambiar el nivel de una habilidad ya asignada al CV.
class _HojaNivel extends StatelessWidget {
  const _HojaNivel({required this.nombre, required this.actual});

  final String nombre;
  final String? actual;

  static const _niveles = [
    ('BASICO', 'Básico'),
    ('INTERMEDIO', 'Intermedio'),
    ('AVANZADO', 'Avanzado'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nombre, style: AppText.h2),
            const SizedBox(height: AppSpacing.gap),
            Text('Nivel', style: AppText.label),
            const SizedBox(height: AppSpacing.group),
            Wrap(
              spacing: AppSpacing.group,
              runSpacing: AppSpacing.group,
              children: [
                for (final (valor, etiqueta) in _niveles)
                  FilterChipButton(
                    label: etiqueta,
                    selected: actual == valor,
                    onTap: () => Navigator.of(context).pop((nivel: valor)),
                  ),
                FilterChipButton(
                  label: 'Sin nivel',
                  selected: actual == null,
                  onTap: () => Navigator.of(context).pop((nivel: null)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Selector de habilidad del catálogo y nivel para «Añadir habilidad».
class _HojaAnadirHabilidad extends StatefulWidget {
  const _HojaAnadirHabilidad({required this.existentes});

  final Set<String> existentes;

  @override
  State<_HojaAnadirHabilidad> createState() => _HojaAnadirHabilidadState();
}

class _HojaAnadirHabilidadState extends State<_HojaAnadirHabilidad> {
  final _catalogo = HabilidadesService().listarCatalogo();
  String _nivel = 'INTERMEDIO';

  static const _niveles = [
    ('BASICO', 'Básico'),
    ('INTERMEDIO', 'Intermedio'),
    ('AVANZADO', 'Avanzado'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Añadir habilidad', style: AppText.h2),
            const SizedBox(height: AppSpacing.gap),
            Text('Nivel', style: AppText.label),
            const SizedBox(height: AppSpacing.group),
            Wrap(
              spacing: AppSpacing.group,
              runSpacing: AppSpacing.group,
              children: [
                for (final (valor, etiqueta) in _niveles)
                  FilterChipButton(
                    label: etiqueta,
                    selected: _nivel == valor,
                    onTap: () => setState(() => _nivel = valor),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.gap),
            Text('Habilidad', style: AppText.label),
            const SizedBox(height: AppSpacing.group),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _catalogo,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: AppSpinner(size: 24));
                }
                if (snapshot.hasError) {
                  return Notice(
                    message: snapshot.error.toString(),
                    variant: StatusVariant.error,
                  );
                }
                final disponibles = (snapshot.data ?? const [])
                    .where((h) => !widget.existentes.contains(h['id']))
                    .toList();
                if (disponibles.isEmpty) {
                  return Text(
                    'Ya tienes todas las habilidades disponibles.',
                    style: AppText.mutedBody,
                  );
                }
                return Wrap(
                  spacing: AppSpacing.group,
                  runSpacing: AppSpacing.group,
                  children: [
                    for (final habilidad in disponibles)
                      FilterChipButton(
                        label: habilidad['nombre'] as String? ?? 'Habilidad',
                        selected: false,
                        onTap: () => Navigator.of(
                          context,
                        ).pop((id: habilidad['id'] as String, nivel: _nivel)),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoError extends StatelessWidget {
  const _EstadoError({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.screen),
      child: Panel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Notice(message: mensaje, variant: StatusVariant.error),
            const SizedBox(height: AppSpacing.gap),
            SecondaryButton(label: 'Reintentar', onPressed: onReintentar),
          ],
        ),
      ),
    ),
  );
}
