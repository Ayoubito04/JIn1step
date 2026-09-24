import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../services/auth.service.dart';

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
      // TODO: navegar a la pantalla principal cuando exista.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Cuenta creada! Bienvenido, ${usuario['nombre']}'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
      _sacudida.forward(from: 0);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
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
    return Scaffold(
      // AppBar transparente: da la flecha de volver al login sin tapar el
      // degradado. extendBodyBehindAppBar hace que el fondo llegue arriba.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFFDB2777)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    _aparecer(
                      inicio: 0.0,
                      child: const Text(
                        'Crea tu cuenta',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _aparecer(
                      inicio: 0.05,
                      child: const Text(
                        'Empieza a encontrar tu próximo empleo',
                        style: TextStyle(fontSize: 15, color: Colors.white70),
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
      child: _aparecer(
        inicio: 0.15,
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
                label: Text(rol == Rol.candidato ? 'Candidato' : 'Reclutador'),
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
        border: const OutlineInputBorder(),
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
        border: OutlineInputBorder(),
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
        border: OutlineInputBorder(),
      ),
      validator: (valor) =>
          valor != _passwordCtrl.text ? 'Las contraseñas no coinciden' : null,
    );
  }

  Widget _construirError() {
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

  Widget _botonCrear() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _cargando ? null : _registrarse,
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
                  'Crear cuenta',
                  key: ValueKey('texto'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}
