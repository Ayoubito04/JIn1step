// Tests de Perfil y de la vista previa del CV. Los servicios son falsos: no
// hay backend ni descarga real. El visor de PDF (motor nativo) no se
// monta aquí; se prueban los estados de carga, error y reintento.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:jin1step/core/api_client.dart';
import 'package:jin1step/core/app_theme.dart';
import 'package:jin1step/screens/cv_preview.dart';
import 'package:jin1step/screens/perfil.dart';
import 'package:jin1step/services/candidato.service.dart';

class ServicioFalso extends CandidatoService {
  ServicioFalso({
    this.ubicacion,
    this.disponibilidad,
    this.suscripcion,
    this.falloAlCargar = false,
    this.falloAlGuardar,
  });

  String? ubicacion;
  String? disponibilidad;
  final Map<String, dynamic>? suscripcion;
  final bool falloAlCargar;
  final ApiException? falloAlGuardar;

  int cargas = 0;
  int guardados = 0;
  String? ultimaUbicacion;
  String? ultimaDisponibilidad;
  int descargas = 0;
  Completer<Uint8List>? descarga;
  ApiException? falloDescarga;

  @override
  Future<Map<String, dynamic>> obtenerMiPerfil() async {
    cargas++;
    if (falloAlCargar && cargas == 1) {
      throw const ApiException('No se puede conectar con el servidor.');
    }
    return {'ubicacion': ubicacion, 'disponibilidad': disponibilidad};
  }

  @override
  Future<Map<String, dynamic>?> obtenerSuscripcionActiva() async => suscripcion;

  @override
  Future<Map<String, dynamic>> guardarMiPerfil({
    required String? ubicacion,
    required String? disponibilidad,
  }) async {
    guardados++;
    ultimaUbicacion = ubicacion;
    ultimaDisponibilidad = disponibilidad;
    if (falloAlGuardar != null) throw falloAlGuardar!;
    return {'ubicacion': ubicacion, 'disponibilidad': disponibilidad};
  }

  @override
  Future<Uint8List> descargarArchivoCv(String cvId) {
    descargas++;
    // Con retardo, como la red real: el error llega cuando la pantalla ya
    // está escuchando el Future.
    if (falloDescarga != null) {
      return Future.delayed(
        const Duration(milliseconds: 10),
        () => throw falloDescarga!,
      );
    }
    return (descarga ??= Completer<Uint8List>()).future;
  }
}

const candidato = {
  'id': '1',
  'nombre': 'Ana',
  'apellidos': 'Pérez López',
  'email': 'ana@test.io',
  'rol': 'CANDIDATO',
};
const reclutador = {
  'id': '2',
  'nombre': 'Luis',
  'apellidos': 'Gómez',
  'email': 'luis@empresa.io',
  'rol': 'RECLUTADOR',
};

Future<void> abrir(WidgetTester tester, Widget pagina) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: construirTemaApp(), home: pagina));
  await tester.pumpAndSettle();
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

  group('Perfil del candidato', () {
    testWidgets('muestra identidad, datos vacíos y plan', (tester) async {
      await abrir(tester, PerfilPage(usuario: candidato, service: ServicioFalso()));

      expect(find.text('Ana Pérez López'), findsOneWidget);
      expect(find.text('ana@test.io'), findsOneWidget);
      expect(find.text('Candidato/a'), findsOneWidget);
      expect(find.text('Ubicación'), findsOneWidget);
      expect(find.text('Disponibilidad'), findsOneWidget);
      expect(find.text('Sin indicar'), findsNWidgets(2));
      expect(find.text('Sin suscripción'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });

    testWidgets('muestra los datos guardados y el plan activo', (tester) async {
      final servicio = ServicioFalso(
        ubicacion: 'Bilbao',
        disponibilidad: 'Inmediata',
        suscripcion: {'tipoPlan': 'ANUAL'},
      );
      await abrir(tester, PerfilPage(usuario: candidato, service: servicio));
      expect(find.text('Bilbao'), findsOneWidget);
      expect(find.text('Inmediata'), findsOneWidget);
      expect(find.text('Plan anual'), findsOneWidget);
    });

    testWidgets('editar: guarda, cierra la hoja y actualiza la pantalla', (
      tester,
    ) async {
      final servicio = ServicioFalso();
      await abrir(tester, PerfilPage(usuario: candidato, service: servicio));

      await tester.tap(find.text('Ubicación'));
      await tester.pumpAndSettle();
      expect(find.text('Guardar cambios'), findsOneWidget);
      // La etiqueta visible va encima y el marcador solo da un ejemplo.
      final campos = find.byType(TextField);
      expect(tester.widget<TextField>(campos.at(0)).decoration?.hintText, 'Madrid, España');

      await tester.enterText(campos.at(0), '  Madrid ');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(servicio.guardados, 1);
      expect(servicio.ultimaUbicacion, 'Madrid');
      expect(servicio.ultimaDisponibilidad, isNull); // vacío = borrar
      expect(find.text('Guardar cambios'), findsNothing);
      expect(find.text('Madrid'), findsOneWidget);
      expect(find.text('Perfil actualizado.'), findsOneWidget);
    });

    testWidgets('un campo vacío borra el dato', (tester) async {
      final servicio = ServicioFalso(ubicacion: 'Bilbao', disponibilidad: 'Inmediata');
      await abrir(tester, PerfilPage(usuario: candidato, service: servicio));
      await tester.tap(find.text('Disponibilidad'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(servicio.ultimaUbicacion, 'Bilbao');
      expect(servicio.ultimaDisponibilidad, isNull);
      expect(find.text('Inmediata'), findsNothing);
    });

    testWidgets('respeta los límites del backend y no llama si no son válidos', (
      tester,
    ) async {
      final servicio = ServicioFalso();
      await abrir(tester, PerfilPage(usuario: candidato, service: servicio));
      await tester.tap(find.text('Ubicación'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'x' * 151);
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(servicio.guardados, 0);
      expect(find.text('La ubicación admite como máximo 150 caracteres'), findsOneWidget);
    });

    testWidgets('enseña el error del backend y mantiene la hoja abierta', (
      tester,
    ) async {
      final servicio = ServicioFalso(
        falloAlGuardar: const ApiException('Error del servidor', status: 500),
      );
      await abrir(tester, PerfilPage(usuario: candidato, service: servicio));
      await tester.tap(find.text('Ubicación'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Madrid');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Error del servidor'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);
    });

    testWidgets('si falla la carga, ofrece reintentar', (tester) async {
      final servicio = ServicioFalso(falloAlCargar: true);
      await abrir(tester, PerfilPage(usuario: candidato, service: servicio));
      expect(find.text('No se puede conectar con el servidor.'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Ubicación'), findsOneWidget);
      expect(servicio.cargas, 2);
    });

    testWidgets('con mostrarAtras hay un botón de volver con tooltip', (tester) async {
      await abrir(
        tester,
        PerfilPage(usuario: candidato, mostrarAtras: true, service: ServicioFalso()),
      );
      expect(find.byTooltip('Volver a Inicio'), findsOneWidget);
    });
  });

  group('Perfil del reclutador', () {
    testWidgets('solo identidad y cerrar sesión', (tester) async {
      final servicio = ServicioFalso();
      await abrir(tester, PerfilPage(usuario: reclutador, service: servicio));
      expect(find.text('Luis Gómez'), findsOneWidget);
      expect(find.text('Reclutador/a'), findsOneWidget);
      expect(find.text('Ubicación'), findsNothing);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(servicio.cargas, 0);
    });
  });

  group('Vista previa del CV', () {
    testWidgets('mientras descarga muestra carga y el título del CV', (tester) async {
      final servicio = ServicioFalso();
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: construirTemaApp(),
          home: CvPreviewPage(cvId: 'cv1', titulo: 'CV Ana', service: servicio),
        ),
      );
      await tester.pump();
      expect(find.text('CV Ana'), findsOneWidget);
      expect(find.text('Vista previa del PDF'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byTooltip('Volver a Mi CV'), findsOneWidget);
      expect(servicio.descargas, 1);
    });

    testWidgets('si no se puede abrir, dice por qué y deja reintentar', (tester) async {
      final servicio = ServicioFalso()
        ..falloDescarga = const ApiException(
          'El archivo del CV ya no está disponible',
          status: 404,
        );
      await abrir(
        tester,
        CvPreviewPage(cvId: 'cv1', titulo: 'CV Ana', service: servicio),
      );
      expect(find.text('El archivo del CV ya no está disponible'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      // Primero se construye el fotograma (la pantalla escucha el nuevo
      // Future) y después pasa el tiempo.
      await tester.pump();
      await tester.pumpAndSettle();
      expect(servicio.descargas, 2);
      expect(find.text('El archivo del CV ya no está disponible'), findsOneWidget);
    });
  });
}
