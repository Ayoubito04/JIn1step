import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../services/empresas.services.dart';
import '../services/habilidades.service.dart';
import '../services/ofertas.services.dart';

class PublicarOferta extends StatefulWidget {
  const PublicarOferta({super.key, this.ofertasService, this.empresasService});

  final OfertasService? ofertasService;
  final EmpresasService? empresasService;

  @override
  State<PublicarOferta> createState() => _PublicarOfertaState();
}

class _PublicarOfertaState extends State<PublicarOferta> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  late final OfertasService _ofertasService =
      widget.ofertasService ?? OfertasService();
  late final EmpresasService _empresasService =
      widget.empresasService ?? EmpresasService();
  final _habilidadesService = HabilidadesService();
  late Future<List<Map<String, dynamic>>> _futuroEmpresas =
      _empresasService.listarEmpresas();
  late final Future<List<Map<String, dynamic>>> _futuroHabilidades =
      _habilidadesService.listarCatalogo();

  String? _empresaId;
  final Map<String, bool> _requisitos = {};
  String _modalidad = 'REMOTO';
  bool _publicando = false;
  String? _error;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrarEmpresa() async {
    final empresa = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CrearEmpresaDialog(service: _empresasService),
    );
    if (empresa == null || !mounted) return;
    setState(() {
      _empresaId = empresa['id'] as String;
      _futuroEmpresas = _empresasService.listarEmpresas();
      _error = null;
    });
  }

  Future<void> _publicar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_empresaId == null) {
      setState(() => _error = 'Selecciona o registra una empresa.');
      return;
    }
    if (_requisitos.isEmpty) {
      setState(() => _error = 'Añade al menos un requisito para la oferta.');
      return;
    }

    setState(() {
      _publicando = true;
      _error = null;
    });

    try {
      await _ofertasService.crearOferta(
        empresaId: _empresaId!,
        titulo: _tituloCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        modalidad: _modalidad,
        requisitos: [
          for (final entry in _requisitos.entries)
            {'habilidadId': entry.key, 'obligatorio': entry.value},
        ],
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _publicando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publicar oferta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _intro(context),
                  const SizedBox(height: 18),
                  GlassPanel(
                    padding: const EdgeInsets.all(22),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _selectorEmpresa(),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _publicando ? null : _registrarEmpresa,
                              icon: const Icon(Icons.add_business_outlined),
                              label: const Text('Registrar empresa y su web'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _tituloCtrl,
                            enabled: !_publicando,
                            decoration: const InputDecoration(
                              labelText: 'Título del puesto',
                              prefixIcon: Icon(Icons.work_outline),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return 'El título es obligatorio';
                              if (text.length > 100) return 'Máximo 100 caracteres';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descripcionCtrl,
                            enabled: !_publicando,
                            minLines: 4,
                            maxLines: 8,
                            decoration: const InputDecoration(
                              labelText: 'Descripción',
                              alignLabelWithHint: true,
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return 'La descripción es obligatoria';
                              if (text.length > 1000) return 'Máximo 1000 caracteres';
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          _selectorModalidad(),
                          const SizedBox(height: 22),
                          _selectorRequisitos(),
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            _errorBanner(context, _error!),
                          ],
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: _publicando ? null : _publicar,
                            icon: _publicando
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.publish_outlined),
                            label: Text(_publicando ? 'Publicando…' : 'Publicar oferta'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(Icons.post_add_rounded, color: colors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Encuentra a la persona adecuada',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('Añade habilidades y requisitos para calcular la compatibilidad.',
                  style: TextStyle(color: colors.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _selectorEmpresa() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futuroEmpresas,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text('No se pudieron cargar las empresas. Registra una empresa nueva.',
              style: TextStyle(color: Theme.of(context).colorScheme.error));
        }
        final empresas = [...(snapshot.data ?? [])]..sort((a, b) {
          final techA = (a['sector'] as String? ?? '').toLowerCase().contains('tecnolog');
          final techB = (b['sector'] as String? ?? '').toLowerCase().contains('tecnolog');
          if (techA != techB) return techA ? -1 : 1;
          return (a['nombre'] as String? ?? '').compareTo(b['nombre'] as String? ?? '');
        });
        final ids = empresas.map((e) => e['id'] as String).toSet();
        final selected = ids.contains(_empresaId) ? _empresaId : null;
        Map<String, dynamic>? empresa;
        for (final item in empresas) {
          if (item['id'] == selected) {
            empresa = item;
            break;
          }
        }
        final sitioWeb = empresa?['sitioWeb'] as String?;
        final ubicacionEmpresa = empresa?['ubicacion'] as String?;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selected,
              decoration: const InputDecoration(
                labelText: 'Empresa',
                prefixIcon: Icon(Icons.business_outlined),
              ),
              items: [
                for (final item in empresas)
                  DropdownMenuItem(
                    value: item['id'] as String,
                    child: Text(
                      '${item['nombre'] ?? 'Empresa'}${(item['ubicacion'] as String?)?.isNotEmpty == true ? ' · ${item['ubicacion']}' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _publicando ? null : (value) => setState(() => _empresaId = value),
            ),
            if (ubicacionEmpresa != null && ubicacionEmpresa.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Ubicación: $ubicacionEmpresa',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
            if (sitioWeb != null && sitioWeb.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Web: $sitioWeb',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ],
          ],
        );
      },
    );
  }

  Widget _selectorModalidad() {
    const options = <(String, String)>[
      ('Remoto', 'REMOTO'),
      ('Híbrido', 'HIBRIDO'),
      ('Presencial', 'PRESENCIAL'),
    ];
    return SegmentedButton<String>(
      segments: [for (final (label, value) in options) ButtonSegment(value: value, label: Text(label))],
      selected: {_modalidad},
      onSelectionChanged: _publicando ? null : (selection) => setState(() => _modalidad = selection.first),
    );
  }

  Widget _selectorRequisitos() {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futuroHabilidades,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Text('No se pudo cargar el catálogo de habilidades: ${snapshot.error}',
              style: TextStyle(color: colors.error));
        }
        final skills = snapshot.data ?? [];
        return Container(
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: .65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineVariant.withValues(alpha: .6)),
          ),
          child: ExpansionTile(
            initiallyExpanded: true,
            title: Text('Requisitos (${_requisitos.length})',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Selecciona al menos uno; marca si es imprescindible.'),
            children: [
              if (skills.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('El catálogo está vacío. Añade habilidades antes de publicar.'),
                )
              else
                for (final skill in skills)
                  _filaHabilidad(skill, colors),
            ],
          ),
        );
      },
    );
  }

  Widget _filaHabilidad(Map<String, dynamic> skill, ColorScheme colors) {
    final id = skill['id'] as String;
    final selected = _requisitos.containsKey(id);
    final obligatorio = _requisitos[id] ?? true;
    return CheckboxListTile(
      dense: true,
      value: selected,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(skill['nombre'] as String? ?? 'Habilidad'),
      subtitle: selected ? Text(obligatorio ? 'Imprescindible' : 'Deseable') : null,
      secondary: selected
          ? IconButton(
              tooltip: obligatorio ? 'Marcar como deseable' : 'Marcar como imprescindible',
              onPressed: _publicando
                  ? null
                  : () => setState(() => _requisitos[id] = !obligatorio),
              icon: Icon(obligatorio ? Icons.star : Icons.star_border, color: colors.primary),
            )
          : null,
      onChanged: _publicando
          ? null
          : (value) => setState(() {
                if (value == true) {
                  _requisitos[id] = true;
                } else {
                  _requisitos.remove(id);
                }
              }),
    );
  }

  Widget _errorBanner(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
    );
  }
}

class _CrearEmpresaDialog extends StatefulWidget {
  const _CrearEmpresaDialog({required this.service});
  final EmpresasService service;

  @override
  State<_CrearEmpresaDialog> createState() => _CrearEmpresaDialogState();
}

class _CrearEmpresaDialogState extends State<_CrearEmpresaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _web = TextEditingController();
  final _sector = TextEditingController();
  final _ubicacion = TextEditingController();
  String? _ubicacionElegida;
  static const _ubicaciones = <String>[
    'Madrid', 'Barcelona', 'Valencia', 'Sevilla', 'Zaragoza', 'Málaga',
    'Bilbao', 'Alicante', 'Murcia', 'Palma', 'A Coruña', 'Vigo', 'Valladolid',
    'Granada', 'San Sebastián', 'Pamplona', 'Santander', 'Oviedo', 'Toledo',
    'Salamanca', 'Girona', 'Tarragona', 'Córdoba', 'Cádiz', 'Burgos', 'León',
    'Logroño', 'Vitoria-Gasteiz', 'Las Palmas de Gran Canaria',
    'Santa Cruz de Tenerife', 'Remoto (España)', 'Otra ubicación',
  ];
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _web.dispose();
    _sector.dispose();
    _ubicacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _guardando = true; _error = null; });
    try {
      final empresa = await widget.service.crearEmpresa(
        nombre: _nombre.text.trim(),
        sector: _sector.text.trim(),
        ubicacion: _ubicacionElegida == 'Otra ubicación'
            ? _ubicacion.text.trim()
            : _ubicacionElegida,
        sitioWeb: _web.text.trim(),
      );
      if (mounted) Navigator.pop(context, empresa);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar empresa'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombre,
                  decoration: const InputDecoration(labelText: 'Nombre de empresa'),
                  validator: (value) => (value?.trim().isEmpty ?? true) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _web,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Sitio web (https://...)'),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    final uri = Uri.tryParse(text);
                    if (uri == null || !uri.hasScheme || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
                      return 'Introduce una URL http o https válida';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _sector, decoration: const InputDecoration(labelText: 'Sector (opcional)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _ubicacionElegida,
                  decoration: const InputDecoration(labelText: 'Ubicación de la empresa', prefixIcon: Icon(Icons.location_on_outlined)),
                  items: [for (final ciudad in _ubicaciones) DropdownMenuItem(value: ciudad, child: Text(ciudad))],
                  onChanged: _guardando ? null : (value) => setState(() => _ubicacionElegida = value),
                ),
                if (_ubicacionElegida == 'Otra ubicación') ...[
                  const SizedBox(height: 10),
                  TextFormField(controller: _ubicacion, decoration: const InputDecoration(labelText: 'Escribe ciudad o zona')),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _guardando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardando ? null : _guardar, child: Text(_guardando ? 'Guardando…' : 'Guardar empresa')),
      ],
    );
  }
}
