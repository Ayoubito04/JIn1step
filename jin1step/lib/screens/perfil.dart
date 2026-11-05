import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../services/auth.service.dart';
import '../services/candidato.service.dart';
import '../widgets/design_system.dart';
import 'red_candidatos.dart';

/// Perfil del usuario. Candidato: foto de portada (banner estilo LinkedIn),
/// ubicación, disponibilidad y expectativa salarial (las ven las empresas al
/// revisar una candidatura), plan y cierre de sesión. Reclutador: identidad y
/// cierre de sesión.
class PerfilPage extends StatefulWidget {
  const PerfilPage({
    super.key,
    required this.usuario,
    this.mostrarAtras = false,
    this.service,
  });

  /// {id, nombre, apellidos, email, rol}, tal como lo devuelve el login.
  final Map<String, dynamic> usuario;
  final bool mostrarAtras;

  /// Opcional para poder inyectar un servicio falso en los tests.
  final CandidatoService? service;

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  late final CandidatoService _service = widget.service ?? CandidatoService();
  late final bool _esCandidato = widget.usuario['rol'] == 'CANDIDATO';
  late Future<_DatosPerfil> _datos = _cargar();
  final Set<String> _modalidadesPreferidas = {'Remoto', 'Híbrido'};
  bool _avisosPushFcm = true;
  bool _subiendoBanner = false;
  bool _subiendoFotoPerfil = false;

  Future<_DatosPerfil> _cargar() async {
    if (!_esCandidato) return const _DatosPerfil();
    final perfil = await _service.obtenerMiPerfil();
    CandidatoService.fotoPerfilActual.value = perfil['fotoPerfil'] as String?;
    // El plan es informativo: si falla, el perfil sigue siendo usable.
    Map<String, dynamic>? suscripcion;
    try {
      suscripcion = await _service.obtenerSuscripcionActiva();
    } catch (_) {}
    return _DatosPerfil(
      ubicacion: perfil['ubicacion'] as String?,
      disponibilidad: perfil['disponibilidad'] as String?,
      expectativaSalarial: (perfil['expectativaSalarial'] as num?)?.toInt(),
      banner: perfil['banner'] as String?,
      fotoPerfil: perfil['fotoPerfil'] as String?,
      seguidoresCount: (perfil['seguidoresCount'] as num?)?.toInt() ?? 0,
      siguiendoCount: (perfil['siguiendoCount'] as num?)?.toInt() ?? 0,
      plan: suscripcion?['tipoPlan'] as String?,
      conSuscripcion: suscripcion != null,
    );
  }

  Future<void> _abrirRed(PestanaRed pestana) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RedCandidatosPage(pestanaInicial: pestana, service: _service),
      ),
    );
    if (mounted) _recargar();
  }

  void _recargar() {
    setState(() {
      _datos = _cargar();
    });
  }

  Future<void> _subirFotoBanner(_DatosPerfil actuales) async {
    if (_subiendoBanner) return;
    try {
      final archivos = await FilePicker.pickFiles(type: FileType.image);
      if (archivos.isEmpty || !mounted) return;
      final archivo = archivos.first;
      final bytes = await archivo.readAsBytes();
      if (bytes.isEmpty) return;

      setState(() => _subiendoBanner = true);
      final actualizado = await _service.subirBannerPerfil(
        nombreArchivo: archivo.name.isEmpty ? 'banner.jpg' : archivo.name,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _datos = Future.value(
          actuales.copyWith(banner: actualizado['banner'] as String?),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de portada actualizada.')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo subir la imagen.')),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoBanner = false);
    }
  }

  Future<void> _quitarFotoBanner(_DatosPerfil actuales) async {
    if (_subiendoBanner) return;
    setState(() => _subiendoBanner = true);
    try {
      await _service.borrarBannerPerfil();
      if (!mounted) return;
      setState(() {
        _datos = Future.value(actuales.copyWith(limpiarBanner: true));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de portada eliminada.')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    } finally {
      if (mounted) setState(() => _subiendoBanner = false);
    }
  }

  Future<void> _subirFotoPerfil(_DatosPerfil actuales) async {
    if (_subiendoFotoPerfil) return;
    try {
      final archivos = await FilePicker.pickFiles(type: FileType.image);
      if (archivos.isEmpty || !mounted) return;
      final archivo = archivos.first;
      final bytes = await archivo.readAsBytes();
      if (bytes.isEmpty) return;

      setState(() => _subiendoFotoPerfil = true);
      final actualizado = await _service.subirFotoPerfil(
        nombreArchivo: archivo.name.isEmpty ? 'avatar.jpg' : archivo.name,
        bytes: bytes,
      );
      CandidatoService.fotoPerfilActual.value =
          actualizado['fotoPerfil'] as String?;
      if (!mounted) return;
      setState(() {
        _datos = Future.value(
          actuales.copyWith(fotoPerfil: actualizado['fotoPerfil'] as String?),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada.')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo subir la foto de perfil.')),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoFotoPerfil = false);
    }
  }

  Future<void> _quitarFotoPerfil(_DatosPerfil actuales) async {
    if (_subiendoFotoPerfil) return;
    setState(() => _subiendoFotoPerfil = true);
    try {
      await _service.borrarFotoPerfil();
      CandidatoService.fotoPerfilActual.value = null;
      if (!mounted) return;
      setState(() {
        _datos = Future.value(actuales.copyWith(limpiarFotoPerfil: true));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil eliminada.')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    } finally {
      if (mounted) setState(() => _subiendoFotoPerfil = false);
    }
  }

  Future<void> _editar(_DatosPerfil actuales) async {
    final guardado = await showModalBottomSheet<_DatosPerfil>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditarPerfil(actuales: actuales, service: _service),
    );
    if (guardado == null || !mounted) return;
    setState(() {
      _datos = Future.value(guardado);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Perfil actualizado.')));
  }

  Future<void> _cerrarSesion() async {
    CandidatoService.fotoPerfilActual.value = null;
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  String get _nombreCompleto =>
      '${widget.usuario['nombre'] ?? ''} ${widget.usuario['apellidos'] ?? ''}'
          .trim();

  @override
  Widget build(BuildContext context) {
    final nombre = (widget.usuario['nombre'] as String? ?? '').trim();
    final correo = widget.usuario['email'] as String? ?? '';
    final inicial = nombre.isEmpty ? 'U' : nombre[0].toUpperCase();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            if (widget.mostrarAtras) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: AppIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Volver a Inicio',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: AppSpacing.gap),
            ],
            if (!_esCandidato) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Avatar(initial: inicial, seed: correo, size: 48),
                  const SizedBox(width: AppSpacing.gap),
                  Expanded(
                    child: ScreenHeader(
                      title: _nombreCompleto.isEmpty
                          ? 'Mi perfil'
                          : _nombreCompleto,
                      subtitle: correo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.group),
              const Align(
                alignment: Alignment.centerLeft,
                child: StatusTag(label: 'Reclutador/a'),
              ),
            ] else ...[
              FutureBuilder<_DatosPerfil>(
                future: _datos,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CabeceraPerfilConBanner(
                          nombreCompleto: _nombreCompleto.isEmpty
                              ? 'Mi perfil'
                              : _nombreCompleto,
                          correo: correo,
                          inicial: inicial,
                          banner: null,
                          subiendo: false,
                          onSubirFoto: null,
                          onQuitarFoto: null,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: AppSpinner(size: 24)),
                        ),
                      ],
                    );
                  }
                  if (snapshot.hasError) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CabeceraPerfilConBanner(
                          nombreCompleto: _nombreCompleto.isEmpty
                              ? 'Mi perfil'
                              : _nombreCompleto,
                          correo: correo,
                          inicial: inicial,
                          banner: null,
                          subiendo: false,
                          onSubirFoto: null,
                          onQuitarFoto: null,
                        ),
                        const SizedBox(height: AppSpacing.gap),
                        Panel(
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
                                onPressed: _recargar,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  final datos = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CabeceraPerfilConBanner(
                        nombreCompleto: _nombreCompleto.isEmpty
                            ? 'Mi perfil'
                            : _nombreCompleto,
                        correo: correo,
                        inicial: inicial,
                        banner: datos.banner,
                        fotoPerfil: datos.fotoPerfil,
                        subiendo: _subiendoBanner,
                        subiendoFotoPerfil: _subiendoFotoPerfil,
                        seguidoresCount: datos.seguidoresCount,
                        siguiendoCount: datos.siguiendoCount,
                        onSubirFoto: () => _subirFotoBanner(datos),
                        onQuitarFoto: datos.tieneFotoBanner
                            ? () => _quitarFotoBanner(datos)
                            : null,
                        onSubirFotoPerfil: () => _subirFotoPerfil(datos),
                        onQuitarFotoPerfil: datos.tieneFotoPerfil
                            ? () => _quitarFotoPerfil(datos)
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.gap),
                      _datosCandidato(datos),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: AppSpacing.gap),
            SecondaryButton(
              label: 'Cerrar sesión',
              leading: const Icon(Icons.logout, size: 20),
              onPressed: _cerrarSesion,
            ),
          ],
        ),
      ),
    );
  }

  Widget _datosCandidato(_DatosPerfil datos) {
    final pasosCompletados =
        1 +
        (datos.tieneFotoBanner ? 1 : 0) +
        ((datos.ubicacion ?? '').trim().isNotEmpty ? 1 : 0) +
        ((datos.disponibilidad ?? '').trim().isNotEmpty ? 1 : 0) +
        (datos.expectativaSalarial != null ? 1 : 0);
    final porcentajeCompletado = pasosCompletados * 20;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Panel(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Completado de perfil', style: AppText.h2),
                    const SizedBox(height: 2),
                    Text(
                      '¿Cómo me ven las empresas y qué busco?',
                      style: AppText.mutedBody,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.group),
              Text('$porcentajeCompletado %', style: AppText.numInline),
              const SizedBox(width: AppSpacing.group),
              Steps(filled: pasosCompletados),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.gap),
        const SectionTitle('Datos para las empresas'),
        const SizedBox(height: AppSpacing.group),
        PanelList(
          children: [
            ListRow(
              title: 'Ubicación',
              lines: [datos.ubicacion ?? 'Sin indicar'],
              onTap: () => _editar(datos),
            ),
            ListRow(
              title: 'Disponibilidad',
              lines: [datos.disponibilidad ?? 'Sin indicar'],
              onTap: () => _editar(datos),
            ),
            ListRow(
              title: 'Expectativa salarial',
              lines: const ['Brutos al año'],
              trailing: Text(
                datos.expectativaSalarial != null
                    ? formatearEurosAnuales(datos.expectativaSalarial!)
                    : 'Sin indicar',
                style: datos.expectativaSalarial != null
                    ? AppText.numInline
                    : AppText.meta,
              ),
              onTap: () => _editar(datos),
            ),
            ListRow(
              title: 'Foto de perfil',
              lines: [
                datos.tieneFotoPerfil
                    ? 'Foto de perfil activa · Toca para cambiarla'
                    : 'Sube una foto circular estilo LinkedIn para tu avatar',
              ],
              trailing: StatusTag(
                label: datos.tieneFotoPerfil ? 'Personalizada' : 'Por defecto',
                variant: datos.tieneFotoPerfil
                    ? StatusVariant.success
                    : StatusVariant.neutral,
              ),
              onTap: () => _subirFotoPerfil(datos),
            ),
            ListRow(
              title: 'Foto de portada (banner)',
              lines: [
                datos.tieneFotoBanner
                    ? 'Imagen de portada activa · Toca para cambiarla'
                    : 'Sube una imagen estilo LinkedIn para tu cabecera',
              ],
              trailing: StatusTag(
                label: datos.tieneFotoBanner ? 'Personalizada' : 'Por defecto',
                variant: datos.tieneFotoBanner
                    ? StatusVariant.success
                    : StatusVariant.neutral,
              ),
              onTap: () => _subirFotoBanner(datos),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.gap),
        const SectionTitle('Red profesional'),
        const SizedBox(height: AppSpacing.group),
        PanelList(
          children: [
            ListRow(
              title: 'Seguidores',
              lines: const ['Candidatos que siguen tu perfil'],
              trailing: Text(
                '${datos.seguidoresCount}',
                style: AppText.numInline,
              ),
              onTap: () => _abrirRed(PestanaRed.seguidores),
            ),
            ListRow(
              title: 'Siguiendo',
              lines: const ['Perfiles que sigues actualmente'],
              trailing: Text(
                '${datos.siguiendoCount}',
                style: AppText.numInline,
              ),
              onTap: () => _abrirRed(PestanaRed.siguiendo),
            ),
            ListRow(
              title: 'Explorar candidatos',
              lines: const [
                'Busca profesionales afines, consulta su perfil y síguelos en un clic',
              ],
              onTap: () => _abrirRed(PestanaRed.explorar),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.gap),
        const SectionTitle('Modalidad preferida'),
        const SizedBox(height: AppSpacing.group),
        Wrap(
          spacing: AppSpacing.group,
          runSpacing: AppSpacing.group,
          children: [
            for (final opcion in const ['Remoto', 'Híbrido', 'Presencial'])
              FilterChipButton(
                label: opcion,
                selected: _modalidadesPreferidas.contains(opcion),
                onTap: () => setState(() {
                  if (_modalidadesPreferidas.contains(opcion) &&
                      _modalidadesPreferidas.length > 1) {
                    _modalidadesPreferidas.remove(opcion);
                  } else {
                    _modalidadesPreferidas.add(opcion);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.gap),
        const SectionTitle('Suscripción'),
        const SizedBox(height: AppSpacing.group),
        PanelList(
          children: [
            ListRow(
              title: 'Autopiloto de postulaciones',
              lines: const ['5 €/mes · 50 €/año'],
              trailing: StatusTag(
                label: datos.etiquetaPlan,
                variant: datos.conSuscripcion
                    ? StatusVariant.success
                    : StatusVariant.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.gap),
        const SectionTitle('Avisos y accesibilidad'),
        const SizedBox(height: AppSpacing.group),
        PanelList(
          children: [
            ListRow(
              title: 'Avisos push de entrevistas (FCM)',
              lines: const [
                'Recibir aviso cuando una empresa te seleccione para entrevista.',
              ],
              trailing: AppSwitch(
                value: _avisosPushFcm,
                label: 'Avisos push de entrevistas (FCM)',
                onChanged: (v) => setState(() => _avisosPushFcm = v),
              ),
            ),
            ListRow(
              title: 'Reducir movimiento en la interfaz',
              lines: const [
                'Desactiva las animaciones y mantiene el fondo estático.',
              ],
              trailing: AppSwitch(
                value: reducirMovimientoManual.value,
                label: 'Reducir movimiento en la interfaz',
                onChanged: (v) =>
                    setState(() => reducirMovimientoManual.value = v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Formatea un entero en euros con separador de miles («38.000 €»).
String formatearEurosAnuales(int euros) {
  final str = euros.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(str[i]);
  }
  return '$buffer €';
}

/// Decodifica una imagen en formato `data:image/...;base64,...` a bytes.
Uint8List? decodificarImagenBanner(String? banner) {
  if (banner == null) return null;
  final limpio = banner.trim();
  if (!limpio.startsWith('data:image/')) return null;
  final coma = limpio.indexOf(',');
  if (coma == -1 || coma + 1 >= limpio.length) return null;
  try {
    return base64Decode(limpio.substring(coma + 1));
  } catch (_) {
    return null;
  }
}

/// Cabecera de perfil con foto de portada (banner estilo LinkedIn) y avatar
/// superpuesto sobre el borde inferior del banner.
class _CabeceraPerfilConBanner extends StatelessWidget {
  const _CabeceraPerfilConBanner({
    required this.nombreCompleto,
    required this.correo,
    required this.inicial,
    required this.banner,
    required this.subiendo,
    required this.onSubirFoto,
    required this.onQuitarFoto,
    this.fotoPerfil,
    this.subiendoFotoPerfil = false,
    this.onSubirFotoPerfil,
    this.onQuitarFotoPerfil,
    this.seguidoresCount = 0,
    this.siguiendoCount = 0,
  });

  final String nombreCompleto;
  final String correo;
  final String inicial;
  final String? banner;
  final String? fotoPerfil;
  final bool subiendo;
  final bool subiendoFotoPerfil;
  final VoidCallback? onSubirFoto;
  final VoidCallback? onQuitarFoto;
  final VoidCallback? onSubirFotoPerfil;
  final VoidCallback? onQuitarFotoPerfil;
  final int seguidoresCount;
  final int siguiendoCount;

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
              // Foto de portada (banner estilo LinkedIn)
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
                        errorBuilder: (_, _, _) => const _FondoPortadaPorDefecto(),
                      )
                    : const _FondoPortadaPorDefecto(),
              ),
              // Acciones en la esquina superior derecha para subir/quitar foto
              if (onSubirFoto != null)
                Positioned(
                  top: AppSpacing.group,
                  right: AppSpacing.group,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onQuitarFoto != null && !subiendo) ...[
                        Tooltip(
                          message: 'Quitar foto de portada',
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.58),
                            borderRadius: BorderRadius.circular(AppRadii.control),
                            child: InkWell(
                              onTap: onQuitarFoto,
                              borderRadius: BorderRadius.circular(
                                AppRadii.control,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.micro),
                      ],
                      Material(
                        color: Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        child: InkWell(
                          onTap: subiendo ? null : onSubirFoto,
                          borderRadius: BorderRadius.circular(AppRadii.control),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (subiendo)
                                  const SizedBox.square(
                                    dimension: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.photo_camera_outlined,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                const SizedBox(width: 6),
                                Text(
                                  subiendo
                                      ? 'Subiendo…'
                                      : (bytes != null || urlRed != null
                                            ? 'Cambiar portada'
                                            : 'Subir foto de portada'),
                                  style: AppText.meta.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Avatar superpuesto en el borde inferior izquierdo (estilo LinkedIn)
              Positioned(
                left: AppSpacing.gap,
                bottom: -24,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: subiendoFotoPerfil ? null : onSubirFotoPerfil,
                      child: Material(
                        color: AppColors.surface,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: subiendoFotoPerfil ? null : onSubirFotoPerfil,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Avatar(
                              initial: inicial,
                              seed: correo,
                              size: 56,
                              imageUrl: fotoPerfil,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (onSubirFotoPerfil != null)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Tooltip(
                          message: 'Cambiar foto de perfil',
                          child: Material(
                            color: AppColors.ink,
                            shape: const CircleBorder(
                              side: BorderSide(
                                color: AppColors.surface,
                                width: 2,
                              ),
                            ),
                            child: InkWell(
                              onTap: subiendoFotoPerfil
                                  ? null
                                  : onSubirFotoPerfil,
                              customBorder: const CircleBorder(),
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: subiendoFotoPerfil
                                    ? const SizedBox.square(
                                        dimension: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.photo_camera_outlined,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (onQuitarFotoPerfil != null && !subiendoFotoPerfil)
                      Positioned(
                        left: -4,
                        bottom: -2,
                        child: Tooltip(
                          message: 'Quitar foto de perfil',
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: const CircleBorder(
                              side: BorderSide(
                                color: AppColors.surface,
                                width: 1.5,
                              ),
                            ),
                            child: InkWell(
                              onTap: onQuitarFotoPerfil,
                              customBorder: const CircleBorder(),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  size: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
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
                ScreenHeader(title: nombreCompleto, subtitle: correo),
                const SizedBox(height: AppSpacing.group),
                Wrap(
                  spacing: AppSpacing.group,
                  runSpacing: AppSpacing.group,
                  children: [
                    const StatusTag(label: 'Candidato/a'),
                    StatusTag(
                      label:
                          '$seguidoresCount ${seguidoresCount == 1 ? 'seguidor' : 'seguidores'}',
                    ),
                    StatusTag(label: '$siguiendoCount siguiendo'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Portada por defecto cuando el candidato aún no ha subido una foto.
class _FondoPortadaPorDefecto extends StatelessWidget {
  const _FondoPortadaPorDefecto();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
        ),
      ),
    );
  }
}

class _DatosPerfil {
  const _DatosPerfil({
    this.ubicacion,
    this.disponibilidad,
    this.expectativaSalarial,
    this.banner,
    this.fotoPerfil,
    this.seguidoresCount = 0,
    this.siguiendoCount = 0,
    this.plan,
    this.conSuscripcion = false,
  });

  final String? ubicacion;
  final String? disponibilidad;
  final int? expectativaSalarial;
  final String? banner;
  final String? fotoPerfil;
  final int seguidoresCount;
  final int siguiendoCount;
  final String? plan;
  final bool conSuscripcion;

  bool get tieneFotoBanner =>
      decodificarImagenBanner(banner) != null ||
      (banner != null &&
          (banner!.startsWith('http://') || banner!.startsWith('https://')));

  bool get tieneFotoPerfil =>
      decodificarImagenBanner(fotoPerfil) != null ||
      (fotoPerfil != null &&
          (fotoPerfil!.startsWith('http://') ||
              fotoPerfil!.startsWith('https://')));

  _DatosPerfil copyWith({
    String? ubicacion,
    String? disponibilidad,
    int? expectativaSalarial,
    String? banner,
    String? fotoPerfil,
    int? seguidoresCount,
    int? siguiendoCount,
    bool limpiarBanner = false,
    bool limpiarFotoPerfil = false,
  }) => _DatosPerfil(
    ubicacion: ubicacion ?? this.ubicacion,
    disponibilidad: disponibilidad ?? this.disponibilidad,
    expectativaSalarial: expectativaSalarial ?? this.expectativaSalarial,
    banner: limpiarBanner ? null : (banner ?? this.banner),
    fotoPerfil: limpiarFotoPerfil ? null : (fotoPerfil ?? this.fotoPerfil),
    seguidoresCount: seguidoresCount ?? this.seguidoresCount,
    siguiendoCount: siguiendoCount ?? this.siguiendoCount,
    plan: plan,
    conSuscripcion: conSuscripcion,
  );

  String get etiquetaPlan {
    if (!conSuscripcion) return 'Sin suscripción';
    return switch (plan) {
      'MENSUAL' => 'Plan mensual',
      'ANUAL' => 'Plan anual',
      _ => 'Suscripción activa',
    };
  }
}

/// Hoja con los datos del perfil. Un campo vacío borra ese dato.
class _EditarPerfil extends StatefulWidget {
  const _EditarPerfil({required this.actuales, required this.service});

  final _DatosPerfil actuales;
  final CandidatoService service;

  @override
  State<_EditarPerfil> createState() => _EditarPerfilState();
}

class _EditarPerfilState extends State<_EditarPerfil> {
  final _formKey = GlobalKey<FormState>();
  late final _ubicacion = TextEditingController(
    text: widget.actuales.ubicacion ?? '',
  );
  late final _disponibilidad = TextEditingController(
    text: widget.actuales.disponibilidad ?? '',
  );
  late final _expectativaSalarial = TextEditingController(
    text: widget.actuales.expectativaSalarial?.toString() ?? '',
  );
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _ubicacion.dispose();
    _disponibilidad.dispose();
    _expectativaSalarial.dispose();
    super.dispose();
  }

  // Mismos límites que actualizarPerfilSchema del backend (150 y 200).
  String? _validarUbicacion(String? valor) => (valor ?? '').trim().length > 150
      ? 'La ubicación admite como máximo 150 caracteres'
      : null;

  String? _validarDisponibilidad(String? valor) =>
      (valor ?? '').trim().length > 200
      ? 'La disponibilidad admite como máximo 200 caracteres'
      : null;

  int? _parsearSalario(String bruto) {
    final limpio = bruto.replaceAll(RegExp(r'[.\s€]'), '').trim();
    if (limpio.isEmpty) return null;
    return int.tryParse(limpio);
  }

  String? _validarSalario(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return null;
    final numero = _parsearSalario(texto);
    if (numero == null) {
      return 'Introduce una cifra entera en euros (ej. 38000)';
    }
    if (numero < 1000 || numero > 500000) {
      return 'La expectativa salarial debe estar entre 1.000 y 500.000 €';
    }
    return null;
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final ubicacion = _ubicacion.text.trim();
    final disponibilidad = _disponibilidad.text.trim();
    final salario = _parsearSalario(_expectativaSalarial.text);
    try {
      await widget.service.guardarMiPerfil(
        ubicacion: ubicacion.isEmpty ? null : ubicacion,
        disponibilidad: disponibilidad.isEmpty ? null : disponibilidad,
        expectativaSalarial: salario,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        _DatosPerfil(
          ubicacion: ubicacion.isEmpty ? null : ubicacion,
          disponibilidad: disponibilidad.isEmpty ? null : disponibilidad,
          expectativaSalarial: salario,
          banner: widget.actuales.banner,
          fotoPerfil: widget.actuales.fotoPerfil,
          seguidoresCount: widget.actuales.seguidoresCount,
          siguiendoCount: widget.actuales.siguiendoCount,
          plan: widget.actuales.plan,
          conSuscripcion: widget.actuales.conSuscripcion,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.micro,
        AppSpacing.screen,
        AppSpacing.screen + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Datos para las empresas'),
            const SizedBox(height: AppSpacing.gap),
            AppTextField(
              controller: _ubicacion,
              enabled: !_guardando,
              label: 'Ubicación',
              hint: 'Madrid, España',
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.addressCity],
              validator: _validarUbicacion,
            ),
            const SizedBox(height: AppSpacing.gap),
            AppTextField(
              controller: _disponibilidad,
              enabled: !_guardando,
              label: 'Disponibilidad',
              hint: 'Inmediata',
              textInputAction: TextInputAction.next,
              validator: _validarDisponibilidad,
            ),
            const SizedBox(height: AppSpacing.gap),
            AppTextField(
              controller: _expectativaSalarial,
              enabled: !_guardando,
              label: 'Expectativa salarial (€ brutos/año)',
              hint: '38000',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              validator: _validarSalario,
              onSubmitted: (_) => _guardar(),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.gap),
              Notice(message: _error!, variant: StatusVariant.error),
            ],
            const SizedBox(height: AppSpacing.gap),
            PrimaryButton(
              label: 'Guardar cambios',
              loading: _guardando,
              loadingLabel: 'Guardando…',
              onPressed: _guardar,
            ),
          ],
        ),
      ),
    ),
  );
}
