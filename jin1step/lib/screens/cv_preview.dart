import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/app_theme.dart';
import '../services/candidato.service.dart';
import '../widgets/design_system.dart';

/// Vista previa del PDF de un CV propio. Se baja el archivo con la sesión del
/// usuario (nunca una URL pública) y se dibuja con el visor de PDF.
class CvPreviewPage extends StatefulWidget {
  const CvPreviewPage({
    super.key,
    required this.cvId,
    required this.titulo,
    this.service,
  });

  final String cvId;
  final String titulo;

  /// Opcional para poder inyectar un servicio falso en los tests.
  final CandidatoService? service;

  @override
  State<CvPreviewPage> createState() => _CvPreviewPageState();
}

class _CvPreviewPageState extends State<CvPreviewPage> {
  late final CandidatoService _service = widget.service ?? CandidatoService();
  late Future<Uint8List> _archivo = _service.descargarArchivoCv(widget.cvId);

  void _reintentar() {
    setState(() {
      _archivo = _service.descargarArchivoCv(widget.cvId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Volver a Mi CV',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: AppSpacing.group),
                  Expanded(
                    child: ScreenHeader(
                      title: widget.titulo,
                      subtitle: 'Vista previa del PDF',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.gap),
              Expanded(
                child: FutureBuilder<Uint8List>(
                  future: _archivo,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Panel(
                        child: Center(child: AppSpinner(size: 24)),
                      );
                    }
                    if (snapshot.hasError) {
                      return Align(
                        alignment: Alignment.topCenter,
                        child: Panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                snapshot.error.toString(),
                                style: AppText.body,
                              ),
                              const SizedBox(height: AppSpacing.gap),
                              SecondaryButton(
                                label: 'Reintentar',
                                onPressed: _reintentar,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Semantics(
                      label: 'Vista previa del CV ${widget.titulo}',
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.ground,
                          borderRadius: BorderRadius.circular(AppRadii.panel),
                          border: Border.all(color: AppColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: PdfViewer.data(
                          snapshot.data!,
                          sourceName: 'cv-${widget.cvId}',
                          params: const PdfViewerParams(
                            backgroundColor: AppColors.ground,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
