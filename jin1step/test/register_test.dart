// Tests de la pantalla de registro contra DESIGN.md: contenido, etiquetas
// visibles, marcadores solo de formato, validación al salir del campo (y error
// que se limpia al volver a enfocar), botón nunca desactivado y envío.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:jin1step/core/api_client.dart';
import 'package:jin1step/core/app_theme.dart';
import 'package:jin1step/screens/register.dart';
import 'package:jin1step/services/auth.service.dart';

class AuthFalso extends AuthService {
  AuthFalso({this.error});

  final ApiException? error;
  int registros = 0;
  Rol? ultimoRol;
  String? ultimoNombre;
  String? ultimosApellidos;
  String? ultimoEmail;

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
    ultimosApellidos = apellidos;
    ultimoEmail = email;
    if (error != null) throw error!;
    return {'nombre': nombre};
  }
}

Widget _homeDePrueba(BuildContext context) {
  final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  return Scaffold(body: Text('PANTALLA HOME: ${args['nombre']}'));
}

Future<void> abrirRegistro(WidgetTester tester, AuthService auth) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: construirTemaApp(),
      routes: {
        '/': (_) => const Scaffold(body: Text('PANTALLA LOGIN')),
        '/register': (_) => RegisterPage(auth: auth),
        '/home': _homeDePrueba,
      },
      initialRoute: '/register',
    ),
  );
  await tester.pumpAndSettle();
}

Finder get campos => find.byType(TextField);
Finder get campoNombre => campos.at(0);
Finder get campoCorreo => campos.at(1);
Finder get campoPassword => campos.at(2);
Finder get botonCrear => find.text('Crear cuenta');

Future<void> rellenar(WidgetTester tester, {String password = 'Passw0rd!12'}) async {
  await tester.enterText(campoNombre, '  Ana María   Pérez López ');
  await tester.enterText(campoCorreo, ' ana@test.io ');
  await tester.enterText(campoPassword, password);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    final anterior = FlutterError.onError;
    FlutterError.onError = (detalles) {
      if (detalles.exceptionAsString().contains('google_fonts')) return;
      anterior?.call(detalles);
    };
  });

  group('contenido (DESIGN.md, pantalla Registro)', () {
    testWidgets('tiene exactamente lo que pide el diseño', (tester) async {
      await abrirRegistro(tester, AuthFalso());

      // Selector Candidato/a · Reclutador/a (radio) con su etiqueta.
      expect(find.text('Soy'), findsOneWidget);
      expect(find.text('Candidato/a'), findsOneWidget);
      expect(find.text('Reclutador/a'), findsOneWidget);
      // Nombre completo, correo y contraseña: etiqueta visible encima.
      expect(find.text('Nombre completo'), findsOneWidget);
      expect(find.text('Correo'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(campos, findsNWidgets(3));
      // Botones y enlace.
      expect(find.text('Crear cuenta'), findsOneWidget);
      expect(find.text('Registrarme con Google'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
      // Sin lo que el diseño no define (el subtítulo no está en el diseño).
      expect(find.text('Buscar trabajo en un solo paso.'), findsNothing);
      expect(find.byIcon(Icons.visibility), findsNothing);
    });

    testWidgets('el marcador solo da un ejemplo de formato, nunca el nombre del campo', (
      tester,
    ) async {
      await abrirRegistro(tester, AuthFalso());
      final marcadores = tester
          .widgetList<TextField>(campos)
          .map((c) => c.decoration?.hintText)
          .toList();
      expect(marcadores[1], 'nombre@correo.com');
      for (final marcador in marcadores.whereType<String>()) {
        expect(
          ['Nombre completo', 'Correo', 'Contraseña'],
          isNot(contains(marcador)),
        );
      }
    });

    testWidgets('la etiqueta está enlazada al campo para los lectores de pantalla', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await abrirRegistro(tester, AuthFalso());
      expect(tester.getSemantics(campoNombre).label, contains('Nombre completo'));
      expect(tester.getSemantics(campoCorreo).label, contains('Correo'));
      expect(tester.getSemantics(campoPassword).label, contains('Contraseña'));
      semantica.dispose();
    });

    testWidgets('autofillHints: nombre, correo y contraseña nueva', (tester) async {
      await abrirRegistro(tester, AuthFalso());
      final pistas = tester
          .widgetList<TextField>(campos)
          .map((c) => c.autofillHints?.toList())
          .toList();
      expect(pistas[0], [AutofillHints.name]);
      expect(pistas[1], [AutofillHints.email]);
      expect(pistas[2], [AutofillHints.newPassword]);
    });

    testWidgets('áreas táctiles: campos y botones de 48 px, radios de 44 px', (
      tester,
    ) async {
      await abrirRegistro(tester, AuthFalso());
      for (var i = 0; i < 3; i++) {
        expect(tester.getSize(campos.at(i)).height, greaterThanOrEqualTo(48));
      }
      expect(tester.getSize(botonCrear).height, greaterThanOrEqualTo(14));
      final alturaBoton = tester
          .getSize(find.ancestor(of: botonCrear, matching: find.byType(InkWell)).first)
          .height;
      expect(alturaBoton, greaterThanOrEqualTo(48));
      final alturaRadio = tester
          .getSize(find.ancestor(of: find.text('Candidato/a'), matching: find.byType(InkWell)).first)
          .height;
      expect(alturaRadio, greaterThanOrEqualTo(44));
    });
  });

  group('validación', () {
    testWidgets('no marca el campo como inválido mientras se escribe', (tester) async {
      await abrirRegistro(tester, AuthFalso());
      await tester.tap(campoCorreo);
      await tester.enterText(campoCorreo, 'ana@');
      await tester.pump();
      expect(find.text('Ese correo no es válido'), findsNothing);
    });

    testWidgets('valida al salir del campo y limpia el error al volver a enfocarlo', (
      tester,
    ) async {
      await abrirRegistro(tester, AuthFalso());
      await tester.tap(campoCorreo);
      await tester.enterText(campoCorreo, 'ana@');
      await tester.pump();

      // Sale del campo: aparece el error junto al campo.
      await tester.tap(campoPassword);
      await tester.pump();
      expect(find.text('Ese correo no es válido'), findsOneWidget);

      // Vuelve a enfocarlo: el error desaparece y el texto se conserva.
      await tester.tap(campoCorreo);
      await tester.pump();
      expect(find.text('Ese correo no es válido'), findsNothing);
      expect(
        tester.widget<TextField>(campoCorreo).controller!.text,
        'ana@',
      );
    });

    testWidgets('con los campos vacíos no llama al backend y el botón sigue activo', (
      tester,
    ) async {
      final auth = AuthFalso();
      await abrirRegistro(tester, auth);

      await tester.tap(botonCrear);
      await tester.pumpAndSettle();

      expect(auth.registros, 0);
      expect(find.text('Introduce tu nombre y apellidos'), findsOneWidget);
      expect(find.text('Introduce tu correo'), findsOneWidget);
      expect(find.text('Introduce una contraseña'), findsOneWidget);
      // El botón nunca se desactiva: se puede volver a pulsar.
      await tester.tap(botonCrear);
      await tester.pumpAndSettle();
      expect(find.text('Introduce tu correo'), findsOneWidget);
    });

    testWidgets('exige nombre y apellidos', (tester) async {
      final auth = AuthFalso();
      await abrirRegistro(tester, auth);
      await tester.enterText(campoNombre, 'Ana');
      await tester.enterText(campoCorreo, 'ana@test.io');
      await tester.enterText(campoPassword, 'Passw0rd!12');
      await tester.tap(botonCrear);
      await tester.pumpAndSettle();
      expect(auth.registros, 0);
      expect(find.text('Escribe tu nombre y apellidos'), findsOneWidget);
    });

    testWidgets('exige 8 caracteres de contraseña, como el backend', (tester) async {
      final auth = AuthFalso();
      await abrirRegistro(tester, auth);
      await rellenar(tester, password: 'corta');
      await tester.tap(botonCrear);
      await tester.pumpAndSettle();
      expect(auth.registros, 0);
      expect(find.text('La contraseña necesita mínimo 8 caracteres'), findsOneWidget);
    });
  });

  group('envío', () {
    testWidgets('manda CANDIDATO por defecto, separa el nombre y recorta espacios', (
      tester,
    ) async {
      final auth = AuthFalso();
      await abrirRegistro(tester, auth);
      await rellenar(tester);
      await tester.tap(botonCrear);
      await tester.pumpAndSettle();

      expect(auth.registros, 1);
      expect(auth.ultimoRol, Rol.candidato);
      expect(auth.ultimoNombre, 'Ana');
      expect(auth.ultimosApellidos, 'María Pérez López');
      expect(auth.ultimoEmail, 'ana@test.io');
      expect(find.text('PANTALLA HOME: Ana'), findsOneWidget);
    });

    testWidgets('el selector cambia el rol a RECLUTADOR', (tester) async {
      final auth = AuthFalso();
      await abrirRegistro(tester, auth);
      await tester.tap(find.text('Reclutador/a'));
      await tester.pumpAndSettle();
      await rellenar(tester);
      await tester.tap(botonCrear);
      await tester.pumpAndSettle();

      expect(auth.ultimoRol, Rol.reclutador);
      expect(find.textContaining('PANTALLA HOME'), findsOneWidget);
    });

    testWidgets('enseña el error del backend', (tester) async {
      final auth = AuthFalso(
        error: const ApiException('Ya existe una cuenta con ese email', status: 409),
      );
      await abrirRegistro(tester, auth);
      await rellenar(tester);
      await tester.tap(botonCrear);
      await tester.pumpAndSettle();
      expect(find.text('Ya existe una cuenta con ese email'), findsOneWidget);
    });

    testWidgets('el enlace «Entrar» vuelve al login', (tester) async {
      await abrirRegistro(tester, AuthFalso());
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA LOGIN'), findsOneWidget);
    });
  });
}
