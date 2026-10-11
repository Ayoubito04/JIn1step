import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/candidato.service.dart';

class MisCvsPage extends StatefulWidget {
  const MisCvsPage({super.key, this.seleccionable = true});

  final bool seleccionable;

  @override
  State<MisCvsPage> createState() => _MisCvsPageState();
}

class _MisCvsPageState extends State<MisCvsPage> {
  final _service = CandidatoService();
  late Future<List<Map<String, dynamic>>> _cvs = _service.listarCvs();
  bool _subiendo = false;
  String? _error;

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
        setState(() {
          _cvs = _service.listarCvs();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis currículums')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _cvs,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _estadoError(snapshot.error.toString());
          }
          final cvs = snapshot.data ?? const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: esquema.primary,
                      size: 30,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Un CV listo para postularte',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sube un PDF. Lo analizaremos para calcular la compatibilidad con cada oferta.',
                      style: TextStyle(
                        color: esquema.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _subiendo ? null : _subirCv,
                      icon: _subiendo
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_outlined),
                      label: Text(_subiendo ? 'Subiendo…' : 'Subir CV en PDF'),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _mensaje(_error!, esquema.error, esquema.errorContainer),
              ],
              const SizedBox(height: 24),
              Text(
                'Tus CVs',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              if (cvs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Todavía no has subido ningún CV.',
                    style: TextStyle(color: esquema.onSurfaceVariant),
                  ),
                )
              else
                for (final cv in cvs)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: esquema.primary.withValues(alpha: .1),
                        child: Icon(
                          Icons.picture_as_pdf_outlined,
                          color: esquema.primary,
                        ),
                      ),
                      title: Text(
                        cv['titulo'] as String? ?? 'Currículum',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('PDF · listo para usar'),
                      trailing: widget.seleccionable
                          ? const Icon(Icons.chevron_right)
                          : null,
                      onTap: widget.seleccionable
                          ? () => Navigator.of(context).pop(cv)
                          : null,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _estadoError(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(() {
                _cvs = _service.listarCvs();
              }),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mensaje(String texto, Color color, Color fondo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(texto, style: TextStyle(color: color)),
    );
  }
}
