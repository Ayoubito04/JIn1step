import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/google_auth_config.dart';
import '../services/auth.service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/design_system.dart';
import '../widgets/google_sign_in_web_button_stub.dart'
    if (dart.library.html) '../widgets/google_sign_in_web_button.dart'
    as google_web;
import 'login.dart' show GoogleLogoMark, inicializarGoogleSignIn;
// home.dart NO se importa: se navega con pushNamedAndRemoveUntil('/home', ...),
// la ruta con nombre que ya registra main.dart, sin referenciar la clase Home.

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.auth});

  /// Opcional para poder inyectar un servicio falso en los tests.
  final AuthService? auth;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  // El diseño tiene un único campo "Nombre completo" (nombre y apellidos); al
  // enviar se separa en nombre + apellidos, que es lo que exige el backend.
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  late final AuthService _auth = widget.auth ?? AuthService();

  // Por defecto candidato: es el caso más común, y así el formulario nunca
  // se envía sin rol (el backend lo exige).
  Rol _rol = Rol.candidato;
  bool _cargando = false;
  bool _googlePreparado = false;
  String? _errorGoogle;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleEvents;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_prepararGoogle());
  }

  Future<void> _prepararGoogle() async {
    if (kIsWeb && googleWebClientId.isEmpty) {
      if (mounted) {
        setState(() {
          _errorGoogle =
              'Falta configurar el ID de cliente web de Google para esta versión web.';
        });
      }
      return;
    }

    try {
      await inicializarGoogleSignIn();
      if (kIsWeb) {
        _googleEvents = _googleSignIn.authenticationEvents.listen(
          (evento) {
            // Solo atiende el evento si el Registro es la pantalla visible.
            if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
            if (evento is GoogleSignInAuthenticationEventSignIn) {
              unawaited(
                _registrarConGoogleToken(evento.user.authentication.idToken),
              );
            }
          },
          onError: (Object error) {
            if (mounted) {
              setState(
                () => _errorGoogle =
                    'No se pudo completar el registro con Google.',
              );
            }
          },
        );
      }
      if (mounted) setState(() => _googlePreparado = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorGoogle =
              'Google está tardando demasiado o no pudo inicializarse. Comprueba la conexión y la configuración OAuth.',
        );
      }
    }
  }

  @override
  void dispose() {
    unawaited(_googleEvents?.cancel());
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Separa "Ana María López" en nombre ("Ana") y apellidos ("María López").
  (String, String) _separarNombre() {
    final partes = _nombreCtrl.text.trim().split(RegExp(r'\s+'));
    return (partes.first, partes.skip(1).join(' '));
  }

  // Mismos límites que exige el backend, ahora junto a cada campo.
  String? _validarNombre(String? valor) {
    final completo = (valor ?? '').trim();
    if (completo.isEmpty) return 'Introduce tu nombre y apellidos';
    final partes = completo.split(RegExp(r'\s+'));
    final nombre = partes.first;
    final apellidos = partes.skip(1).join(' ');
    if (apellidos.isEmpty) return 'Escribe tu nombre y apellidos';
    if (nombre.length > 100) {
      return 'El nombre admite como máximo 100 caracteres';
    }
    if (apellidos.length > 150) {
      return 'Los apellidos admiten como máximo 150 caracteres';
    }
    return null;
  }

  String? _validarEmail(String? valor) {
    final email = (valor ?? '').trim();
    if (email.isEmpty) return 'Introduce tu correo';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Ese correo no es válido';
    }
    return null;
  }

  // Los mismos límites que el registerSchema del backend (min 8, max 72).
  // 72 no es arbitrario: bcrypt ignora todo lo que pase de 72 bytes.
  String? _validarPassword(String? valor) {
    final password = valor ?? '';
    if (password.isEmpty) return 'Introduce una contraseña';
    if (password.length < 8) {
      return 'La contraseña necesita mínimo 8 caracteres';
    }
    if (password.length > 72) {
      return 'La contraseña admite como máximo 72 caracteres';
    }
    return null;
  }

  Future<void> _registrarse() async {
    if (_cargando) return;
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _error = null);
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final (nombre, apellidos) = _separarNombre();
      final usuario = await _auth.register(
        nombre,
        apellidos,
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
        _rol,
      );

      if (!mounted) return;

      // register() ya guarda los tokens: el usuario queda con la sesión
      // iniciada, sin tener que pasar por el login.
      _entrarHome(usuario);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _registrarseConGoogle() async {
    if (_cargando || !_googlePreparado || kIsWeb) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final cuenta = await _googleSignIn.authenticate();
      final token = cuenta.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const ApiException(
          'Google no devolvió un token de identidad. Revisa la configuración OAuth.',
        );
      }
      final usuario = await _auth.loginConGoogle(token, rol: _rol);
      if (mounted) _entrarHome(usuario);
    } on GoogleSignInException catch (e) {
      if (!mounted || e.code == GoogleSignInExceptionCode.canceled) return;
      setState(
        () => _error =
            'No se pudo registrar con Google. Revisa la huella SHA-1 y el cliente OAuth.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo registrar con Google.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _registrarConGoogleToken(String? token) async {
    if (!mounted || _cargando) return;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Google no devolvió un token de identidad.');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final usuario = await _auth.loginConGoogle(token, rol: _rol);
      if (mounted) _entrarHome(usuario);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo registrar con Google.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Lleva al home pasándole los datos del usuario recién creado. Mismo
  /// patrón que en login.dart: pushNamedAndRemoveUntil borra el registro del
  /// historial para que "atrás" no vuelva a un formulario ya enviado.
  void _entrarHome(Map<String, dynamic> usuario) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/home', (route) => false, arguments: usuario);
  }

  void _volverALogin() {
    if (_cargando) return;
    // pop y no pushNamed('/login'): se llegó aquí desde el login, así que
    // basta con volver atrás. Con push se apilarían logins infinitos.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // El fondo con líneas lo pone AppBackground (main.dart); el Scaffold es
    // transparente y solo aporta el Material de los campos y el teclado.
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: BrandLogo(size: 48),
                  ),
                  const SizedBox(height: AppSpacing.gap),
                  const ScreenHeader(title: 'Crea tu cuenta'),
                  const SizedBox(height: AppSpacing.gap),
                  _construirFormulario(),
                  const SizedBox(height: AppSpacing.gap),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.group,
                      children: [
                        Text('¿Ya tienes cuenta?', style: AppText.mutedBody),
                        LinkAction(label: 'Entrar', onTap: _volverALogin),
                      ],
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

  Widget _construirFormulario() {
    final mensajeError = _error ?? (!kIsWeb ? _errorGoogle : null);

    return Panel(
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _selectorRol(),
              const SizedBox(height: AppSpacing.gap),
              _campoNombre(),
              const SizedBox(height: AppSpacing.gap),
              _campoEmail(),
              const SizedBox(height: AppSpacing.gap),
              _campoPassword(),
              if (mensajeError != null) ...[
                const SizedBox(height: AppSpacing.gap),
                Notice(message: mensajeError, variant: StatusVariant.error),
              ],
              const SizedBox(height: AppSpacing.gap),
              PrimaryButton(
                label: 'Crear cuenta',
                loading: _cargando,
                loadingLabel: 'Creando cuenta…',
                onPressed: _registrarse,
              ),
              const SizedBox(height: AppSpacing.group),
              _botonGoogle(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectorRol() {
    // Se construye a partir de Rol.values: si mañana se añade un rol al
    // enum, aparece aquí sin tocar esta pantalla.
    return Semantics(
      container: true,
      label: 'Soy',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Soy', style: AppText.label),
          for (final rol in Rol.values)
            AppRadioRow(
              label: switch (rol) {
                Rol.candidato => 'Candidato/a',
                Rol.reclutador => 'Reclutador/a',
              },
              selected: rol == _rol,
              onTap: () {
                if (!_cargando) setState(() => _rol = rol);
              },
            ),
        ],
      ),
    );
  }

  Widget _campoNombre() {
    return AppTextField(
      controller: _nombreCtrl,
      enabled: !_cargando,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.name],
      validator: _validarNombre,
      label: 'Nombre completo',
      hint: 'Ana López Pérez',
    );
  }

  Widget _campoEmail() {
    return AppTextField(
      controller: _emailCtrl,
      enabled: !_cargando,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      validator: _validarEmail,
      label: 'Correo',
      hint: 'nombre@correo.com',
    );
  }

  Widget _campoPassword() {
    return AppTextField(
      controller: _passwordCtrl,
      enabled: !_cargando,
      obscureText: true,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.newPassword],
      validator: _validarPassword,
      onSubmitted: (_) => _registrarse(),
      label: 'Contraseña',
    );
  }

  Widget _botonGoogle() {
    if (kIsWeb) {
      if (googleWebClientId.isEmpty) {
        return Text(
          _errorGoogle ??
              'Google estará disponible al configurar el cliente web.',
          textAlign: TextAlign.center,
          style: AppText.meta,
        );
      }
      if (_errorGoogle != null) {
        return Notice(message: _errorGoogle!, variant: StatusVariant.error);
      }
      if (!_googlePreparado) {
        return const SizedBox(
          height: AppSpacing.field,
          child: Center(child: AppSpinner()),
        );
      }
      return Center(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: IgnorePointer(
            ignoring: _cargando,
            child: google_web.buildGoogleSignInWebButton(),
          ),
        ),
      );
    }

    return SecondaryButton(
      label: 'Registrarme con Google',
      leading: const GoogleLogoMark(),
      onPressed: _registrarseConGoogle,
    );
  }
}
