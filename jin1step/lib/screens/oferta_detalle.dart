import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../services/candidato.service.dart';
import '../services/chat.service.dart';
import 'mensajes.dart';
import 'mis_cvs.dart';

class OfertaDetalle extends StatefulWidget {
  const OfertaDetalle({super.key, required this.oferta});

  final Map<String, dynamic> oferta;

  @override
  State<OfertaDetalle> createState() => _OfertaDetalleState();
}

class _OfertaDetalleState extends State<OfertaDetalle> {
  final _service = CandidatoService();
  final _chatService = ChatService();
  bool _cargando = false;
  Map<String, dynamic>? _postulacionExistente;
  String? _error;

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
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Elige el CV para esta candidatura',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final cv in cvs)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(cv['titulo'] as String? ?? 'Currículum'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => Navigator.pop(context, cv),
                    ),
                  TextButton.icon(
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
                    icon: const Icon(Icons.add),
                    label: const Text('Subir otro CV'),
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
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final oferta = widget.oferta;
    final empresa = oferta['empresa'] as Map<String, dynamic>?;
    final titulo = oferta['titulo'] as String? ?? 'Oferta';
    final nombreEmpresa = empresa?['nombre'] as String?;
    final sitioWeb = empresa?['sitioWeb'] as String?;
    final requisitos = (oferta['requisitos'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const <Map<String, dynamic>>[];
    final ubicacion = empresa?['ubicacion'] as String?;
    final modalidad = oferta['modalidad'] as String?;
    final descripcion = oferta['descripcion'] as String? ?? 'Sin descripción';
    final estaAbierta =
        oferta['estado'] == null || oferta['estado'] == 'ABIERTA';
    final yaPostulada = _postulacionExistente != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la oferta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [esquema.primary, const Color(0xFF8177F4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.business_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  titulo,
                  style: tema.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (nombreEmpresa != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    nombreEmpresa,
                    style: tema.textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: .86),
                    ),
                  ),
                ],
                if (sitioWeb != null && sitioWeb.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: () => launchUrl(Uri.parse(sitioWeb)),
                    icon: const Icon(Icons.open_in_new, size: 17),
                    label: Text(sitioWeb, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Wrap(
              spacing: 18,
              runSpacing: 14,
              children: [
                if (ubicacion != null)
                  _dato(context, Icons.location_on_outlined, ubicacion),
                if (modalidad != null)
                  _dato(
                    context,
                    Icons.work_outline,
                    _etiquetaModalidad(modalidad),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text(
            'Sobre el puesto',
            style: tema.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            descripcion,
            style: tema.textTheme.bodyLarge?.copyWith(
              height: 1.65,
              color: esquema.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Requisitos del puesto',
            style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (requisitos.isEmpty)
            const GlassPanel(
              child: Text('Esta oferta todavía no tiene requisitos definidos.'),
            )
          else
            GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (final requisito in requisitos)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        requisito['obligatorio'] == true
                            ? Icons.check_circle_outline
                            : Icons.add_circle_outline,
                        color: esquema.primary,
                      ),
                      title: Text(
                        (requisito['habilidad'] as Map<String, dynamic>?)?['nombre']
                                as String? ??
                            'Habilidad',
                      ),
                      subtitle: Text(requisito['obligatorio'] == true ? 'Imprescindible' : 'Deseable'),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 28),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: esquema.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: esquema.onErrorContainer),
              ),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _contactarReclutador,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Chatear con el reclutador'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _cargando ||
                    yaPostulada ||
                    !estaAbierta ||
                    requisitos.isEmpty
                ? null
                : _postularse,
            icon: _cargando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    yaPostulada
                        ? Icons.check_circle_outline
                        : Icons.send_outlined,
                  ),
            label: Text(
              _cargando
                  ? 'Enviando candidatura…'
                  : yaPostulada
                  ? 'Ya te has postulado'
                  : requisitos.isEmpty
                  ? 'Pendiente de requisitos'
                  : estaAbierta
                  ? 'Postularme a esta oferta'
                  : 'Oferta cerrada',
            ),
          ),
          if (yaPostulada &&
              requisitos.isNotEmpty &&
              _postulacionExistente?['matchScore'] is num) ...[
            const SizedBox(height: 10),
            Text(
              'Compatibilidad: ${(_postulacionExistente!['matchScore'] as num).round()}%',
              textAlign: TextAlign.center,
              style: TextStyle(color: esquema.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dato(BuildContext context, IconData icono, String texto) {
    final esquema = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 19, color: esquema.primary),
        const SizedBox(width: 8),
        Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _etiquetaModalidad(String valor) => switch (valor) {
    'REMOTO' => 'Remoto',
    'HIBRIDO' => 'Híbrido',
    'PRESENCIAL' => 'Presencial',
    _ => valor,
  };
}
