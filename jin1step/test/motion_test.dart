// Comprueba el movimiento de animation.md: que ocurre, que termina y que se
// respeta el movimiento reducido. Las fuentes de Google no se descargan en
// los tests; los errores de carga de fuente se ignoran.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:jin1step/core/app_theme.dart';
import 'package:jin1step/screens/splash_screen.dart';
import 'package:jin1step/widgets/brand_logo.dart';
import 'package:jin1step/widgets/design_system.dart';

Widget _app(Widget child, {bool sinMovimiento = false}) => MaterialApp(
  theme: construirTemaApp(),
  builder: (context, hijo) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: sinMovimiento),
    child: hijo!,
  ),
  home: Scaffold(body: Center(child: child)),
);

/// Opacidad acumulada de la primera barra de Steps (el primer Container de 4 px).
double _opacidadPrimeraBarra(WidgetTester tester) {
  final barra = find
      .byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 4)
      .first;
  var opacidad = 1.0;
  tester.element(barra).visitAncestorElements((e) {
    final w = e.widget;
    if (w is Opacity) opacidad *= w.opacity;
    return true;
  });
  return opacidad;
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

  group('Steps', () {
    testWidgets('con animar, las barras aparecen escalonadas y terminan llenas', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const Steps(filled: 3, animar: true)));
      // Primer fotograma: la primera barra aún no es visible del todo.
      expect(_opacidadPrimeraBarra(tester), lessThan(.5));
      await tester.pump(const Duration(milliseconds: 100));
      final aMitad = _opacidadPrimeraBarra(tester);
      expect(aMitad, greaterThan(.5));
      await tester.pumpAndSettle();
      // Al final no queda ninguna animación activa ni transparencia.
      expect(_opacidadPrimeraBarra(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('sin animar, se pinta de golpe', (tester) async {
      await tester.pumpWidget(_app(const Steps(filled: 3)));
      expect(_opacidadPrimeraBarra(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('con movimiento reducido solo hay fundido, sin escala', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const Steps(filled: 2, animar: true), sinMovimiento: true),
      );
      final escalas = tester.widgetList<Transform>(find.byType(Transform));
      for (final t in escalas) {
        expect(t.transform.getMaxScaleOnAxis(), 1);
      }
      await tester.pumpAndSettle();
      expect(_opacidadPrimeraBarra(tester), 1);
    });
  });

  group('ChatBubble', () {
    testWidgets('la nueva entra animada y termina en su sitio', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 300,
            child: ChatBubble(
              message: 'Hola',
              sentByMe: true,
              animarEntrada: true,
            ),
          ),
        ),
      );
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Hola'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('las del historial no se animan', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 300,
            child: ChatBubble(message: 'Hola', sentByMe: false),
          ),
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('BottomNav', () {
    Widget nav(int indice) => _app(
      Align(
        alignment: Alignment.bottomCenter,
        child: BottomNav(
          selectedIndex: indice,
          items: [
            for (final e in ['Inicio', 'Ofertas', 'Autopiloto', 'Chat', 'Mi CV'])
              BottomNavItem(label: e, icon: Icons.circle_outlined, onTap: () {}),
          ],
        ),
      ),
    );

    testWidgets('la píldora se desliza al nuevo icono, no salta', (
      tester,
    ) async {
      await tester.pumpWidget(nav(0));
      await tester.pumpAndSettle();
      final pildora = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.maxWidth == 48 &&
            w.constraints?.maxHeight == 28 &&
            w.decoration is BoxDecoration,
      );
      final inicio = tester.getCenter(pildora).dx;

      await tester.pumpWidget(nav(4));
      await tester.pump(const Duration(milliseconds: 100));
      final aMitad = tester.getCenter(pildora).dx;
      await tester.pumpAndSettle();
      final fin = tester.getCenter(pildora).dx;

      expect(aMitad, greaterThan(inicio));
      expect(aMitad, lessThan(fin));
      // La última pestaña queda centrada sobre su icono.
      final iconos = find.byIcon(Icons.circle_outlined);
      expect((fin - tester.getCenter(iconos.last).dx).abs(), lessThan(1));
    });
  });

  group('Splash', () {
    Future<List<String>> recorrer(WidgetTester tester, {bool reducido = false}) async {
      final rutas = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: construirTemaApp(),
          builder: (context, hijo) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reducido),
            child: hijo!,
          ),
          routes: {
            '/': (_) => const SplashScreen(),
            '/login': (_) {
              rutas.add('/login');
              return const Scaffold(body: Text('login'));
            },
          },
        ),
      );
      return rutas;
    }

    testWidgets('se reproduce una sola vez y continúa a login', (tester) async {
      final rutas = await recorrer(tester);
      expect(rutas, isEmpty);
      // A mitad de la pasada sigue en el splash y hay animación en curso.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);
      // Pasada completa (900 ms) más la pausa de 500 ms: navega a login.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('login'), findsOneWidget);
      expect(rutas, ['/login']);
    });

    testWidgets('con movimiento reducido muestra el logo estático y continúa', (
      tester,
    ) async {
      await recorrer(tester, reducido: true);
      expect(find.byType(AnimatedBrandLogo), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.text('login'), findsOneWidget);
    });
  });

  group('Botones', () {
    testWidgets('al pulsar se escalan a 0.97 y vuelven', (tester) async {
      await tester.pumpWidget(
        _app(PrimaryButton(label: 'Entrar', onPressed: () {})),
      );
      double escala() => tester
          .widget<AnimatedScale>(find.byType(AnimatedScale).first)
          .scale;
      expect(escala(), 1);
      final gesto = await tester.startGesture(
        tester.getCenter(find.text('Entrar')),
      );
      await tester.pump();
      expect(escala(), .97);
      await gesto.up();
      await tester.pump();
      expect(escala(), 1);
    });

    testWidgets('con movimiento reducido no se escalan', (tester) async {
      await tester.pumpWidget(
        _app(
          PrimaryButton(label: 'Entrar', onPressed: () {}),
          sinMovimiento: true,
        ),
      );
      final gesto = await tester.startGesture(
        tester.getCenter(find.text('Entrar')),
      );
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale).first).scale,
        1,
      );
      await gesto.up();
    });
  });
}
