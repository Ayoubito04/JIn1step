import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/habilidades.service.dart';
import '../services/ofertas.services.dart';
import 'candidatos_oferta.dart';
import 'publicar_oferta.dart';

class MisOfertasPage extends StatefulWidget {
  const MisOfertasPage({super.key, this.service, this.usuarioId});

  final OfertasService? service;
  final String? usuarioId;

  @override
  State<MisOfertasPage> createState() => _MisOfertasPageState();
}

class _MisOfertasPageState extends State<MisOfertasPage> {
  late final OfertasService _service = widget.service ?? OfertasService();
  late Future<List<Map<String, dynamic>>> _ofertas = _service.getMisOfertas();

  Future<void> _refrescar() async {
    final nuevas = _service.getMisOfertas();
    setState(() => _ofertas = nuevas);
    await nuevas;
  }

  Future<void> _publicar() async {
    final publicada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PublicarOferta()),
    );
    if (publicada == true && mounted) await _refrescar();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis ofertas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _publicar,
        icon: const Icon(Icons.add),
        label: const Text('Publicar oferta'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ofertas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _estado(
              context,
              Icons.cloud_off_outlined,
              'No se pudieron cargar tus ofertas',
              action: OutlinedButton(onPressed: _refrescar, child: const Text('Reintentar')),
            );
          }
          final ofertas = snapshot.data ?? [];
          if (ofertas.isEmpty) {
            return _estado(
              context,
              Icons.work_outline,
              'Todavía no has publicado ofertas',
              action: FilledButton.icon(
                onPressed: _publicar,
                icon: const Icon(Icons.add),
                label: const Text('Publicar una oferta'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refrescar,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: ofertas.length,
              itemBuilder: (context, index) {
                final oferta = ofertas[index];
                final empresa = oferta['empresa'] as Map<String, dynamic>? ?? {};
                final requisitos = oferta['requisitos'] as List? ?? const [];
                final faltanRequisitos = requisitos.isEmpty;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: colors.primary.withValues(alpha: .1),
                              child: Icon(Icons.work_outline, color: colors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(oferta['titulo'] as String? ?? 'Oferta',
                                      style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text(empresa['nombre'] as String? ?? 'Empresa',
                                      style: TextStyle(color: colors.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            Icon(
                              faltanRequisitos ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                              color: faltanRequisitos ? colors.error : colors.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          faltanRequisitos
                              ? 'Faltan requisitos: no se puede calcular una compatibilidad fiable.'
                              : '${requisitos.length} requisitos definidos',
                          style: TextStyle(
                            color: faltanRequisitos ? colors.error : colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final actualizado = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => EditarRequisitosOfertaPage(oferta: oferta),
                              ),
                            );
                            if (actualizado == true && mounted) await _refrescar();
                          },
                          icon: const Icon(Icons.tune),
                          label: Text(faltanRequisitos ? 'Añadir requisitos' : 'Editar requisitos'),
                        ),
                        if (widget.usuarioId != null) ...[
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => CandidatosOfertaPage(
                                  oferta: oferta,
                                  reclutadorId: widget.usuarioId!,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.people_alt_outlined),
                            label: const Text('Ver candidatos y chatear'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _estado(BuildContext context, IconData icon, String message, {Widget? action}) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: colors.primary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }
}

class EditarRequisitosOfertaPage extends StatefulWidget {
  const EditarRequisitosOfertaPage({super.key, required this.oferta});
  final Map<String, dynamic> oferta;

  @override
  State<EditarRequisitosOfertaPage> createState() => _EditarRequisitosOfertaPageState();
}

class _EditarRequisitosOfertaPageState extends State<EditarRequisitosOfertaPage> {
  final _habilidades = HabilidadesService();
  late final Future<List<Map<String, dynamic>>> _catalogo = _habilidades.listarCatalogo();
  late final OfertasService _ofertas = OfertasService();
  final Map<String, bool> _seleccion = {};
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final requisitos = widget.oferta['requisitos'] as List? ?? const [];
    for (final item in requisitos.whereType<Map<String, dynamic>>()) {
      final habilidad = item['habilidad'] as Map<String, dynamic>?;
      final id = habilidad?['id'] as String?;
      if (id != null) _seleccion[id] = item['obligatorio'] == true;
    }
  }

  Future<void> _guardar() async {
    if (_seleccion.isEmpty) {
      setState(() => _error = 'Selecciona al menos un requisito.');
      return;
    }
    setState(() { _guardando = true; _error = null; });
    try {
      await _ofertas.reemplazarRequisitos(
        ofertaId: widget.oferta['id'] as String,
        requisitos: [
          for (final entry in _seleccion.entries)
            {'habilidadId': entry.key, 'obligatorio': entry.value},
        ],
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Requisitos de la oferta')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _catalogo,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('No se cargó el catálogo: ${snapshot.error}'));
          final habilidades = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.oferta['titulo'] as String? ?? 'Oferta',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('Selecciona habilidades. El icono de estrella cambia entre imprescindible y deseable.'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Column(
                  children: [
                    for (final habilidad in habilidades)
                      _fila(habilidad, colors),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: colors.error)),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(_guardando ? 'Guardando…' : 'Guardar requisitos'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _fila(Map<String, dynamic> habilidad, ColorScheme colors) {
    final id = habilidad['id'] as String;
    final selected = _seleccion.containsKey(id);
    final obligatorio = _seleccion[id] ?? true;
    return CheckboxListTile(
      value: selected,
      title: Text(habilidad['nombre'] as String? ?? 'Habilidad'),
      subtitle: selected ? Text(obligatorio ? 'Imprescindible' : 'Deseable') : null,
      secondary: selected
          ? IconButton(
              onPressed: _guardando ? null : () => setState(() => _seleccion[id] = !obligatorio),
              icon: Icon(obligatorio ? Icons.star : Icons.star_border, color: colors.primary),
            )
          : null,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: _guardando
          ? null
          : (value) => setState(() {
                if (value == true) {
                  _seleccion[id] = true;
                } else {
                  _seleccion.remove(id);
                }
              }),
    );
  }
}
