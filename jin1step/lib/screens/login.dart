import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../services/auth.service.dart';

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
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// Sacudida horizontal de la tarjeta cuando el login falla. Es el gesto que
  /// usa iOS para "contraseña incorrecta" y se entiende sin leer nada.
  late final AnimationController _sacudida = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  bool _cargando = false; //Definimos la pantalla de carga
  bool _verPassword = false;
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

  Future<void> _iniciarSesion() async {
    // Cierra el teclado para que el usuario vea el resultado.
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      _sacudida.forward(from: 0);
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

      // TODO: navegar a la pantalla principal cuando exista.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('¡Hola, ${usuario['nombre']}!')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
      _sacudida.forward(from: 0);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
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
    // found") y gestiona el hueco del teclado.
    return Scaffold(
      body: Container(
        // Degradado en vez de imagen: assets/images/login.png no existe en el
        // proyecto. Para usar una imagen, ver la nota al final del archivo.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFFDB2777)],
          ),
        ),
        // SafeArea evita que el contenido quede bajo la barra de estado o
        // el notch del móvil.
        child: SafeArea(
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
                    _construirCabecera(),
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
                          style: TextStyle(
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirCabecera() {
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
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 2),
            ),
            child: const Icon(
              Icons.work_outline,
              size: 42,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _aparecer(
          inicio: 0.1,
          child: const Text(
            'Jin1step',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 4),
        _aparecer(
          inicio: 0.15,
          child: const Text(
            'Inicia sesión para continuar',
            style: TextStyle(fontSize: 16, color: Colors.white70),
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
        child: Card(
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
        border: OutlineInputBorder(),
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
        border: const OutlineInputBorder(),
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
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade800),
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
      child: ElevatedButton(
        // Deshabilitado mientras carga: evita que un doble toque mande dos
        // peticiones de login.
        onPressed: _cargando ? null : _iniciarSesion,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(
            0xFF4F46E5,
          ).withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // AnimatedSwitcher funde el texto con el indicador de carga.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _cargando
              ? const SizedBox(
                  key: ValueKey('cargando'),
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Iniciar sesión',
                  key: ValueKey('texto'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}

// NOTA: para usar una imagen de fondo en lugar del degradado:
//
// 1. Crea la carpeta jin1step/assets/images/ y pon ahí login.png
// 2. En pubspec.yaml, dentro de la sección `flutter:`, añade:
//      assets:
//        - assets/images/
// 3. Sustituye el `gradient:` del BoxDecoration por:
//      image: DecorationImage(
//        image: AssetImage('assets/images/login.png'),
//        fit: BoxFit.cover,
//      ),
