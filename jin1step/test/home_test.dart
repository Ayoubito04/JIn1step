// Tests del home rediseñado (cabecera azul, tarjeta de cristal, accesos
// rápidos). El objetivo principal aquí es cazar overflows de layout: un
// RenderFlex desbordado lanza una excepción que flutter_test convierte en
// fallo de test, así que si esto pasa en verde, el diseño encaja en una
// pantalla de móvil estándar sin desbordarse.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jin1step/screens/home.dart';
import 'package:jin1step/services/ofertas.services.dart';

/// IndexedStack monta TODAS las pestañas de golpe (es lo que le permite
/// conservar su estado al cambiar entre ellas). Eso significa que la de
/// Ofertas hace su llamada de red en cuanto Home se construye, aunque el
/// candidato esté mirando Inicio. Sin este falso, cada test de Home
/// dispararía una petición HTTP real contra un backend que aquí no existe,
/// y pumpAndSettle se quedaría esperando el spinner para siempre.
class OfertasFalso extends OfertasService {
  @override
  Future<List<Map<String, dynamic>>> getAllOfertas() async => [];
}

Future<void> abrirHome(
  WidgetTester tester,
  Map<String, dynamic> usuario,
) async {
  await tester.pumpWidget(
    MaterialApp(
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: RouteSettings(arguments: usuario),
        builder: (_) => Home(ofertasService: OfertasFalso()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final candidato = {
  'id': '1',
  'nombre': 'Ana',
  'apellidos': 'Pérez',
  'email': 'ana@test.io',
  'rol': 'CANDIDATO',
};

final reclutador = {
  'id': '2',
  'nombre': 'Luis',
  'apellidos': 'Gómez',
  'email': 'luis@test.io',
  'rol': 'RECLUTADOR',
};

void main() {
  testWidgets('candidato: ve Ofertas y sus accesos rápidos sin desbordar',
      (tester) async {
    await abrirHome(tester, candidato);

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Ofertas'), findsWidgets);
    // "Autopiloto" aparece dos veces A PROPÓSITO: como acceso rápido y como
    // título de la tarjeta de estadística. Igual que "Perfil" (pestaña +
    // acceso rápido).
    expect(find.text('Autopiloto'), findsNWidgets(2));
    expect(find.text('Mensajes'), findsWidgets);
    expect(find.text('Perfil'), findsNWidgets(2));

    // tester.takeException() sería null aquí de todas formas si hubiera
    // fallado (pumpAndSettle ya lo relanza), pero se deja explícito el punto
    // que se está comprobando: nada se ha desbordado.
    expect(tester.takeException(), isNull);
  });

  testWidgets('reclutador: ve Mis ofertas y NO ve Autopiloto', (tester) async {
    await abrirHome(tester, reclutador);

    expect(find.text('Hola, Luis'), findsOneWidget);
    expect(find.text('Mis ofertas'), findsWidgets);
    expect(find.text('Publicar'), findsOneWidget);
    // Igual que "Autopiloto" en el candidato: acceso rápido + tarjeta.
    expect(find.text('Candidatos'), findsNWidgets(2));
    expect(find.text('Autopiloto'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el acceso rápido "Ofertas" cambia a esa pestaña',
      (tester) async {
    await abrirHome(tester, candidato);

    // El botón de la pestaña y el del acceso rápido comparten texto; se
    // pulsa el segundo, que es el de la fila de accesos rápidos.
    await tester.tap(find.text('Ofertas').last);
    await tester.pumpAndSettle();

    // Ya es la pantalla Ofertas real, no el marcador de "en construcción".
    // Con OfertasFalso devolviendo una lista vacía, muestra su estado vacío.
    expect(find.text('Ofertas de empleo'), findsOneWidget);
    expect(find.text('No hay ofertas disponibles'), findsOneWidget);
  });

  testWidgets('la pestaña Perfil enseña los datos y permite cerrar sesión',
      (tester) async {
    await abrirHome(tester, candidato);

    // El icono de perfil aparece dos veces en pantalla (acceso rápido de
    // Inicio + barra inferior): se busca el texto DENTRO del NavigationBar
    // para no ambigüar sobre cuál de los dos tocar.
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Perfil')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('ana@test.io'), findsOneWidget);
    expect(find.text('Candidato'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('Autopiloto de postulaciones'), findsOneWidget);
  });

  testWidgets('reclutador en Perfil no ve la opción de autopiloto',
      (tester) async {
    await abrirHome(tester, reclutador);

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Perfil')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reclutador'), findsOneWidget);
    expect(find.text('Autopiloto de postulaciones'), findsNothing);
  });

  testWidgets('sin argumentos, no revienta: se queda en blanco esperando la redirección',
      (tester) async {
    // Sin RouteSettings.arguments, Home debería programar una redirección a
    // /login en vez de lanzar una excepción al hacer el cast.
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) =>
            MaterialPageRoute(builder: (_) => const Home()),
        // Sin '/login' registrada, la redirección en sí fallaría; lo que se
        // comprueba aquí es que Home no lanza ANTES de intentarla.
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
