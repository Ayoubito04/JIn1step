import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/candidato.service.dart';
import '../widgets/design_system.dart';
import 'perfil.dart';
import 'perfil_candidato.dart';

enum PestanaRed { explorar, siguiendo, seguidores }

/// Red profesional entre candidatos (estilo LinkedIn):
/// buscador por nombre/rol/ubicación/habilidades, pestañas Explorar, Siguiendo
/// y Seguidores, seguimiento en 1 clic y acceso al perfil público de cada candidato.
class RedCandidatosPage extends StatefulWidget {
  const RedCandidatosPage({
    super.key,
    this.pestanaInicial = PestanaRed.explorar,
    this.service,
  });

  final PestanaRed pestanaInicial;
  final CandidatoService? service;

  @override
  State<RedCandidatosPage> createState() => _RedCandidatosPageState();
}

class _RedCandidatosPageState extends State<RedCandidatosPage> {
  late final CandidatoService _service = widget.service ?? CandidatoService();
  final _busqueda = TextEditingController();
  late PestanaRed _pestana = widget.pestanaInicial;
  late Future<Map<String, dynamic>> _futuroRed = _cargar();
  final Set<String> _procesandoIds = {};
  String? _errorAccion;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _cargar() =>
      _service.obtenerRedCandidatos(busqueda: _busqueda.text);

  Future<void> _recargar() async {
    final nuevo = _cargar();
    setState(() {
      _errorAccion = null;
      _futuroRed = nuevo;
    });
    await nuevo;
  }

  Future<void> _alternarSeguimiento(Map<String, dynamic> candidato) async {
    final id = candidato['id'] as String? ?? '';
    if (id.isEmpty || _procesandoIds.contains(id)) return;
    final loSigo = candidato['loSigo'] == true;

    setState(() {
      _errorAccion = null;
      _procesandoIds.add(id);
    });
    try {
      if (loSigo) {
        await _service.dejarDeSeguirCandidato(id);
      } else {
        await _service.seguirCandidato(id);
      }
      if (!mounted) return;
      await _recargar();
    } catch (error) {
      if (mounted) setState(() => _errorAccion = error.toString());
    } finally {
      if (mounted) setState(() => _procesandoIds.remove(id));
    }
  }

  Future<void> _abrirPerfilCandidato(Map<String, dynamic> candidato) async {
    final id = candidato['id'] as String? ?? '';
    if (id.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerfilCandidatoPage(
          candidatoId: id,
          candidatoInicial: candidato,
          esVistaCandidato: true,
          candidatoService: _service,
        ),
      ),
    );
    if (mounted) await _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _recargar,
          child: FutureBuilder<Map<String, dynamic>>(
            future: _futuroRed,
            builder: (context, snapshot) {
              final datos = snapshot.data;
              final seguidoresCount =
                  (datos?['seguidoresCount'] as num?)?.toInt() ?? 0;
              final siguiendoCount =
                  (datos?['siguiendoCount'] as num?)?.toInt() ?? 0;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                  const ScreenHeader(
                    title: 'Red profesional',
                    subtitle:
                        'Conecta con otros candidatos, consulta sus perfiles y síguelos en un clic.',
                  ),
                  const SizedBox(height: AppSpacing.gap),
                  KpiGrid(
                    items: [
                      KpiItem(
                        'Seguidores',
                        '$seguidoresCount',
                        onTap: () =>
                            setState(() => _pestana = PestanaRed.seguidores),
                      ),
                      KpiItem(
                        'Siguiendo',
                        '$siguiendoCount',
                        onTap: () =>
                            setState(() => _pestana = PestanaRed.siguiendo),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.gap),
                  SearchField(
                    controller: _busqueda,
                    label: 'Buscar candidatos',
                    hint: 'Nombre, rol, ubicación o habilidad (React, Madrid…)',
                    onChanged: (_) => _recargar(),
                  ),
                  const SizedBox(height: AppSpacing.gap),
                  Wrap(
                    spacing: AppSpacing.group,
                    runSpacing: AppSpacing.group,
                    children: [
                      FilterChipButton(
                        label: 'Explorar',
                        selected: _pestana == PestanaRed.explorar,
                        onTap: () =>
                            setState(() => _pestana = PestanaRed.explorar),
                      ),
                      FilterChipButton(
                        label: 'Siguiendo · $siguiendoCount',
                        selected: _pestana == PestanaRed.siguiendo,
                        onTap: () =>
                            setState(() => _pestana = PestanaRed.siguiendo),
                      ),
                      FilterChipButton(
                        label: 'Seguidores · $seguidoresCount',
                        selected: _pestana == PestanaRed.seguidores,
                        onTap: () =>
                            setState(() => _pestana = PestanaRed.seguidores),
                      ),
                    ],
                  ),
                  if (_errorAccion != null) ...[
                    const SizedBox(height: AppSpacing.gap),
                    Notice(
                      message: _errorAccion!,
                      variant: StatusVariant.error,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.gap),
                  ..._contenidoLista(snapshot, datos),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _contenidoLista(
    AsyncSnapshot<Map<String, dynamic>> snapshot,
    Map<String, dynamic>? datos,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting && datos == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: AppSpinner(size: 24)),
        ),
      ];
    }
    if (snapshot.hasError && datos == null) {
      return [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(snapshot.error.toString(), style: AppText.body),
              const SizedBox(height: AppSpacing.gap),
              SecondaryButton(label: 'Reintentar', onPressed: _recargar),
            ],
          ),
        ),
      ];
    }

    final claveLista = switch (_pestana) {
      PestanaRed.explorar => 'descubrir',
      PestanaRed.siguiendo => 'siguiendo',
      PestanaRed.seguidores => 'seguidores',
    };
    final lista = (datos?[claveLista] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    if (lista.isEmpty) {
      final mensajeVacio = switch (_pestana) {
        PestanaRed.explorar =>
          'No se encontraron candidatos con ese criterio de búsqueda.',
        PestanaRed.siguiendo =>
          'Aún no sigues a ningún candidato. Explora la comunidad para empezar a seguir perfiles.',
        PestanaRed.seguidores =>
          'Todavía no tienes seguidores. Completa tu perfil y sigue a otros candidatos.',
      };
      return [
        Panel(child: Text(mensajeVacio, style: AppText.mutedBody)),
      ];
    }

    return [
      for (var i = 0; i < lista.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpacing.group),
        _TarjetaCandidatoRed(
          candidato: lista[i],
          procesando: _procesandoIds.contains(lista[i]['id'] as String? ?? ''),
          onTapPerfil: () => _abrirPerfilCandidato(lista[i]),
          onAlternarSeguimiento: () => _alternarSeguimiento(lista[i]),
        ),
      ],
    ];
  }
}

class _TarjetaCandidatoRed extends StatelessWidget {
  const _TarjetaCandidatoRed({
    required this.candidato,
    required this.procesando,
    required this.onTapPerfil,
    required this.onAlternarSeguimiento,
  });

  final Map<String, dynamic> candidato;
  final bool procesando;
  final VoidCallback onTapPerfil;
  final VoidCallback onAlternarSeguimiento;

  @override
  Widget build(BuildContext context) {
    final nombre =
        '${candidato['nombre'] ?? ''} ${candidato['apellidos'] ?? ''}'.trim();
    final nombreVisible = nombre.isEmpty ? 'Candidato/a' : nombre;
    final inicial = nombreVisible[0].toUpperCase();
    final titular = (candidato['titular'] as String?)?.trim() ?? '';
    final ubicacion = (candidato['ubicacion'] as String?)?.trim() ?? '';
    final disponibilidad =
        (candidato['disponibilidad'] as String?)?.trim() ?? '';
    final banner = candidato['banner'] as String?;
    final bannerBytes = decodificarImagenBanner(banner);
    final habilidades = (candidato['habilidades'] as List? ?? const [])
        .whereType<String>()
        .toList();
    final seguidoresCount =
        (candidato['seguidoresCount'] as num?)?.toInt() ?? 0;
    final loSigo = candidato['loSigo'] == true;
    final meSigue = candidato['meSigue'] == true;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTapPerfil,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (bannerBytes != null)
              SizedBox(
                height: 64,
                width: double.infinity,
                child: Image.memory(bannerBytes, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.gap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Avatar(
                        initial: inicial,
                        seed: candidato['email'] as String? ?? nombreVisible,
                        size: 44,
                        imageUrl: candidato['fotoPerfil'] as String?,
                      ),
                      const SizedBox(width: AppSpacing.group),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombreVisible, style: AppText.h2),
                            if (titular.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                titular,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.mutedBody,
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              [
                                '$seguidoresCount ${seguidoresCount == 1 ? 'seguidor' : 'seguidores'}',
                                if (ubicacion.isNotEmpty) ubicacion,
                                if (disponibilidad.isNotEmpty) disponibilidad,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.meta,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.group),
                      _BotonSeguirRed(
                        loSigo: loSigo,
                        procesando: procesando,
                        onTap: onAlternarSeguimiento,
                      ),
                    ],
                  ),
                  if (meSigue || habilidades.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.group),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (meSigue)
                          const StatusTag(
                            label: 'Te sigue',
                            variant: StatusVariant.success,
                          ),
                        for (final hab in habilidades.take(5))
                          StatusTag(label: hab),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonSeguirRed extends StatelessWidget {
  const _BotonSeguirRed({
    required this.loSigo,
    required this.procesando,
    required this.onTap,
  });

  final bool loSigo;
  final bool procesando;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: loSigo ? AppColors.surface : AppColors.ink,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        side: BorderSide(color: loSigo ? AppColors.control : AppColors.ink),
      ),
      child: InkWell(
        onTap: procesando ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (procesando)
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      loSigo ? AppColors.text : AppColors.white,
                    ),
                  ),
                )
              else
                Icon(
                  loSigo ? Icons.check : Icons.person_add_alt_1_outlined,
                  size: 16,
                  color: loSigo ? AppColors.text : AppColors.white,
                ),
              const SizedBox(width: 6),
              Text(
                loSigo ? 'Siguiendo' : 'Seguir',
                style: AppText.button.copyWith(
                  color: loSigo ? AppColors.text : AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

