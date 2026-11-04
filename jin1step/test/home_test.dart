// Tests de Inicio (home.dart) contra DESIGN.md: cabecera con marca y campana,
// título «Hoy», frase resumen, cuadrícula de 4 cifras (KpiGrid), 2 mejores
// matches ordenados y barra inferior de 5 pestañas con contador en Chat.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:jin1step/core/api_client.dart';
import 'package:jin1step/core/app_theme.dart';
import 'package:jin1step/screens/home.dart';
import 'package:jin1step/screens/oferta_detalle.dart';
import 'package:jin1step/widgets/design_system.dart';

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

List<Map<String, dynamic>> _postulacionesDemo() {
  final ahora = DateTime.now().toIso8601String();
  final haceDosDias =
      DateTime.now().subtract(const Duration(days: 2)).toIso8601String();
  // 12 candidaturas = 7 manuales + 5 por IA.
  // 1 en entrevista (Vértice, 94 %), 6 pendientes de revisión, 3 por IA hoy.
  return [
    {
      'id': 'p1',
      'estado': 'ENTREVISTA',
      'postuladoPorIa': false,
      'matchScore': 94,
      'fechaPostulacion': haceDosDias,
      'oferta': {
        'id': 'o1',
        'titulo': 'React Junior',
        'modalidad': 'REMOTO',
        'empresa': {'nombre': 'Vértice'},
      },
    },
    for (var i = 2; i <= 4; i++)
      {
        'id': 'p$i',
        'estado': 'ENVIADA',
        'postuladoPorIa': true,
        'matchScore': 80,
        'fechaPostulacion': ahora,
        'oferta': {
          'id': 'o$i',
          'titulo': 'Oferta IA $i',
          'modalidad': 'REMOTO',
          'empresa': {'nombre': 'Empresa $i'},
        },
      },
    for (var i = 5; i <= 7; i++)
      {
        'id': 'p$i',
        'estado': 'PENDIENTE',
        'postuladoPorIa': false,
        'matchScore': 70,
        'fechaPostulacion': haceDosDias,
        'oferta': {
          'id': 'o$i',
          'titulo': 'Oferta Manual $i',
          'modalidad': 'HIBRIDO',
          'empresa': {'nombre': 'Empresa $i'},
        },
      },
    for (var i = 8; i <= 9; i++)
      {
        'id': 'p$i',
        'estado': 'VISTA',
        'postuladoPorIa': true,
        'matchScore': 76,
        'fechaPostulacion': haceDosDias,
        'oferta': {
          'id': 'o$i',
          'titulo': 'Oferta Vista IA $i',
          'modalidad': 'REMOTO',
          'empresa': {'nombre': 'Empresa $i'},
        },
      },
    for (var i = 10; i <= 12; i++)
      {
        'id': 'p$i',
        'estado': 'VISTA',
        'postuladoPorIa': false,
        'matchScore': 68,
        'fechaPostulacion': haceDosDias,
        'oferta': {
          'id': 'o$i',
          'titulo': 'Oferta Vista Manual $i',
          'modalidad': 'PRESENCIAL',
          'empresa': {'nombre': 'Empresa $i'},
        },
      },
  ];
}

List<Map<String, dynamic>> _ofertasDemo() => [
  {
    'id': 'o-react',
    'titulo': 'React Junior',
    'modalidad': 'REMOTO',
    'empresa': {'nombre': 'Vértice'},
    'requisitos': [
      for (final h in ['React', 'TypeScript', 'HTML', 'CSS', 'Git'])
        {
          'obligatorio': true,
          'habilidad': {'nombre': h},
        },
      for (final h in ['Jest', 'Figma', 'REST', 'Tailwind', 'GraphQL'])
        {
          'obligatorio': false,
          'habilidad': {'nombre': h},
        },
    ],
  },
  {
    'id': 'o-net',
    'titulo': 'Full Stack .NET',
    'modalidad': 'HIBRIDO',
    'empresa': {'nombre': 'Nexo Digital'},
    'requisitos': [
      for (final h in ['C#', '.NET', 'SQL', 'Docker'])
        {
          'obligatorio': true,
          'habilidad': {'nombre': h},
        },
      for (final h in ['Azure', 'Redis'])
        {
          'obligatorio': false,
          'habilidad': {'nombre': h},
        },
    ],
  },
  {
    'id': 'o-qa',
    'titulo': 'QA Automation',
    'modalidad': 'PRESENCIAL',
    'empresa': {'nombre': 'Calidad Sur'},
    'requisitos': [
      for (final h in ['Git', 'SQL', 'HTML', 'Selenium', 'Cypress', 'Java', 'Python'])
        {
          'obligatorio': true,
          'habilidad': {'nombre': h},
        },
    ],
  },
];

List<Map<String, dynamic>> _habilidadesDemo() => [
  for (final h in [
    'React',
    'TypeScript',
    'HTML',
    'CSS',
    'Git',
    'Jest',
    'Figma',
    'REST',
    'Tailwind',
    'C#',
    '.NET',
    'SQL',
    'Azure',
  ])
    {
      'habilidadId': 'id-$h',
      'nivel': 'INTERMEDIO',
      'habilidad': {'id': 'id-$h', 'nombre': h},
    },
];

Future<void> abrirHome(
  WidgetTester tester,
  Map<String, dynamic> usuario,
) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: construirTemaApp(),
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: RouteSettings(arguments: usuario),
        builder: (_) => const Home(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late List<Interceptor> interceptoresOriginales;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    final anterior = FlutterError.onError;
    FlutterError.onError = (detalles) {
      if (detalles.exceptionAsString().contains('google_fonts')) return;
      anterior?.call(detalles);
    };
  });

  setUp(() {
    interceptoresOriginales = ApiClient.dio.interceptors.toList();
    ApiClient.dio.interceptors.clear();
    ApiClient.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final Object data = switch (options.path) {
            '/postulaciones/mias' => _postulacionesDemo(),
            '/preferencias-autopilot' => {
              'activo': true,
              'revisarAntes': true,
              'cvId': 'cv-1',
              'scoreMinimo': 70,
              'maxPorDia': 5,
            },
            '/ofertas' => _ofertasDemo(),
            '/cv' => [
              {'id': 'cv-1', 'titulo': 'CV Principal'},
            ],
            '/habilidades/cv/cv-1' => _habilidadesDemo(),
            '/mensajes/sin-leer' => {'sinLeer': 3},
            '/conversaciones' => <Map<String, dynamic>>[],
            '/suscripciones/mia' => {'tipoPlan': 'MENSUAL'},
            '/postulaciones-autopilot/historial' => <Map<String, dynamic>>[],
            _ => <String, dynamic>{},
          };
          handler.resolve(Response(requestOptions: options, data: data));
        },
      ),
    );
  });

  tearDown(() {
    ApiClient.dio.interceptors.clear();
    ApiClient.dio.interceptors.addAll(interceptoresOriginales);
  });

  testWidgets('candidato: muestra Hoy, 4 cifras, 2 mejores matches y 5 pestañas', (
    tester,
  ) async {
    await abrirHome(tester, candidato);

    // Cabecera, título "Hoy" y frase resumen
    expect(find.text('JIn1Step'), findsOneWidget);
    expect(find.byType(NotificationBell), findsOneWidget);
    expect(find.text('Hoy'), findsWidgets);
    expect(
      find.textContaining('Tienes 1 entrevista y 3 mensajes sin leer.'),
      findsOneWidget,
    );

    // 4 cifras en KpiGrid (12 candidaturas, 1 entrevista, 6 pendientes, 3 mensajes)
    expect(find.byType(KpiGrid), findsOneWidget);
    expect(find.text('Candidaturas'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Entrevistas'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Pendientes de revisión'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('Mensajes sin leer'), findsOneWidget);

    // 2 mejores matches y enlace "Ver todas las ofertas"
    expect(find.text('Mejores matches'), findsOneWidget);
    expect(find.text('Ver todas las ofertas'), findsOneWidget);
    expect(find.text('React Junior'), findsOneWidget);
    expect(find.text('94 %'), findsOneWidget);
    expect(find.text('Full Stack .NET'), findsOneWidget);
    expect(find.text('68 %'), findsOneWidget);
    // QA Automation (30 %) no sale entre los 2 mejores
    expect(find.text('QA Automation'), findsNothing);

    // Barra inferior de 5 pestañas
    expect(find.byType(BottomNav), findsOneWidget);
    for (final pestana in ['Inicio', 'Ofertas', 'Autopiloto', 'Chat', 'Mi CV']) {
      expect(
        find.descendant(of: find.byType(BottomNav), matching: find.text(pestana)),
        findsOneWidget,
      );
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('enlace "Ver todas las ofertas" cambia a la pestaña Ofertas', (
    tester,
  ) async {
    await abrirHome(tester, candidato);

    await tester.tap(find.text('Ver todas las ofertas'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ordenadas por lo bien que encajan con tu CV'),
      findsOneWidget,
    );
    expect(find.text('QA Automation'), findsOneWidget);
  });

  testWidgets('reclutador: ve su resumen sin Autopiloto', (tester) async {
    await abrirHome(tester, reclutador);

    expect(find.text('Hola, Luis'), findsOneWidget);
    expect(find.text('Mis ofertas'), findsWidgets);
    expect(find.text('Autopiloto'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin argumentos no revienta', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) =>
            MaterialPageRoute(builder: (_) => const Home()),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'OfertaDetalle calcula match híbrido (50/20/30) con descripción, hallazgo y palabras clave',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final ofertaConDescripcion = {
        'id': 'o-hibrida',
        'titulo': 'Backend Node.js',
        'modalidad': 'REMOTO',
        'empresa': {'nombre': 'Cloud Iber'},
        'descripcion':
            'Buscamos perfil con experiencia en Node.js, TypeScript, Docker y PostgreSQL bajo metodología Scrum.',
        'requisitos': [
          {
            'obligatorio': true,
            'habilidad': {'nombre': 'Node.js'},
          },
          {
            'obligatorio': true,
            'habilidad': {'nombre': 'Docker'},
          },
          {
            'obligatorio': false,
            'habilidad': {'nombre': 'PostgreSQL'},
          },
        ],
      };

      // El candidato tiene Node.js y PostgreSQL en habilidades y menciona
      // TypeScript y Scrum en el texto de su CV; le falta Docker.
      final habilidades = {
        'node.js',
        'postgresql',
        ...MatchOferta.extraerTerminosDeTexto(
          'Experiencia de 3 años desarrollando con TypeScript en equipos Scrum.',
        ),
      };

      final match = MatchOferta.calcular(ofertaConDescripcion, habilidades);
      // Obligatorias: 1/2 (50 % * 0.50 = 25)
      // Deseables: 1/1 (100 % * 0.20 = 20)
      // Descripción: 4/5 (Node.js, TypeScript, PostgreSQL, Scrum cubiertos; falta Docker -> 80 % * 0.30 = 24)
      // Total: 25 + 20 + 24 = 69 %
      expect(match.score, 69);
      expect(match.porcentajeDescripcion, 80);
      expect(match.hallazgo?.nombre, 'Docker');
      expect(match.hallazgo?.nuevoScore, 100);

      await tester.pumpWidget(
        MaterialApp(
          theme: construirTemaApp(),
          home: OfertaDetalle(
            oferta: ofertaConDescripcion,
            habilidadesCv: habilidades,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('69 %'), findsOneWidget);
      expect(
        find.text(
          'de match con tu CV principal. Obligatorias 50 %, deseables 20 %, descripción 30 %.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Con Docker pasarías de 69 % a 100 %.'),
        findsOneWidget,
      );
      expect(find.text('Encaje con la descripción'), findsOneWidget);
      expect(find.text('4 de 5 (80 %)'), findsOneWidget);
      expect(find.text('Descripción de la oferta'), findsOneWidget);
      expect(find.text('TypeScript · En tu CV'), findsOneWidget);
      expect(find.text('Docker · Falta en CV'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
