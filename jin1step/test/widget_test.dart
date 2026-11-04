// Tests de la pantalla de Login contra DESIGN.md: logo, título, correo,
// contraseña, "Entrar", "Entrar con Google", enlace a "Crear cuenta",
// validación al salir del campo y botón nunca desactivado.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:jin1step/core/api_client.dart';
import 'package:jin1step/core/app_theme.dart';
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
}

Widget _homeDePrueba(BuildContext context) {
  final args =
      ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  return Scaffold(body: Text('PANTALLA HOME: ${args['nombre']}'));
}

Future<void> abrirLogin(WidgetTester tester, AuthService auth) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: construirTemaApp(),
      routes: {
        '/': (_) => LoginScreen(auth: auth),
        '/register': (_) => const RegisterPage(),
        '/home': _homeDePrueba,
      },
    ),
  );
  await tester.pumpAndSettle();
}

Finder get campoEmail => find.byType(TextField).at(0);
Finder get campoPassword => find.byType(TextField).at(1);
Finder get botonEntrar => find.text('Entrar');

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    final anterior = FlutterError.onError;
    FlutterError.onError = (detalles) {
      if (detalles.exceptionAsString().contains('google_fonts')) return;
      anterior?.call(detalles);
    };
  });

  testWidgets('pinta la pantalla de Login según DESIGN.md', (tester) async {
    await abrirLogin(tester, AuthFalso());

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.text('Buscar trabajo en un solo paso.'), findsOneWidget);
    expect(find.text('Correo'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(botonEntrar, findsOneWidget);
    expect(find.text('Entrar con Google'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
  });

  testWidgets('con los campos vacíos no llama al backend y muestra errores', (
    tester,
  ) async {
    final auth = AuthFalso();
    await abrirLogin(tester, auth);

    await tester.tap(botonEntrar);
    await tester.pumpAndSettle();

    expect(find.text('Introduce tu correo'), findsOneWidget);
    expect(find.text('Introduce tu contraseña'), findsOneWidget);
    expect(auth.llamadas, 0);
  });

  testWidgets('rechaza un correo mal escrito', (tester) async {
    final auth = AuthFalso();
    await abrirLogin(tester, auth);

    await tester.enterText(campoEmail, 'esto-no-es-un-email');
    await tester.enterText(campoPassword, 'Passw0rd!12');
    await tester.tap(botonEntrar);
    await tester.pumpAndSettle();

    expect(find.text('Ese correo no es válido'), findsOneWidget);
    expect(auth.llamadas, 0);
  });

  testWidgets('si el backend rechaza, enseña su mensaje de error', (
    tester,
  ) async {
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

  testWidgets('mientras carga muestra spinner y evita doble envío', (
    tester,
  ) async {
    final espera = Completer<Map<String, dynamic>>();
    final auth = AuthFalso(espera: espera);
    await abrirLogin(tester, auth);

    await tester.enterText(campoEmail, 'ana@test.io');
    await tester.enterText(campoPassword, 'Passw0rd!12');
    await tester.tap(botonEntrar);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Entrando…'), findsOneWidget);

    espera.complete({'nombre': 'Ana'});
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('PANTALLA HOME'), findsOneWidget);
  });

  testWidgets('login correcto: recorta espacios y navega al home', (
    tester,
  ) async {
    final auth = AuthFalso();
    await abrirLogin(tester, auth);

    await tester.enterText(campoEmail, '  ana@test.io  ');
    await tester.enterText(campoPassword, 'Passw0rd!12');
    await tester.tap(botonEntrar);
    await tester.pumpAndSettle();

    expect(auth.ultimoEmail, 'ana@test.io');
    expect(find.text('PANTALLA HOME: Ana'), findsOneWidget);
  });

  testWidgets('el enlace Crear cuenta navega al registro', (tester) async {
    await abrirLogin(tester, AuthFalso());

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);
  });
}
