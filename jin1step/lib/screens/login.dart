import 'dart:async';
import 'dart:math' as math;

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
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.auth});

  /// Opcional para poder inyectar un servicio falso en los tests. En la app
  /// normal se deja vacío y se usa el AuthService real.
  final AuthService? auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// StatefulWidget y no StatelessWidget: la pantalla tiene que recordar lo que
// escribe el usuario, si está cargando, si hay un error y el estado de las
// animaciones. Un StatelessWidget no guarda nada entre repintados.
class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  //Definimos el formulario para enviar la información o hacer una petición http
  final _emailCtrl = TextEditingController(); //Controlador de email
  final _passwordCtrl = TextEditingController(); //Controlador de contraseña
  late final AuthService _auth = widget.auth ?? AuthService();
  //definimos los servicio de AuthService dentro de la pantalla de login
  /// Animación de entrada: logo, título, campos y botón aparecen de forma
  /// escalonada, uno detrás de otro.
  late final AnimationController _entrada = AnimationController(
    vsync: this, //Esto define un controlador de animaciones
    duration: const Duration(milliseconds: 1400), //la duiración en milisegundos
  );

  /// Sacudida horizontal de la tarjeta cuando el login falla. Es el gesto que
  /// usa iOS para "contraseña incorrecta" y se entiende sin leer nada.
  late final AnimationController _sacudida = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  bool _cargando = false; //Definimos la pantalla de carga
  bool _googlePreparado = false;
  String? _errorGoogle;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleEvents;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  String? _error;

  @override
  void initState() {
    super.initState();
    _entrada.forward();
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
      await _googleSignIn
          .initialize(
            clientId: kIsWeb ? googleWebClientId : null,
            serverClientId: !kIsWeb && googleWebClientId.isNotEmpty
                ? googleWebClientId
                : null,
          )
          .timeout(const Duration(seconds: 12));
      if (kIsWeb) {
        _googleEvents = _googleSignIn.authenticationEvents.listen(
          (evento) {
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
    // Los controladores reservan recursos (y los de animación, un ticker que
    // se ejecuta cada frame). Si no se liberan, se quedan vivos aunque la
    // pantalla desaparezca.
    _entrada.dispose();
    _sacudida.dispose();
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
      _sacudida.forward(from: 0);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
      _sacudida.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo iniciar sesión con Google.');
      _sacudida.forward(from: 0);
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

  //Evitamos sobrecargar la memoria
  Future<void> _iniciarSesion() async {
    // Cierra el teclado para que el usuario vea el resultado.
    FocusScope.of(context).unfocus();
    //FocusScoipe sirve para cerrar el teclado y mejora la experiencia del usuario
    if (!_formKey.currentState!.validate()) {
      _sacudida.forward(
        from: 0,
      ); //Si hay algo mal en el formulario,se ejecutará una animación con un borde rojo
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
      _sacudida.forward(from: 0);
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

  /// Envuelve un widget para que entre deslizándose hacia arriba y
  /// apareciendo. [inicio] es el momento (de 0 a 1) en que empieza su parte
  /// de la animación: así cada elemento entra un poco después que el anterior.
  Widget _aparecer({required double inicio, required Widget child}) {
    final curva = CurvedAnimation(
      parent: _entrada,
      curve: Interval(
        inicio,
        math.min(inicio + 0.45, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );

    return FadeTransition(
      opacity: curva,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(curva),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold es imprescindible: da el fondo Material que necesitan los
    // TextFormField (sin él la pantalla rompe con "No Material widget
    // found") y gestiona el hueco del teclado. El color de fondo lo pone
    // scaffoldBackgroundColor del tema (core/app_theme.dart): sin degradado
    // ni imagen, que es el estilo plano de Material 3.
    return Scaffold(
      // SafeArea evita que el contenido quede bajo la barra de estado o
      // el notch del móvil.
      body: AuthBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.authHorizontal,
              AppSpacing.authTop,
              AppSpacing.authHorizontal,
              24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Column(
                  children: [
                    _construirCabecera(context),
                    const SizedBox(height: AppSpacing.authBlockGap),
                    _construirTarjeta(),
                    const SizedBox(height: 8),
                    _aparecer(inicio: 0.55, child: _crearCuentaLink()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirCabecera(BuildContext context) {
    // El logo entra con un pequeño rebote (elasticOut), el resto con un
    // deslizamiento suave. Es el primer elemento que aparece.
    final escalaLogo = CurvedAnimation(
      parent: _entrada,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );

    return Column(
      children: [
        ScaleTransition(
          scale: escalaLogo,
          // Círculo de contenedor tonal (primaryContainer) en vez del
          // círculo translúcido sobre el degradado: es el mismo patrón que
          // el icono de perfil de una cuenta de Google.
          child: const BrandLogo(size: AppDimensions.authLogo),
        ),
        const SizedBox(height: 10),
        _aparecer(
          inicio: 0.1,
          child: Text(
            'Bienvenido de nuevo',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: AppFontSizes.authHeading,
              height: 1,
              letterSpacing: -0.4,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 4),
        _aparecer(
          inicio: 0.15,
          child: Text(
            'Buscar trabajo en un solo paso',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: AppFontSizes.muted,
              color: AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirTarjeta() {
    // AnimatedBuilder repinta la tarjeta en cada frame de la sacudida.
    return AnimatedBuilder(
      animation: _sacudida,
      builder: (context, child) {
        // Onda seno que se va apagando: rebota a izquierda y derecha y se
        // detiene, en vez de pararse de golpe.
        final t = _sacudida.value;
        final desplazamiento = math.sin(t * math.pi * 5) * 14 * (1 - t);
        return Transform.translate(
          offset: Offset(desplazamiento, 0),
          child: child,
        );
      },
      child: _aparecer(
        inicio: 0.25,
        child: JCard(
          radius: AppRadii.authCard,
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _aparecer(inicio: 0.35, child: _campoEmail()),
                const SizedBox(height: AppSpacing.authBlockGap),
                _aparecer(inicio: 0.42, child: _campoPassword()),
                _construirError(),
                const SizedBox(height: AppSpacing.authBlockGap),
                _aparecer(inicio: 0.5, child: _botonEntrar()),
                const SizedBox(height: AppSpacing.authBlockGap),
                _aparecer(inicio: 0.51, child: _separadorAcceso()),
                const SizedBox(height: AppSpacing.authBlockGap),
                _aparecer(inicio: 0.52, child: _botonGoogle()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _crearCuentaLink() => TextButton(
    onPressed: _cargando
        ? null
        : () => Navigator.pushNamed(context, '/register'),
    style: TextButton.styleFrom(
      minimumSize: const Size(44, 44),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: RichText(
      text: TextSpan(
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontSize: 13, color: AppColors.muted),
        children: const [
          TextSpan(text: '¿No tienes cuenta? '),
          TextSpan(
            text: 'Crear cuenta',
            style: TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _separadorAcceso() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.fieldBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'o',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
              fontSize: 12,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.fieldBorder)),
      ],
    );
  }

  Widget _botonGoogle() {
    if (kIsWeb) {
      if (googleWebClientId.isEmpty) {
        return Text(
          _errorGoogle ??
              'Google estará disponible al configurar el cliente web.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      }
      if (_errorGoogle != null) {
        return Text(
          _errorGoogle!,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        );
      }
      if (!_googlePreparado) {
        return const SizedBox(
          height: 44,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
      authStyle: true,
      label: 'Continuar con Google',
      leading: const _GoogleG(),
      onPressed: _cargando || !_googlePreparado ? null : _iniciarSesionGoogle,
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
      label: 'Correo electrónico',
      hint: 'tu@correo.com',
      validator: (valor) {
        final email = valor?.trim() ?? '';
        if (email.isEmpty) return 'Introduce tu email';
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
          return 'Ese email no es válido';
        }
        return null;
      },
    );
  }

  Widget _campoPassword() {
    return AppTextField(
      controller: _passwordCtrl,
      enabled: !_cargando,
      obscureText: true,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      onSubmitted: (_) => _iniciarSesion(),
      label: 'Contraseña',
      hint: 'Tu contraseña',
      validator: (valor) =>
          (valor == null || valor.isEmpty) ? 'Introduce tu contraseña' : null,
    );
  }

  Widget _construirError() {
    final esquema = Theme.of(context).colorScheme;
    final mensajeError = _error ?? (!kIsWeb ? _errorGoogle : null);

    // AnimatedSize hace que el hueco del error se abra y cierre suavemente
    // en vez de empujar el botón de golpe.
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: mensajeError == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              // errorContainer/onErrorContainer: el par de colores que
              // Material 3 reserva justo para avisos de error, el mismo
              // que usan Gmail o Drive en sus banners de aviso.
              decoration: BoxDecoration(
                color: esquema.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: esquema.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mensajeError,
                      style: TextStyle(color: esquema.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _botonEntrar() {
    return PrimaryButton(
      label: 'Entrar',
      loading: _cargando,
      onPressed: _cargando ? null : _iniciarSesion,
    );
  }
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: AppGradients.googleMark.createShader,
    child: Text(
      'G',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: AppColors.white,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
