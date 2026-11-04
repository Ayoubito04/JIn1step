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

// home.dart NO se importa: se navega con pushNamedAndRemoveUntil('/home', ...),
// la ruta con nombre que ya registra main.dart, sin referenciar la clase Home.

Future<void>? _inicializacionGoogle;

/// Google Sign-In solo admite una llamada a `initialize` en toda la app. Login
/// y Registro comparten esta función para no inicializarlo dos veces (en web
/// duplicaría los eventos de autenticación).
Future<void> inicializarGoogleSignIn() async {
  try {
    await (_inicializacionGoogle ??= GoogleSignIn.instance
        .initialize(
          clientId: kIsWeb ? googleWebClientId : null,
          serverClientId: !kIsWeb && googleWebClientId.isNotEmpty
              ? googleWebClientId
              : null,
        )
        .timeout(const Duration(seconds: 12)));
  } catch (_) {
    // Permite reintentar si la inicialización falló o agotó el tiempo.
    _inicializacionGoogle = null;
    rethrow;
  }
}

/// Logo "G" de Google en sectores sólidos con los cuatro colores oficiales,
/// sin degradado. Lo comparten Login y Registro.
class GoogleLogoMark extends StatelessWidget {
  const GoogleLogoMark({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _GoogleLogoPainter()),
    ),
  );
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final trazo = size.width * .22;
    final radio = (size.width - trazo) / 2;
    final centro = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: centro, radius: radio);

    void sector(Color color, double inicioGrados, double barridoGrados) {
      canvas.drawArc(
        rect,
        inicioGrados * 3.141592653589793 / 180,
        barridoGrados * 3.141592653589793 / 180,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = trazo
          ..isAntiAlias = true
          ..color = color,
      );
    }

    sector(AppColors.googleBlue, 0, 45);
    sector(AppColors.googleGreen, 45, 90);
    sector(AppColors.googleYellow, 135, 75);
    sector(AppColors.googleRed, 210, 105);

    canvas.drawRect(
      Rect.fromLTRB(
        centro.dx,
        centro.dy - trazo / 2,
        size.width - trazo * .05,
        centro.dy + trazo / 2,
      ),
      Paint()..color = AppColors.googleBlue,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.auth});

  /// Opcional para poder inyectar un servicio falso en los tests. En la app
  /// normal se deja vacío y se usa el AuthService real.
  final AuthService? auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// StatefulWidget y no StatelessWidget: la pantalla tiene que recordar lo que
// escribe el usuario, si está cargando y si hay un error.
class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(); //Controlador de email
  final _passwordCtrl = TextEditingController(); //Controlador de contraseña
  late final AuthService _auth = widget.auth ?? AuthService();

  bool _cargando = false; //Definimos la pantalla de carga
  bool _googlePreparado = false;
  String? _errorGoogle;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleEvents;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.auth != null) {
      _googlePreparado = true;
    } else {
      unawaited(_prepararGoogle());
    }
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
            // Con el Registro abierto encima, el evento le corresponde a él.
            if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
            if (evento is GoogleSignInAuthenticationEventSignIn) {
              unawaited(
                _iniciarSesionConGoogleToken(
                  evento.user.authentication.idToken,
                ),
              );
            }
          },
          onError: (Object error) {
            if (mounted) {
              setState(
                () => _errorGoogle =
                    'No se pudo completar el inicio de sesión con Google.',
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
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesionGoogle() async {
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
      final usuario = await _auth.loginConGoogle(token);
      if (mounted) _entrarHome(usuario);
    } on GoogleSignInException catch (e) {
      if (!mounted || e.code == GoogleSignInExceptionCode.canceled) return;
      setState(
        () => _error =
            'No se pudo iniciar sesión con Google. Revisa la huella SHA-1 y el cliente OAuth.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo iniciar sesión con Google.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _iniciarSesionConGoogleToken(String? token) async {
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
      final usuario = await _auth.loginConGoogle(token);
      if (mounted) _entrarHome(usuario);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo iniciar sesión con Google.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // Mismas reglas de siempre, ahora junto a cada campo.
  String? _validarEmail(String? valor) {
    final email = (valor ?? '').trim();
    if (email.isEmpty) return 'Introduce tu correo';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Ese correo no es válido';
    }
    return null;
  }

  String? _validarPassword(String? valor) =>
      (valor ?? '').isEmpty ? 'Introduce tu contraseña' : null;

  //Evitamos sobrecargar la memoria
  Future<void> _iniciarSesion() async {
    if (_cargando) return;
    // Cierra el teclado para que el usuario vea el resultado.
    FocusScope.of(context).unfocus();
    //FocusScoipe sirve para cerrar el teclado y mejora la experiencia del usuario
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _error = null);
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final usuario = await _auth.login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );

      // La pantalla puede haberse cerrado mientras esperábamos al servidor.
      // Usar el context en ese caso lanzaría una excepción.
      if (!mounted) return;

      _entrarHome(usuario);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Lleva al home pasándole los datos del usuario (id, nombre, rol...) y
  /// borra el login del historial: con pushNamedAndRemoveUntil, el botón
  /// "atrás" del móvil no puede volver a la pantalla de login ya superada.
  void _entrarHome(Map<String, dynamic> usuario) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/home', (route) => false, arguments: usuario);
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
                  const ScreenHeader(
                    title: 'Bienvenido de nuevo',
                    subtitle: 'Buscar trabajo en un solo paso.',
                  ),
                  const SizedBox(height: AppSpacing.gap),
                  _construirFormulario(),
                  const SizedBox(height: AppSpacing.gap),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.group,
                      children: [
                        Text('¿Aún no tienes cuenta?', style: AppText.mutedBody),
                        LinkAction(
                          label: 'Crear cuenta',
                          onTap: () {
                            if (_cargando) return;
                            Navigator.pushNamed(context, '/register');
                          },
                        ),
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _campoEmail(),
            const SizedBox(height: AppSpacing.gap),
            _campoPassword(),
            if (mensajeError != null) ...[
              const SizedBox(height: AppSpacing.gap),
              Notice(message: mensajeError, variant: StatusVariant.error),
            ],
            const SizedBox(height: AppSpacing.gap),
            PrimaryButton(
              label: 'Entrar',
              loading: _cargando,
              loadingLabel: 'Entrando…',
              onPressed: _iniciarSesion,
            ),
            const SizedBox(height: AppSpacing.group),
            _botonGoogle(),
          ],
        ),
      ),
    );
  }

  Widget _botonGoogle() {
    // DESIGN.md 3.2.7 y 5: Botón de Google siempre como SecondaryButton con el
    // logo multicolor oficial y el texto «Entrar con Google».
    final botonDiseno = SecondaryButton(
      label: 'Entrar con Google',
      leading: const GoogleLogoMark(),
      onPressed: kIsWeb
          ? () {
              if (_errorGoogle != null) {
                setState(() => _error = _errorGoogle);
              }
            }
          : _iniciarSesionGoogle,
    );

    if (kIsWeb && _googlePreparado && _errorGoogle == null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          botonDiseno,
          Positioned.fill(
            child: Opacity(
              opacity: 0.01,
              child: IgnorePointer(
                ignoring: _cargando,
                child: google_web.buildGoogleSignInWebButton(),
              ),
            ),
          ),
        ],
      );
    }

    return botonDiseno;
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
      autofillHints: const [AutofillHints.password],
      validator: _validarPassword,
      onSubmitted: (_) => _iniciarSesion(),
      label: 'Contraseña',
    );
  }
}
