import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../services/auth.service.dart';
import '../services/candidato.service.dart';
import '../widgets/design_system.dart';

/// Perfil del usuario. Candidato: ubicación y disponibilidad (las ven las
/// empresas al revisar una candidatura), plan y cierre de sesión. Reclutador:
/// identidad y cierre de sesión.
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

  Future<_DatosPerfil> _cargar() async {
    if (!_esCandidato) return const _DatosPerfil();
    final perfil = await _service.obtenerMiPerfil();
    // El plan es informativo: si falla, el perfil sigue siendo usable.
    Map<String, dynamic>? suscripcion;
    try {
      suscripcion = await _service.obtenerSuscripcionActiva();
    } catch (_) {}
    return _DatosPerfil(
      ubicacion: perfil['ubicacion'] as String?,
      disponibilidad: perfil['disponibilidad'] as String?,
      plan: suscripcion?['tipoPlan'] as String?,
      conSuscripcion: suscripcion != null,
    );
  }

  void _recargar() {
    setState(() {
      _datos = _cargar();
    });
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Avatar(
                  initial: nombre.isEmpty ? 'U' : nombre[0].toUpperCase(),
                  seed: correo,
                ),
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
            Align(
              alignment: Alignment.centerLeft,
              child: StatusTag(
                label: _esCandidato ? 'Candidato/a' : 'Reclutador/a',
              ),
            ),
            if (_esCandidato) ...[
              const SizedBox(height: AppSpacing.gap),
              FutureBuilder<_DatosPerfil>(
                future: _datos,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: AppSpinner(size: 24)),
                    );
                  }
                  if (snapshot.hasError) {
                    return Panel(
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
                    );
                  }
                  return _datosCandidato(snapshot.data!);
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

  Widget _datosCandidato(_DatosPerfil datos) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
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
        ],
      ),
      const SizedBox(height: AppSpacing.gap),
      const SectionTitle('Suscripción'),
      const SizedBox(height: AppSpacing.group),
      PanelList(
        children: [
          ListRow(
            title: 'Autopiloto de postulaciones',
            trailing: StatusTag(
              label: datos.etiquetaPlan,
              variant: datos.conSuscripcion
                  ? StatusVariant.success
                  : StatusVariant.warning,
            ),
          ),
        ],
      ),
    ],
  );
}

class _DatosPerfil {
  const _DatosPerfil({
    this.ubicacion,
    this.disponibilidad,
    this.plan,
    this.conSuscripcion = false,
  });

  final String? ubicacion;
  final String? disponibilidad;
  final String? plan;
  final bool conSuscripcion;

  String get etiquetaPlan {
    if (!conSuscripcion) return 'Sin suscripción';
    return switch (plan) {
      'MENSUAL' => 'Plan mensual',
      'ANUAL' => 'Plan anual',
      _ => 'Suscripción activa',
    };
  }
}

/// Hoja con los dos datos del perfil. Un campo vacío borra ese dato.
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
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _ubicacion.dispose();
    _disponibilidad.dispose();
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
    try {
      await widget.service.guardarMiPerfil(
        ubicacion: ubicacion.isEmpty ? null : ubicacion,
        disponibilidad: disponibilidad.isEmpty ? null : disponibilidad,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        _DatosPerfil(
          ubicacion: ubicacion.isEmpty ? null : ubicacion,
          disponibilidad: disponibilidad.isEmpty ? null : disponibilidad,
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
              textInputAction: TextInputAction.done,
              validator: _validarDisponibilidad,
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
