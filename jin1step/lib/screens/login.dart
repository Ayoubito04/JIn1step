import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../services/auth.service.dart';

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
  bool _verPassword =
      false; //Esta variable nos va a servir para ver o ocultar la contraseña
  String? _error;

  @override
  void initState() {
    super.initState();
    _entrada.forward();
  }

  @override
  void dispose() {
    // Los controladores reservan recursos (y los de animación, un ticker que
    // se ejecuta cada frame). Si no se liberan, se quedan vivos aunque la
    // pantalla desaparezca.
    _entrada.dispose();
    _sacudida.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
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
      body: SafeArea(
        child: Center(
          // Con scroll, al abrir el teclado el formulario se desplaza en
          // vez de desbordar con la franja amarilla y negra.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              // En web o tablet, que el formulario no ocupe toda la pantalla.
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  _construirCabecera(context),
                  const SizedBox(height: 32),
                  _construirTarjeta(),
                  const SizedBox(height: 16),
                  _aparecer(
                    inicio: 0.55,
                    child: TextButton(
                      onPressed: _cargando
                          ? null
                          : () => Navigator.pushNamed(context, '/register'),
                      child: const Text(
                        '¿No tienes cuenta? Regístrate',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
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

  Widget _construirCabecera(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

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
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: esquema.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.work_outline,
              size: 42,
              color: esquema.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _aparecer(
          inicio: 0.1,
          child: Text(
            'Jin1step',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: esquema.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 4),
        _aparecer(
          inicio: 0.15,
          child: Text(
            'Inicia sesión para continuar',
            style: TextStyle(fontSize: 16, color: esquema.onSurfaceVariant),
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
      // Card sin decoración extra: elevation, color y bordes redondeados ya
      // salen de cardTheme (core/app_theme.dart), la superficie tonal
      // estándar de Material 3.
      child: _aparecer(
        inicio: 0.25,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _aparecer(inicio: 0.35, child: _campoEmail()),
                  const SizedBox(height: 16),
                  _aparecer(inicio: 0.42, child: _campoPassword()),
                  _construirError(),
                  const SizedBox(height: 24),
                  _aparecer(inicio: 0.5, child: _botonEntrar()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _campoEmail() {
    return TextFormField(
      controller: _emailCtrl,
      enabled: !_cargando,
      // El backend hace login con EMAIL, no con nombre de usuario.
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      decoration: const InputDecoration(
        labelText: 'Email',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      validator: (valor) {
        final email = valor?.trim() ?? '';
        if (email.isEmpty) return 'Introduce tu email';
        // Comprobación básica en el móvil para no gastar una petición en un
        // email mal escrito. La validación de verdad la hace el backend.
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
          return 'Ese email no es válido';
        }
        return null;
      },
    );
  }

  Widget _campoPassword() {
    return TextFormField(
      controller: _passwordCtrl,
      enabled: !_cargando,
      // Oculta la contraseña mientras se escribe.
      obscureText: !_verPassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      // Pulsar "Hecho" en el teclado equivale a pulsar el botón.
      onFieldSubmitted: (_) => _iniciarSesion(),
      decoration: InputDecoration(
        labelText: 'Contraseña',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _verPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
          icon: Icon(
            _verPassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          onPressed: () => setState(() => _verPassword = !_verPassword),
        ),
      ),
      validator: (valor) =>
          (valor == null || valor.isEmpty) ? 'Introduce tu contraseña' : null,
    );
  }

  Widget _construirError() {
    final esquema = Theme.of(context).colorScheme;

    // AnimatedSize hace que el hueco del error se abra y cierre suavemente
    // en vez de empujar el botón de golpe.
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: _error == null
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
                      _error!,
                      style: TextStyle(color: esquema.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _botonEntrar() {
    return SizedBox(
      height: 52,
      // FilledButton y no ElevatedButton: en Material 3 es el botón de
      // acción principal, fondo sólido sin sombra (filledButtonTheme en
      // core/app_theme.dart ya le da el redondeo y el tamaño).
      child: FilledButton(
        // Deshabilitado mientras carga: evita que un doble toque mande dos
        // peticiones de login.
        onPressed: _cargando ? null : _iniciarSesion,
        // AnimatedSwitcher funde el texto con el indicador de carga.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _cargando
              ? SizedBox(
                  key: const ValueKey('cargando'),
                  width: 24,
                  height: 24,
                  // Color explícito onPrimary: sin él, el spinner toma el
                  // primary del tema por defecto y se vuelve invisible sobre
                  // el fondo (también primary) del FilledButton.
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              : const Text('Iniciar sesión', key: ValueKey('texto')),
        ),
      ),
    );
  }
}
