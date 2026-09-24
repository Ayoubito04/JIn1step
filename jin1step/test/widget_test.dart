// Tests de la pantalla de login.
//
// Usan un AuthService falso para no depender de que el backend esté
// encendido: así se prueba solo el comportamiento de la pantalla.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jin1step/core/api_client.dart';
import 'package:jin1step/screens/login.dart';
import 'package:jin1step/screens/register.dart';
import 'package:jin1step/services/auth.service.dart';

class AuthFalso extends AuthService {
  AuthFalso({this.error, this.espera});

  final ApiException? error;
  final Completer<Map<String, dynamic>>? espera;
  int llamadas = 0;
  String? ultimoEmail;

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    llamadas++;
    ultimoEmail = email;
    if (espera != null) return espera!.future;
    if (error != null) throw error!;
    return {'nombre': 'Ana'};
  }

  int registros = 0;
  Rol? ultimoRol;
  String? ultimoNombre;

  @override
  Future<Map<String, dynamic>> register(
    String nombre,
    String apellidos,
    String email,
    String password,
    Rol rol,
  ) async {
    registros++;
    ultimoRol = rol;
    ultimoNombre = nombre;
    if (error != null) throw error!;
    return {'nombre': nombre};
  }
}

Future<void> abrirLogin(WidgetTester tester, AuthService auth) async {
  await tester.pumpWidget(
    MaterialApp(
      routes: {
        '/': (_) => LoginScreen(auth: auth),
        '/register': (_) => const RegisterPage(),
      },
    ),
  );
  // Deja terminar la animación de entrada.
  await tester.pumpAndSettle();
}

Finder get campoEmail => find.byType(TextFormField).at(0);
Finder get campoPassword => find.byType(TextFormField).at(1);
Finder get botonEntrar => find.text('Iniciar sesión');

/// La SnackBar deja un temporizador vivo; si no se agota, el test falla al
/// terminar con "A Timer is still pending".
Future<void> cerrarSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pinta la pantalla completa tras la animación de entrada',
      (tester) async {
    await abrirLogin(tester, AuthFalso());

    expect(find.text('Jin1step'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(botonEntrar, findsOneWidget);
    expect(find.text('¿No tienes cuenta? Regístrate'), findsOneWidget);
  });

  testWidgets('con los campos vacíos no llama al backend', (tester) async {
    final auth = AuthFalso();
    await abrirLogin(tester, auth);

    await tester.tap(botonEntrar);
    await tester.pumpAndSettle();

    expect(find.text('Introduce tu email'), findsOneWidget);
    expect(find.text('Introduce tu contraseña'), findsOneWidget);
    expect(auth.llamadas, 0);
  });

  testWidgets('rechaza un email mal escrito', (tester) async {
    final auth = AuthFalso();
    await abrirLogin(tester, auth);

    await tester.enterText(campoEmail, 'esto-no-es-un-email');
    await tester.enterText(campoPassword, 'Passw0rd!12');
    await tester.tap(botonEntrar);
    await tester.pumpAndSettle();

    expect(find.text('Ese email no es válido'), findsOneWidget);
    expect(auth.llamadas, 0);
  });

  testWidgets('la contraseña va oculta y el ojo la muestra', (tester) async {
    await abrirLogin(tester, AuthFalso());

    TextField campo() => tester.widget<TextField>(
          find.descendant(of: campoPassword, matching: find.byType(TextField)),
        );

    expect(campo().obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();
    expect(campo().obscureText, isFalse);
  });

  testWidgets('si el backend rechaza, enseña su mensaje de error',
      (tester) async {
    final auth = AuthFalso(
      error: const ApiException('Email o contraseña incorrectos', status: 401),
    );
    await abrirLogin(tester, auth);

    await tester.enterText(campoEmail, 'ana@test.io');
    await tester.enterText(campoPassword, 'mal');
    await tester.tap(botonEntrar);
    await tester.pumpAndSettle();

    expect(auth.llamadas, 1);
    expect(find.text('Email o contraseña incorrectos'), findsOneWidget);
  });

  testWidgets('mientras carga, el botón se desactiva y muestra un spinner',
      (tester) async {
    final espera = Completer<Map<String, dynamic>>();
    final auth = AuthFalso(espera: espera);
    await abrirLogin(tester, auth);

    await tester.enterText(campoEmail, 'ana@test.io');
    await tester.enterText(campoPassword, 'Passw0rd!12');
    await tester.tap(botonEntrar);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final boton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(boton.onPressed, isNull, reason: 'evita un doble envío');

    espera.complete({'nombre': 'Ana'});
    await tester.pumpAndSettle();
    await cerrarSnackBar(tester);
  });

  testWidgets('login correcto: recorta espacios y saluda', (tester) async {
    final auth = AuthFalso();
    await abrirLogin(tester, auth);

    await tester.enterText(campoEmail, '  ana@test.io  ');
    await tester.enterText(campoPassword, 'Passw0rd!12');
    await tester.tap(botonEntrar);
    await tester.pumpAndSettle();

    expect(auth.ultimoEmail, 'ana@test.io');
    expect(find.text('¡Hola, Ana!'), findsOneWidget);
    await cerrarSnackBar(tester);
  });

  testWidgets('el enlace de registro navega sin romper', (tester) async {
    await abrirLogin(tester, AuthFalso());

    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);
  });

  testsDeRegistro();
}

// ─── Registro ───────────────────────────────────────────────────────────────

/// El formulario de registro es más alto que la pantalla de test por defecto
/// (800x600); se agranda para que el botón sea pulsable sin hacer scroll.
Future<void> abrirRegistro(WidgetTester tester, AuthService auth) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      routes: {
        '/': (_) => const Scaffold(body: Text('PANTALLA LOGIN')),
        '/register': (_) => RegisterPage(auth: auth),
      },
      initialRoute: '/register',
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> rellenarRegistro(
  WidgetTester tester, {
  String password = 'Passw0rd!12',
  String? confirmar,
}) async {
  final campos = find.byType(TextFormField);
  await tester.enterText(campos.at(0), '  Ana ');
  await tester.enterText(campos.at(1), 'Pérez');
  await tester.enterText(campos.at(2), 'ana@test.io');
  await tester.enterText(campos.at(3), password);
  await tester.enterText(campos.at(4), confirmar ?? password);
}

Finder get botonCrear => find.text('Crear cuenta');

void testsDeRegistro() {
  testWidgets('registro: con campos vacíos no llama al backend', (tester) async {
    final auth = AuthFalso();
    await abrirRegistro(tester, auth);

    await tester.tap(botonCrear);
    await tester.pumpAndSettle();

    expect(find.text('Obligatorio'), findsNWidgets(2));
    expect(find.text('Introduce tu email'), findsOneWidget);
    expect(find.text('Introduce una contraseña'), findsOneWidget);
    expect(auth.registros, 0);
  });

  testWidgets('registro: exige 8 caracteres de contraseña como el backend',
      (tester) async {
    final auth = AuthFalso();
    await abrirRegistro(tester, auth);

    await rellenarRegistro(tester, password: 'corta');
    await tester.tap(botonCrear);
    await tester.pumpAndSettle();

    expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
    expect(auth.registros, 0);
  });

  testWidgets('registro: detecta contraseñas que no coinciden', (tester) async {
    final auth = AuthFalso();
    await abrirRegistro(tester, auth);

    await rellenarRegistro(tester, confirmar: 'OtraDistinta1');
    await tester.tap(botonCrear);
    await tester.pumpAndSettle();

    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    expect(auth.registros, 0);
  });

  testWidgets('registro: manda CANDIDATO por defecto y recorta espacios',
      (tester) async {
    final auth = AuthFalso();
    await abrirRegistro(tester, auth);

    await rellenarRegistro(tester);
    await tester.tap(botonCrear);
    await tester.pumpAndSettle();

    expect(auth.registros, 1);
    expect(auth.ultimoRol, Rol.candidato);
    expect(auth.ultimoRol!.valorApi, 'CANDIDATO');
    expect(auth.ultimoNombre, 'Ana');
    expect(find.textContaining('Cuenta creada'), findsOneWidget);
    await cerrarSnackBar(tester);
  });

  testWidgets('registro: el selector cambia el rol a RECLUTADOR',
      (tester) async {
    final auth = AuthFalso();
    await abrirRegistro(tester, auth);

    await tester.tap(find.text('Reclutador'));
    await tester.pumpAndSettle();
    await rellenarRegistro(tester);
    await tester.tap(botonCrear);
    await tester.pumpAndSettle();

    expect(auth.ultimoRol, Rol.reclutador);
    expect(auth.ultimoRol!.valorApi, 'RECLUTADOR');
    await cerrarSnackBar(tester);
  });

  testWidgets('registro: enseña el error del backend', (tester) async {
    final auth = AuthFalso(
      error: const ApiException('Ya existe una cuenta con ese email', status: 409),
    );
    await abrirRegistro(tester, auth);

    await rellenarRegistro(tester);
    await tester.tap(botonCrear);
    await tester.pumpAndSettle();

    expect(find.text('Ya existe una cuenta con ese email'), findsOneWidget);
  });

  testWidgets('registro: el enlace vuelve al login', (tester) async {
    await abrirRegistro(tester, AuthFalso());

    await tester.tap(find.text('¿Ya tienes cuenta? Inicia sesión'));
    await tester.pumpAndSettle();

    expect(find.text('PANTALLA LOGIN'), findsOneWidget);
  });
}
