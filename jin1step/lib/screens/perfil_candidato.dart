import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/chat.service.dart';
import '../services/postulaciones.service.dart';
import '../widgets/design_system.dart';
import 'mensajes.dart';
import 'perfil.dart';

/// Vista del perfil completo de un candidato para el reclutador:
/// cabecera estilo LinkedIn con su foto de portada (banner) y avatar,
/// ubicación, disponibilidad, expectativa salarial, resumen profesional,
/// habilidades con su nivel y acciones sobre su candidatura.
class PerfilCandidatoPage extends StatefulWidget {
  const PerfilCandidatoPage({
    super.key,
    required this.candidatoId,
    this.candidatoInicial,
    this.postulacion,
    this.oferta,
    this.reclutadorId,
    this.service,
  });

  final String candidatoId;
  final Map<String, dynamic>? candidatoInicial;
  final Map<String, dynamic>? postulacion;
  final Map<String, dynamic>? oferta;
  final String? reclutadorId;
  final PostulacionesService? service;

  @override
  State<PerfilCandidatoPage> createState() => _PerfilCandidatoPageState();
}

class _PerfilCandidatoPageState extends State<PerfilCandidatoPage> {
  late final PostulacionesService _service =
      widget.service ?? PostulacionesService();
  final _chat = ChatService();
  late Future<Map<String, dynamic>> _futuroPerfil = _service
      .obtenerPerfilCandidato(widget.candidatoId);
  late String? _estadoPostulacion = widget.postulacion?['estado'] as String?;
  bool _abriendoChat = false;
  bool _descargandoCv = false;
  bool _actualizandoEstado = false;
  String? _errorAccion;

  void _recargar() {
    setState(() {
      _futuroPerfil = _service.obtenerPerfilCandidato(widget.candidatoId);
    });
  }

  String _etiquetaNivel(String? nivel) => switch (nivel) {
    'AVANZADO' => 'Avanzado',
    'INTERMEDIO' => 'Intermedio',
    'BASICO' => 'Básico',
    _ => 'Declarada',
  };

  StatusVariant _varianteNivel(String? nivel) => switch (nivel) {
    'AVANZADO' => StatusVariant.success,
    'INTERMEDIO' => StatusVariant.warning,
    _ => StatusVariant.neutral,
  };

  Future<void> _abrirChat(Map<String, dynamic> usuario) async {
    if (_abriendoChat) return;
    setState(() {
      _abriendoChat = true;
      _errorAccion = null;
    });
    try {
      final ofertaId =
          (widget.oferta?['id'] ?? widget.postulacion?['ofertaId']) as String?;
      final conversacion = await _chat.abrir(
        usuarioId: widget.candidatoId,
        ofertaId: ofertaId,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatThreadPage(
            conversacion: {
              ...conversacion,
              'interlocutor': conversacion['candidato'] ?? usuario,
            },
            usuarioId: widget.reclutadorId ?? '',
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _errorAccion = error.toString());
    } finally {
      if (mounted) setState(() => _abriendoChat = false);
    }
  }

  Future<void> _descargarCv(String postulacionId, String tituloCv) async {
    if (_descargandoCv) return;
    setState(() {
      _descargandoCv = true;
      _errorAccion = null;
    });
    try {
      final bytes = await _service.descargarCv(postulacionId);
      if (bytes.isEmpty) throw Exception('El archivo del CV está vacío.');
      if (!mounted) return;
      final limpio = tituloCv
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Guardar currículum',
        fileName: '${limpio.isEmpty ? 'CV' : limpio}.pdf',
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
      if (mounted) setState(() => _errorAccion = error.toString());
    } finally {
      if (mounted) setState(() => _descargandoCv = false);
    }
  }

  Future<void> _seleccionarParaEntrevista(String postulacionId) async {
    if (_actualizandoEstado) return;
    setState(() {
      _actualizandoEstado = true;
      _errorAccion = null;
    });
    try {
      await _service.actualizarEstado(postulacionId, 'ENTREVISTA');
      if (!mounted) return;
      setState(() => _estadoPostulacion = 'ENTREVISTA');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Candidato seleccionado para entrevista.'),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _errorAccion = error.toString());
    } finally {
      if (mounted) setState(() => _actualizandoEstado = false);
    }
  }

  void _mostrarTextoCv(String titulo, String? contenido) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _futuroPerfil,
          builder: (context, snapshot) {
            final datos = snapshot.data;
            final usuario =
                (datos?['usuario'] as Map<String, dynamic>?) ??
                widget.candidatoInicial ??
                const <String, dynamic>{};
            final nombre =
                '${usuario['nombre'] ?? ''} ${usuario['apellidos'] ?? ''}'
                    .trim();
            final nombreVisible = nombre.isEmpty ? 'Candidato/a' : nombre;
            final correo = (usuario['email'] as String?)?.trim() ?? '';
            final inicial = nombreVisible[0].toUpperCase();
            final banner = datos?['banner'] as String?;

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Volver',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(height: AppSpacing.gap),
                _CabeceraCandidatoReclutador(
                  nombreCompleto: nombreVisible,
                  correo: correo,
                  inicial: inicial,
                  banner: banner,
                  paraEntrevista: _estadoPostulacion == 'ENTREVISTA',
                ),
                const SizedBox(height: AppSpacing.gap),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: AppSpinner(size: 24)),
                  )
                else if (snapshot.hasError)
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(snapshot.error.toString(), style: AppText.body),
                        const SizedBox(height: AppSpacing.gap),
                        SecondaryButton(
                          label: 'Reintentar',
                          onPressed: _recargar,
                        ),
                      ],
                    ),
                  )
                else
                  _contenidoPerfil(datos ?? const {}, usuario),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _contenidoPerfil(
    Map<String, dynamic> datos,
    Map<String, dynamic> usuario,
  ) {
    final ubicacion = (datos['ubicacion'] as String?)?.trim();
    final disponibilidad = (datos['disponibilidad'] as String?)?.trim();
    final expectativa = (datos['expectativaSalarial'] as num?)?.toInt();
    final cvs = (datos['cvs'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final cvPrincipal = cvs.isEmpty ? null : cvs.first;
    final rawPerfilIa = cvPrincipal?['perfilIa'];
    final perfilIa =
        rawPerfilIa is Map<String, dynamic> ? rawPerfilIa : null;
    final resumenIa = rawPerfilIa is String
        ? rawPerfilIa.trim()
        : (perfilIa?['resumen'] as String?)?.trim();
    final seniorityIa = (perfilIa?['seniority'] as String?)?.trim();
    final sectorIa = (perfilIa?['sector'] as String?)?.trim();
    final rolesIa = (perfilIa?['rolesObjetivo'] as List? ?? const [])
        .whereType<String>()
        .toList();
    final idiomasIa = (perfilIa?['idiomas'] as List? ?? const [])
        .whereType<String>()
        .toList();
    final habilidades = (cvPrincipal?['habilidades'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final postulacion = widget.postulacion;
    final postulacionId = postulacion?['id'] as String?;
    final matchScore = (postulacion?['matchScore'] as num?)?.round();
    final puntuacionIa = (postulacion?['puntuacionIa'] as num?)?.round();
    final motivoIa = (postulacion?['motivoIa'] as String?)?.trim();
    final cartaIa = (postulacion?['cartaIa'] as String?)?.trim();
    final tituloOferta = (widget.oferta?['titulo'] as String?)?.trim();
    final salarioOferta = (widget.oferta?['salario'] as String?)?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (postulacion != null) ...[
          SectionTitle(
            tituloOferta != null && tituloOferta.isNotEmpty
                ? 'Candidatura · $tituloOferta'
                : 'Candidatura a tu oferta',
          ),
          const SizedBox(height: AppSpacing.group),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Compatibilidad con la oferta', style: AppText.h2),
                    ),
                    if (puntuacionIa != null || matchScore != null)
                      MatchIndicator(match: puntuacionIa ?? matchScore ?? 0),
                  ],
                ),
                if (salarioOferta != null && salarioOferta.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.micro),
                  Text('Salario de la oferta: $salarioOferta', style: AppText.meta),
                ],
                if (motivoIa != null && motivoIa.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.group),
                  Text(motivoIa, style: AppText.body),
                ],
                if (cartaIa != null && cartaIa.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.gap),
                  const Divider(),
                  const SizedBox(height: AppSpacing.group),
                  Text('Carta de presentación', style: AppText.meta),
                  const SizedBox(height: AppSpacing.micro),
                  Text(cartaIa, style: AppText.body),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.gap),
        ],
        const SectionTitle('Datos del candidato'),
        const SizedBox(height: AppSpacing.group),
        PanelList(
          children: [
            ListRow(
              title: 'Ubicación',
              lines: [
                ubicacion == null || ubicacion.isEmpty
                    ? 'Sin indicar'
                    : ubicacion,
              ],
            ),
            ListRow(
              title: 'Disponibilidad',
              lines: [
                disponibilidad == null || disponibilidad.isEmpty
                    ? 'Sin indicar'
                    : disponibilidad,
              ],
            ),
            ListRow(
              title: 'Expectativa salarial',
              lines: const ['Brutos al año'],
              trailing: Text(
                expectativa != null
                    ? formatearEurosAnuales(expectativa)
                    : 'Sin indicar',
                style: expectativa != null ? AppText.numInline : AppText.meta,
              ),
            ),
          ],
        ),
        if (resumenIa != null && resumenIa.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.gap),
          const SectionTitle('Resumen profesional'),
          const SizedBox(height: AppSpacing.group),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(resumenIa, style: AppText.body),
                if ((seniorityIa != null && seniorityIa.isNotEmpty) ||
                    (sectorIa != null && sectorIa.isNotEmpty) ||
                    rolesIa.isNotEmpty ||
                    idiomasIa.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.group),
                  Wrap(
                    spacing: AppSpacing.group,
                    runSpacing: AppSpacing.group,
                    children: [
                      if (seniorityIa != null && seniorityIa.isNotEmpty)
                        StatusTag(
                          label: 'Seniority: $seniorityIa',
                          variant: StatusVariant.success,
                        ),
                      if (sectorIa != null && sectorIa.isNotEmpty)
                        StatusTag(label: sectorIa),
                      for (final rol in rolesIa.take(3))
                        StatusTag(label: rol),
                      for (final idioma in idiomasIa)
                        StatusTag(label: idioma),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.gap),
        SectionTitle(
          'Habilidades en su CV',
          trailing: Text('${habilidades.length}', style: AppText.numInline),
        ),
        const SizedBox(height: AppSpacing.group),
        if (habilidades.isEmpty)
          Panel(
            child: Text(
              'El candidato aún no ha declarado habilidades en su CV.',
              style: AppText.mutedBody,
            ),
          )
        else
          PanelList(
            children: [
              for (final item in habilidades)
                ListRow(
                  title:
                      (item['habilidad'] as Map<String, dynamic>?)?['nombre']
                          as String? ??
                      'Habilidad',
                  strongTitle: false,
                  trailing: StatusTag(
                    label: _etiquetaNivel(item['nivel'] as String?),
                    variant: _varianteNivel(item['nivel'] as String?),
                  ),
                ),
            ],
          ),
        if (cvs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.gap),
          const SectionTitle('Currículum'),
          const SizedBox(height: AppSpacing.group),
          PanelList(
            children: [
              for (final cv in cvs)
                ListRow(
                  title: cv['titulo'] as String? ?? 'Currículum',
                  lines: const ['Toca para leer el contenido extraído del CV'],
                  trailing: const StatusTag(label: 'Leer CV'),
                  onTap: () => _mostrarTextoCv(
                    cv['titulo'] as String? ?? 'Currículum',
                    cv['contenidoTexto'] as String?,
                  ),
                ),
            ],
          ),
        ],
        if (_errorAccion != null) ...[
          const SizedBox(height: AppSpacing.gap),
          Notice(message: _errorAccion!, variant: StatusVariant.error),
        ],
        const SizedBox(height: AppSpacing.gap),
        if (widget.reclutadorId != null && widget.reclutadorId!.isNotEmpty) ...[
          PrimaryButton(
            label: 'Chatear con el candidato',
            loading: _abriendoChat,
            loadingLabel: 'Abriendo chat…',
            onPressed: () => _abrirChat(usuario),
          ),
          const SizedBox(height: AppSpacing.group),
        ],
        if (postulacionId != null && postulacionId.isNotEmpty) ...[
          SecondaryButton(
            label: _descargandoCv ? 'Descargando…' : 'Descargar CV en PDF',
            leading: const Icon(Icons.download_outlined, size: 20),
            onPressed: _descargandoCv
                ? null
                : () => _descargarCv(
                    postulacionId,
                    cvPrincipal?['titulo'] as String? ?? 'CV',
                  ),
          ),
          const SizedBox(height: AppSpacing.group),
          if (_estadoPostulacion != 'ENTREVISTA')
            SecondaryButton(
              label: _actualizandoEstado
                  ? 'Actualizando…'
                  : 'Seleccionar para entrevista',
              leading: const Icon(Icons.event_available_outlined, size: 20),
              onPressed: _actualizandoEstado
                  ? null
                  : () => _seleccionarParaEntrevista(postulacionId),
            ),
        ],
      ],
    );
  }
}

class _CabeceraCandidatoReclutador extends StatelessWidget {
  const _CabeceraCandidatoReclutador({
    required this.nombreCompleto,
    required this.correo,
    required this.inicial,
    required this.banner,
    required this.paraEntrevista,
  });

  final String nombreCompleto;
  final String correo;
  final String inicial;
  final String? banner;
  final bool paraEntrevista;

  @override
  Widget build(BuildContext context) {
    final bytes = decodificarImagenBanner(banner);
    final urlRed =
        bytes == null &&
            banner != null &&
            (banner!.startsWith('http://') || banner!.startsWith('https://'))
        ? banner!
        : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: 120,
                width: double.infinity,
                child: bytes != null
                    ? Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 120,
                      )
                    : urlRed != null
                    ? Image.network(
                        urlRed,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 120,
                        errorBuilder: (_, _, _) => _portadaPorDefecto(),
                      )
                    : _portadaPorDefecto(),
              ),
              Positioned(
                left: AppSpacing.gap,
                bottom: -24,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Avatar(
                    initial: inicial,
                    seed: correo.isEmpty ? nombreCompleto : correo,
                    size: 56,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gap,
              0,
              AppSpacing.gap,
              AppSpacing.gap,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenHeader(
                  title: nombreCompleto,
                  subtitle: correo.isEmpty ? null : correo,
                ),
                const SizedBox(height: AppSpacing.group),
                Wrap(
                  spacing: AppSpacing.group,
                  runSpacing: AppSpacing.group,
                  children: [
                    const StatusTag(label: 'Candidato/a'),
                    if (paraEntrevista)
                      const StatusTag(
                        label: 'Seleccionado para entrevista',
                        variant: StatusVariant.success,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _portadaPorDefecto() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
      ),
    ),
  );
}

