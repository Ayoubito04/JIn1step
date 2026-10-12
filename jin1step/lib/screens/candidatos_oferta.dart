import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/chat.service.dart';
import '../services/postulaciones.service.dart';
import 'mensajes.dart';

class CandidatosOfertaPage extends StatefulWidget {
  const CandidatosOfertaPage({
    super.key,
    required this.oferta,
    required this.reclutadorId,
  });

  final Map<String, dynamic> oferta;
  final String reclutadorId;

  @override
  State<CandidatosOfertaPage> createState() => _CandidatosOfertaPageState();
}

class _CandidatosOfertaPageState extends State<CandidatosOfertaPage> {
  final _postulaciones = PostulacionesService();
  final _chat = ChatService();
  late Future<List<Map<String, dynamic>>> _future =
      _postulaciones.listarDeOferta(widget.oferta['id'] as String);
  final Set<String> _abriendoChats = {};
  final Set<String> _abriendoCvs = {};
  final Set<String> _descargandoCvs = {};
  final Set<String> _actualizandoEstado = {};
  String? _error;

  Future<void> _recargar() async {
    final future = _postulaciones.listarDeOferta(widget.oferta['id'] as String);
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _abrirChat(Map<String, dynamic> postulacion) async {
    final cv = postulacion['cv'] as Map<String, dynamic>?;
    final candidato = cv?['usuario'] as Map<String, dynamic>?;
    final candidatoId = candidato?['id'] as String?;
    if (candidatoId == null) {
      setState(() => _error = 'No se pudo identificar al candidato.');
      return;
    }

    setState(() {
      _error = null;
      _abriendoChats.add(candidatoId);
    });
    try {
      final conversacion = await _chat.abrir(
        usuarioId: candidatoId,
        ofertaId: widget.oferta['id'] as String,
      );
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatThreadPage(
          conversacion: {
            ...conversacion,
            'interlocutor': conversacion['candidato'] ?? candidato,
          },
          usuarioId: widget.reclutadorId,
        ),
      ));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _abriendoChats.remove(candidatoId));
    }
  }

  Future<void> _verCv(Map<String, dynamic> postulacion) async {
    final postulacionId = postulacion['id'] as String?;
    if (postulacionId == null) return;
    setState(() => _abriendoCvs.add(postulacionId));
    try {
      final cv = await _postulaciones.obtenerCv(postulacionId);
      if (!mounted) return;
      final contenido = cv['contenidoTexto'] as String?;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(cv['titulo'] as String? ?? 'Currículum'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: SelectableText(
                contenido == null || contenido.trim().isEmpty
                    ? 'Este PDF no contiene texto extraíble para mostrar.'
                    : contenido,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _abriendoCvs.remove(postulacionId));
    }
  }

  Future<void> _descargarCv(Map<String, dynamic> postulacion) async {
    final postulacionId = postulacion['id'] as String?;
    if (postulacionId == null) return;
    setState(() {
      _error = null;
      _descargandoCvs.add(postulacionId);
    });
    try {
      final bytes = await _postulaciones.descargarCv(postulacionId);
      if (bytes.isEmpty) throw Exception('El archivo del CV está vacío.');
      if (!mounted) return;

      final cv = postulacion['cv'] as Map<String, dynamic>? ?? {};
      final titulo = (cv['titulo'] as String? ?? 'CV')
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Guardar currículum',
        fileName: '${titulo.isEmpty ? 'CV' : titulo}.pdf',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (uri != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CV guardado correctamente.')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _descargandoCvs.remove(postulacionId));
    }
  }

  Future<void> _seleccionarParaEntrevista(
    Map<String, dynamic> postulacion,
  ) async {
    final id = postulacion['id'] as String?;
    if (id == null) return;
    setState(() {
      _error = null;
      _actualizandoEstado.add(id);
    });
    try {
      await _postulaciones.actualizarEstado(id, 'ENTREVISTA');
      await _recargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Candidato seleccionado para entrevista.')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _actualizandoEstado.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.oferta['titulo'] as String? ?? 'Oferta';
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Candidatos · $titulo')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _estado(context, 'No se pudieron cargar las candidaturas.',
                accion: 'Reintentar', onTap: _recargar);
          }
          final candidatos = snapshot.data ?? [];
          if (candidatos.isEmpty) {
            return _estado(context, 'Todavía no hay candidatos inscritos en esta oferta.');
          }
          return RefreshIndicator(
            onRefresh: _recargar,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: TextStyle(color: colors.error)),
                  ),
                for (final postulacion in candidatos)
                  _tarjeta(context, postulacion),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tarjeta(BuildContext context, Map<String, dynamic> postulacion) {
    final cv = postulacion['cv'] as Map<String, dynamic>? ?? {};
    final candidato = cv['usuario'] as Map<String, dynamic>? ?? {};
    final id = candidato['id'] as String? ?? '';
    final nombre = '${candidato['nombre'] ?? ''} ${candidato['apellidos'] ?? ''}'.trim();
    final score = postulacion['matchScore'];
    final postulacionId = postulacion['id'] as String? ?? '';
    final paraEntrevista = postulacion['estado'] == 'ENTREVISTA';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(child: Text(nombre.isEmpty ? '?' : nombre.substring(0, 1).toUpperCase())),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nombre.isEmpty ? 'Candidato' : nombre, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(cv['titulo'] as String? ?? 'Currículum', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ])),
              if (score is num) Chip(label: Text('${score.round()}%')),
            ]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: postulacionId.isEmpty ||
                            _abriendoCvs.contains(postulacionId)
                        ? null
                        : () => _verCv(postulacion),
                    icon: _abriendoCvs.contains(postulacionId)
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.description_outlined),
                    label: const Text('Ver CV'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: id.isEmpty || _abriendoChats.contains(id)
                        ? null
                        : () => _abrirChat(postulacion),
                    icon: _abriendoChats.contains(id)
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chat_bubble_outline),
                    label: Text(
                      _abriendoChats.contains(id) ? 'Abriendo…' : 'Chatear',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: postulacionId.isEmpty ||
                        _descargandoCvs.contains(postulacionId)
                    ? null
                    : () => _descargarCv(postulacion),
                icon: _descargandoCvs.contains(postulacionId)
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: Text(
                  _descargandoCvs.contains(postulacionId)
                      ? 'Descargando…'
                      : 'Descargar CV en PDF',
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: paraEntrevista
                  ? const Chip(
                      avatar: Icon(Icons.event_available_outlined),
                      label: Text('Seleccionado para entrevista'),
                    )
                  : OutlinedButton.icon(
                      onPressed: postulacionId.isEmpty ||
                              _actualizandoEstado.contains(postulacionId)
                          ? null
                          : () => _seleccionarParaEntrevista(postulacion),
                      icon: _actualizandoEstado.contains(postulacionId)
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.event_available_outlined),
                      label: Text(
                        _actualizandoEstado.contains(postulacionId)
                            ? 'Actualizando…'
                            : 'Seleccionar para entrevista',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _estado(BuildContext context, String mensaje,
      {String? accion, VoidCallback? onTap}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.people_outline, size: 46, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            if (accion != null) TextButton(onPressed: onTap, child: Text(accion)),
          ]),
        ),
      );
}
