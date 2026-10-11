import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../services/auth.service.dart';
// home.dart NO se importa: se navega con pushNamedAndRemoveUntil('/home', ...),
// la ruta con nombre que ya registra main.dart, sin referenciar la clase Home.

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.auth});

  /// Opcional para poder inyectar un servicio falso en los tests.
  final AuthService? auth;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidosCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  late final AuthService _auth = widget.auth ?? AuthService();

  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _sacudida = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  // Por defecto candidato: es el caso más común, y así el formulario nunca
  // se envía sin rol (el backend lo exige).
  Rol _rol = Rol.candidato;
  bool _cargando = false;
  bool _verPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _entrada.forward();
  }

  @override
  void dispose() {
    _entrada.dispose();
    _sacudida.dispose();
    _nombreCtrl.dispose();
    _apellidosCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrarse() async {
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
      // La confirmación de contraseña NO se manda: solo sirve para cazar
      // erratas aquí. El schema del backend es .strict() y la rechazaría.
      final usuario = await _auth.register(
        _nombreCtrl.text.trim(),
        _apellidosCtrl.text.trim(),
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
      _sacudida.forward(from: 0);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Lleva al home pasándole los datos del usuario recién creado. Mismo
  /// patrón que en login.dart: pushNamedAndRemoveUntil borra el registro del
  /// historial para que "atrás" no vuelva a un formulario ya enviado.
  void _entrarHome(Map<String, dynamic> usuario) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
      arguments: usuario,
    );
  }

  /// Entrada escalonada: mismo efecto que en el login.
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
    final esquema = Theme.of(context).colorScheme;

    // Sin degradado ni AppBar transparente: fondo plano (scaffoldBackground
    // del tema) y una AppBar normal, solo para dar la flecha de "volver".
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: AuthBackdrop(
        child: SafeArea(
          child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  _aparecer(
                    inicio: 0.0,
                    child: Text(
                      'Crea tu cuenta',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: esquema.onSurface,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _aparecer(
                    inicio: 0.05,
                    child: Text(
                      'Empieza a encontrar tu próximo empleo',
                      style: TextStyle(fontSize: 15, color: esquema.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _construirTarjeta(),
                  const SizedBox(height: 12),
                  _aparecer(
                    inicio: 0.55,
                    child: TextButton(
                      // pop y no pushNamed('/login'): se llegó aquí desde el
                      // login, así que basta con volver atrás. Con push se
                      // apilarían pantallas de login infinitas.
                      onPressed: _cargando
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text(
                        '¿Ya tienes cuenta? Inicia sesión',
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
      ),
    );
  }

  Widget _construirTarjeta() {
    return AnimatedBuilder(
      animation: _sacudida,
      builder: (context, child) {
        final t = _sacudida.value;
        final desplazamiento = math.sin(t * math.pi * 5) * 14 * (1 - t);
        return Transform.translate(
          offset: Offset(desplazamiento, 0),
          child: child,
        );
      },
      // Card sin decoración extra: elevation, color y bordes redondeados ya
      // salen de cardTheme (core/app_theme.dart).
      child: _aparecer(
        inicio: 0.15,
        child: GlassPanel(
          padding: const EdgeInsets.all(26),
          child: Padding(
            padding: EdgeInsets.zero,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _aparecer(inicio: 0.22, child: _selectorRol()),
                  const SizedBox(height: 20),
                  _aparecer(
                    inicio: 0.28,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _campoTexto(
                            controller: _nombreCtrl,
                            etiqueta: 'Nombre',
                            icono: Icons.person_outline,
                            autofill: AutofillHints.givenName,
                            maximo: 100,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _campoTexto(
                            controller: _apellidosCtrl,
                            etiqueta: 'Apellidos',
                            autofill: AutofillHints.familyName,
                            maximo: 150,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _aparecer(inicio: 0.34, child: _campoEmail()),
                  const SizedBox(height: 16),
                  _aparecer(inicio: 0.40, child: _campoPassword()),
                  const SizedBox(height: 16),
                  _aparecer(inicio: 0.46, child: _campoConfirmar()),
                  _construirError(),
                  const SizedBox(height: 24),
                  _aparecer(inicio: 0.5, child: _botonCrear()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectorRol() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Me registro como', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        // Se construye a partir de Rol.values: si mañana se añade un rol al
        // enum, aparece aquí sin tocar esta pantalla.
        SegmentedButton<Rol>(
          segments: [
            for (final rol in Rol.values)
              ButtonSegment<Rol>(
                value: rol,
                label: Text(rol.etiqueta),
                icon: Icon(
                  rol == Rol.candidato
                      ? Icons.person_search_outlined
                      : Icons.business_center_outlined,
                ),
              ),
          ],
          selected: {_rol},
          onSelectionChanged: _cargando
              ? null
              : (seleccion) => setState(() => _rol = seleccion.first),
        ),
      ],
    );
  }

  /// Campo de texto obligatorio. Los límites de longitud son los mismos que
  /// exige el backend, para avisar antes de mandar la petición.
  Widget _campoTexto({
    required TextEditingController controller,
    required String etiqueta,
    required String autofill,
    required int maximo,
    IconData? icono,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_cargando,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      autofillHints: [autofill],
      decoration: InputDecoration(
        labelText: etiqueta,
        prefixIcon: icono == null ? null : Icon(icono),
      ),
      validator: (valor) {
        final texto = valor?.trim() ?? '';
        if (texto.isEmpty) return 'Obligatorio';
        if (texto.length > maximo) return 'Máximo $maximo caracteres';
        return null;
      },
    );
  }

  Widget _campoEmail() {
    return TextFormField(
      controller: _emailCtrl,
      enabled: !_cargando,
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
      obscureText: !_verPassword,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.newPassword],
      decoration: InputDecoration(
        labelText: 'Contraseña',
        helperText: 'Entre 8 y 72 caracteres',
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
      // Los mismos límites que el registerSchema del backend (min 8, max 72).
      // 72 no es arbitrario: bcrypt ignora todo lo que pase de 72 bytes.
      validator: (valor) {
        final password = valor ?? '';
        if (password.isEmpty) return 'Introduce una contraseña';
        if (password.length < 8) return 'Mínimo 8 caracteres';
        if (password.length > 72) return 'Máximo 72 caracteres';
        return null;
      },
    );
  }

  Widget _campoConfirmar() {
    return TextFormField(
      controller: _confirmarCtrl,
      enabled: !_cargando,
      obscureText: !_verPassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _registrarse(),
      decoration: const InputDecoration(
        labelText: 'Repite la contraseña',
        prefixIcon: Icon(Icons.lock_reset_outlined),
      ),
      validator: (valor) =>
          valor != _passwordCtrl.text ? 'Las contraseñas no coinciden' : null,
    );
  }

  Widget _construirError() {
    final esquema = Theme.of(context).colorScheme;

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
              // Material 3 reserva para avisos de error.
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

  Widget _botonCrear() {
    return SizedBox(
      height: 52,
      // FilledButton: la acción principal en Material 3 (filledButtonTheme
      // en core/app_theme.dart le da el redondeo y el tamaño).
      child: FilledButton(
        onPressed: _cargando ? null : _registrarse,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _cargando
              ? SizedBox(
                  key: const ValueKey('cargando'),
                  width: 24,
                  height: 24,
                  // Color explícito onPrimary: sin él, el spinner toma el
                  // primary del tema y se vuelve invisible sobre el fondo
                  // (también primary) del FilledButton.
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              : const Text('Crear cuenta', key: ValueKey('texto')),
        ),
      ),
    );
  }
}
