import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'design_system.dart';

/// Azul oficial de LinkedIn. Solo se usa en su logotipo, igual que los colores
/// de Google solo aparecen en la «G».
const _azulLinkedin = Color(0xFF0A66C2);

/// Logotipo «in» de LinkedIn: cuadrado redondeado azul con las letras blancas.
class LinkedinLogoMark extends StatelessWidget {
  const LinkedinLogoMark({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _azulLinkedin,
        borderRadius: BorderRadius.circular(size * .18),
      ),
      child: Text(
        'in',
        style: TextStyle(
          color: AppColors.white,
          fontSize: size * .62,
          fontWeight: FontWeight.w700,
          height: 1,
          letterSpacing: -.3,
        ),
      ),
    ),
  );
}

/// Lo que el usuario confirma en la hoja de LinkedIn. [aMapa] devuelve
/// exactamente las claves que acepta el `linkedinAuthSchema` del backend.
class DatosLinkedin {
  const DatosLinkedin({
    required this.email,
    required this.nombre,
    required this.apellidos,
    required this.titular,
    required this.ubicacion,
    required this.importarFoto,
    required this.importarCv,
    this.accessToken,
  });

  final String email;
  final String nombre;
  final String apellidos;
  final String titular;
  final String ubicacion;
  final bool importarFoto;
  final bool importarCv;
  final String? accessToken;

  Map<String, dynamic> aMapa() => {
    if (accessToken != null && accessToken!.isNotEmpty)
      'accessToken': accessToken,
    if (email.isNotEmpty) 'email': email,
    if (nombre.isNotEmpty) 'nombre': nombre,
    if (apellidos.isNotEmpty) 'apellidos': apellidos,
    if (titular.isNotEmpty) 'titular': titular,
    if (ubicacion.isNotEmpty) 'ubicacion': ubicacion,
    'importarFoto': importarFoto,
    'importarCv': importarCv,
  };
}

/// Abre la hoja para conectar LinkedIn. Devuelve null si el usuario la cierra.
///
/// Con [pedirEmail] a false (sesión ya iniciada) no se pide correo: el perfil
/// se vincula a la cuenta actual.
Future<DatosLinkedin?> mostrarHojaLinkedin(
  BuildContext context, {
  required String titulo,
  required String textoBoton,
  bool pedirEmail = true,
  String? nombreInicial,
  String? apellidosInicial,
}) {
  return showModalBottomSheet<DatosLinkedin>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _HojaLinkedin(
      titulo: titulo,
      textoBoton: textoBoton,
      pedirEmail: pedirEmail,
      nombreInicial: nombreInicial,
      apellidosInicial: apellidosInicial,
    ),
  );
}

class _HojaLinkedin extends StatefulWidget {
  const _HojaLinkedin({
    required this.titulo,
    required this.textoBoton,
    this.pedirEmail = true,
    this.nombreInicial,
    this.apellidosInicial,
  });

  final String titulo;
  final String textoBoton;
  final bool pedirEmail;
  final String? nombreInicial;
  final String? apellidosInicial;

  @override
  State<_HojaLinkedin> createState() => _HojaLinkedinState();
}

class _HojaLinkedinState extends State<_HojaLinkedin> {
  final _formKey = GlobalKey<FormState>();
  late final _emailCtrl = TextEditingController();
  late final _nombreCtrl = TextEditingController(
    text: [
      widget.nombreInicial,
      widget.apellidosInicial,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' '),
  );
  final _titularCtrl = TextEditingController();
  final _ubicacionCtrl = TextEditingController(text: 'Madrid');
  final _tokenCtrl = TextEditingController();
  bool _importarFoto = true;
  bool _importarCv = true;
  bool _avanzado = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nombreCtrl.dispose();
    _titularCtrl.dispose();
    _ubicacionCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  String? _validarEmail(String? valor) {
    final email = (valor ?? '').trim();
    // Con token real el correo lo da LinkedIn; sin él hace falta.
    if (email.isEmpty) {
      return !widget.pedirEmail || _tokenCtrl.text.trim().isNotEmpty
          ? null
          : 'Introduce el correo de tu LinkedIn';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Ese correo no es válido';
    }
    return null;
  }

  void _continuar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final partes = _nombreCtrl.text.trim().split(RegExp(r'\s+'));
    Navigator.of(context).pop(
      DatosLinkedin(
        email: _emailCtrl.text.trim(),
        nombre: partes.first,
        apellidos: partes.skip(1).join(' '),
        titular: _titularCtrl.text.trim(),
        ubicacion: _ubicacionCtrl.text.trim(),
        importarFoto: _importarFoto,
        importarCv: _importarCv,
        accessToken: _tokenCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Sube la hoja por encima del teclado.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const LinkedinLogoMark(size: 28),
                  const SizedBox(width: AppSpacing.group),
                  Expanded(child: Text(widget.titulo, style: AppText.h2)),
                ],
              ),
              const SizedBox(height: AppSpacing.group),
              Text(
                'Confirma el perfil que vas a conectar. Importaremos tu foto '
                'y tu CV para que el autopiloto pueda usarlo desde el primer día.',
                style: AppText.mutedBody,
              ),
              const SizedBox(height: AppSpacing.gap),
              if (widget.pedirEmail) ...[
                AppTextField(
                  controller: _emailCtrl,
                  label: 'Correo de LinkedIn',
                  hint: 'nombre@correo.com',
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: _validarEmail,
                ),
                const SizedBox(height: AppSpacing.gap),
              ],
              AppTextField(
                controller: _nombreCtrl,
                label: 'Nombre completo',
                hint: 'Ana López Pérez',
              ),
              const SizedBox(height: AppSpacing.gap),
              AppTextField(
                controller: _titularCtrl,
                label: 'Titular',
                hint: 'Desarrolladora Full Stack · React y Node.js',
              ),
              const SizedBox(height: AppSpacing.gap),
              AppTextField(
                controller: _ubicacionCtrl,
                label: 'Ubicación',
                hint: 'Madrid',
              ),
              const SizedBox(height: AppSpacing.gap),
              AppSwitch(
                value: _importarFoto,
                label: 'Importar foto de perfil de LinkedIn',
                onChanged: (v) => setState(() => _importarFoto = v),
              ),
              const SizedBox(height: AppSpacing.group),
              AppSwitch(
                value: _importarCv,
                label: 'Importar CV y habilidades de LinkedIn',
                onChanged: (v) => setState(() => _importarCv = v),
              ),
              const SizedBox(height: AppSpacing.group),
              LinkAction(
                label: _avanzado
                    ? 'Ocultar token de LinkedIn'
                    : 'Tengo un token de acceso de LinkedIn',
                onTap: () => setState(() => _avanzado = !_avanzado),
              ),
              if (_avanzado) ...[
                const SizedBox(height: AppSpacing.group),
                AppTextField(
                  controller: _tokenCtrl,
                  label: 'Token de acceso (OAuth)',
                  hint: 'AQV…',
                  autocorrect: false,
                ),
              ],
              const SizedBox(height: AppSpacing.gap),
              PrimaryButton(label: widget.textoBoton, onPressed: _continuar),
            ],
          ),
        ),
      ),
    );
  }
}
