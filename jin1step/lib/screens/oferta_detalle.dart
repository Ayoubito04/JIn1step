import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/candidato.service.dart';
import '../services/chat.service.dart';
import '../widgets/design_system.dart';
import 'mensajes.dart';
import 'mis_cvs.dart';

/// Texto visible de la modalidad (los valores reales son los del enum del
/// backend: REMOTO, HIBRIDO, PRESENCIAL).
String etiquetaModalidad(String valor) => switch (valor) {
  'REMOTO' => 'Remoto',
  'HIBRIDO' => 'Híbrido',
  'PRESENCIAL' => 'Presencial',
  _ => valor,
};

/// Resultado de cruzar los requisitos y la descripción de una oferta con las
/// habilidades y el texto del CV principal. Lo comparten Inicio, el listado y
/// el detalle para que todos muestren exactamente las mismas cifras.
class MatchOferta {
  const MatchOferta({
    required this.score,
    required this.obligatoriasCubiertas,
    required this.obligatoriasTotal,
    required this.deseablesCubiertas,
    required this.deseablesTotal,
    required this.cubiertos,
    required this.faltantes,
    this.descripcionCubiertas = const [],
    this.descripcionFaltantes = const [],
    this.porcentajeDescripcion = 0,
    this.hallazgo,
  });

  final int score;
  final int obligatoriasCubiertas;
  final int obligatoriasTotal;
  final int deseablesCubiertas;
  final int deseablesTotal;

  /// Nombres de los requisitos que el CV ya cubre (obligatorios primero).
  final List<String> cubiertos;

  /// Requisitos que faltan (obligatorios primero).
  final List<({String nombre, bool obligatorio})> faltantes;

  /// Términos clave de la descripción presentes en el CV.
  final List<String> descripcionCubiertas;

  /// Términos clave de la descripción que no aparecen en el CV.
  final List<String> descripcionFaltantes;

  /// Porcentaje (0-100) de términos clave de la descripción cubiertos por el CV.
  final int porcentajeDescripcion;

  /// Qué habilidad o término faltante subiría más el match si se añade al CV.
  final ({String nombre, int nuevoScore})? hallazgo;

  int get descripcionTotal =>
      descripcionCubiertas.length + descripcionFaltantes.length;

  static const _pesoObligatorias = 0.50;
  static const _pesoDeseables = 0.20;
  static const _pesoDescripcion = 0.30;

  static const _terminosClave = <({String etiqueta, List<String> variantes})>[
    (etiqueta: 'React', variantes: ['react', 'reactjs', 'react.js']),
    (etiqueta: 'Angular', variantes: ['angular', 'angularjs']),
    (etiqueta: 'Vue.js', variantes: ['vue', 'vuejs', 'vue.js']),
    (etiqueta: 'TypeScript', variantes: ['typescript', 'ts']),
    (etiqueta: 'JavaScript', variantes: ['javascript', 'js', 'ecmascript']),
    (etiqueta: 'Node.js', variantes: ['node.js', 'nodejs', 'node']),
    (etiqueta: 'Next.js', variantes: ['next.js', 'nextjs']),
    (etiqueta: 'NestJS', variantes: ['nestjs', 'nest.js']),
    (etiqueta: 'Express', variantes: ['express', 'expressjs']),
    (etiqueta: 'HTML', variantes: ['html', 'html5']),
    (etiqueta: 'CSS', variantes: ['css', 'css3', 'sass', 'scss']),
    (etiqueta: 'Tailwind', variantes: ['tailwind', 'tailwindcss']),
    (etiqueta: 'Python', variantes: ['python', 'py']),
    (etiqueta: 'Django', variantes: ['django']),
    (etiqueta: 'FastAPI', variantes: ['fastapi']),
    (etiqueta: 'Java', variantes: ['java']),
    (etiqueta: 'Spring Boot', variantes: ['spring boot', 'spring']),
    (etiqueta: 'C#', variantes: ['c#', 'csharp', 'c sharp']),
    (
      etiqueta: '.NET',
      variantes: ['.net', 'dotnet', 'net core', '.net core', 'asp.net'],
    ),
    (etiqueta: 'C++', variantes: ['c++', 'cpp']),
    (etiqueta: 'PHP', variantes: ['php']),
    (etiqueta: 'Laravel', variantes: ['laravel']),
    (etiqueta: 'Go', variantes: ['golang']),
    (etiqueta: 'Rust', variantes: ['rust']),
    (etiqueta: 'Kotlin', variantes: ['kotlin']),
    (etiqueta: 'Swift', variantes: ['swift']),
    (etiqueta: 'Flutter', variantes: ['flutter']),
    (etiqueta: 'Dart', variantes: ['dart']),
    (etiqueta: 'SQL', variantes: ['sql']),
    (etiqueta: 'PostgreSQL', variantes: ['postgresql', 'postgres', 'psql']),
    (etiqueta: 'MySQL', variantes: ['mysql', 'my sql']),
    (etiqueta: 'MongoDB', variantes: ['mongodb', 'mongo']),
    (etiqueta: 'Redis', variantes: ['redis']),
    (etiqueta: 'Prisma', variantes: ['prisma']),
    (etiqueta: 'Docker', variantes: ['docker', 'contenedores']),
    (etiqueta: 'Kubernetes', variantes: ['kubernetes', 'k8s']),
    (etiqueta: 'AWS', variantes: ['aws', 'amazon web services']),
    (etiqueta: 'Azure', variantes: ['azure']),
    (etiqueta: 'Google Cloud', variantes: ['gcp', 'google cloud']),
    (etiqueta: 'Firebase', variantes: ['firebase']),
    (etiqueta: 'Git', variantes: ['git', 'github', 'gitlab']),
    (etiqueta: 'CI/CD', variantes: ['ci/cd', 'cicd', 'integracion continua']),
    (etiqueta: 'Linux', variantes: ['linux', 'ubuntu', 'bash']),
    (etiqueta: 'REST', variantes: ['rest', 'api rest', 'restful']),
    (etiqueta: 'GraphQL', variantes: ['graphql']),
    (etiqueta: 'Microservicios', variantes: ['microservicios', 'microservices']),
    (
      etiqueta: 'Testing',
      variantes: ['testing', 'pruebas unitarias', 'unit test', 'tdd'],
    ),
    (etiqueta: 'Jest', variantes: ['jest', 'vitest']),
    (etiqueta: 'Cypress', variantes: ['cypress', 'playwright']),
    (etiqueta: 'Selenium', variantes: ['selenium']),
    (etiqueta: 'Scrum', variantes: ['scrum', 'agile', 'agil', 'kanban']),
    (etiqueta: 'Figma', variantes: ['figma']),
    (etiqueta: 'Inglés', variantes: ['ingles', 'english', 'b2', 'c1']),
    (etiqueta: 'Frontend', variantes: ['frontend', 'front-end', 'front end']),
    (etiqueta: 'Backend', variantes: ['backend', 'back-end', 'back end']),
    (
      etiqueta: 'Full Stack',
      variantes: ['full stack', 'fullstack', 'full-stack'],
    ),
    (etiqueta: 'DevOps', variantes: ['devops']),
    (
      etiqueta: 'Clean Architecture',
      variantes: ['clean architecture', 'arquitectura limpia', 'solid', 'ddd'],
    ),
  ];

  static String normalizar(String nombre) => _quitarAcentos(
    nombre.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
  );

  static String _quitarAcentos(String texto) => texto
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u');

  static bool _apareceEnTexto(String textoNorm, String termino) {
    final t = normalizar(termino);
    if (t.isEmpty) return false;
    final patron = RegExp(
      '(?<![a-z0-9.])${RegExp.escape(t)}(?![a-z0-9])',
      caseSensitive: false,
    );
    return patron.hasMatch(textoNorm);
  }

  /// Extrae términos clave reconocidos dentro de un texto libre (p. ej. el
  /// contenido del CV) para enriquecer el conjunto de habilidades del candidato.
  static Set<String> extraerTerminosDeTexto(String? texto) {
    if (texto == null || texto.trim().isEmpty) return <String>{};
    final norm = normalizar(texto);
    final detectados = <String>{};
    for (final item in _terminosClave) {
      final variantes = [item.etiqueta, ...item.variantes];
      if (variantes.any((v) => _apareceEnTexto(norm, v))) {
        detectados.add(normalizar(item.etiqueta));
        for (final v in item.variantes) {
          detectados.add(normalizar(v));
        }
      }
    }
    return detectados;
  }

  /// Habilidades (normalizadas) del CV principal, combinando las habilidades
  /// estructuradas y los términos detectados en `contenidoTexto`.
  static Future<Set<String>> cargarHabilidadesCv(
    CandidatoService service,
  ) async {
    final cvs = await service.listarCvs();
    if (cvs.isEmpty) return <String>{};
    final cvPrincipal = cvs.first;
    final habilidades = await service.listarHabilidadesCv(
      cvPrincipal['id'] as String,
    );
    final resultado = habilidades
        .map((item) => (item['habilidad'] as Map<String, dynamic>?)?['nombre'])
        .whereType<String>()
        .map(normalizar)
        .toSet();
    resultado.addAll(
      extraerTerminosDeTexto(cvPrincipal['contenidoTexto'] as String?),
    );
    return resultado;
  }

  static int _computarScore({
    required int cubiertasO,
    required int totalO,
    required int cubiertasD,
    required int totalD,
    required int cubiertasDesc,
    required int totalDesc,
  }) {
    if (totalO == 0 && totalD == 0 && totalDesc == 0) return 0;
    if (totalDesc == 0 && totalO > 0 && totalD > 0) {
      final ratioO = cubiertasO / totalO;
      final ratioD = cubiertasD / totalD;
      return (ratioO * 70 + ratioD * 30).round();
    }
    var sumaPuntos = 0.0;
    var sumaPesos = 0.0;
    if (totalO > 0) {
      sumaPuntos += (cubiertasO / totalO) * _pesoObligatorias;
      sumaPesos += _pesoObligatorias;
    }
    if (totalD > 0) {
      sumaPuntos += (cubiertasD / totalD) * _pesoDeseables;
      sumaPesos += _pesoDeseables;
    }
    if (totalDesc > 0) {
      sumaPuntos += (cubiertasDesc / totalDesc) * _pesoDescripcion;
      sumaPesos += _pesoDescripcion;
    }
    return sumaPesos > 0 ? ((sumaPuntos / sumaPesos) * 100).round() : 0;
  }

  factory MatchOferta.calcular(
    Map<String, dynamic> oferta,
    Set<String> habilidadesCv, {
    String? textoCv,
  }) {
    final cvSet = <String>{
      ...habilidadesCv.map(normalizar),
      ...extraerTerminosDeTexto(textoCv),
    };
    final textoCvUnido = [
      ...cvSet,
      if (textoCv != null) normalizar(textoCv),
    ].join(' ');

    bool cvCubreVariantes(Iterable<String> variantes) => variantes.any((v) {
      final norm = normalizar(v);
      return cvSet.contains(norm) || _apareceEnTexto(textoCvUnido, norm);
    });

    final requisitos = (oferta['requisitos'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    String? nombreDe(Map<String, dynamic> r) =>
        (r['habilidad'] as Map<String, dynamic>?)?['nombre'] as String?;
    final obligatorias = requisitos.where((r) => r['obligatorio'] != false);
    final deseables = requisitos.where((r) => r['obligatorio'] == false);

    final cubiertos = <String>[];
    final faltantes = <({String nombre, bool obligatorio})>[];
    int procesar(Iterable<Map<String, dynamic>> lista, bool obligatorio) {
      var cubiertas = 0;
      for (final requisito in lista) {
        final nombre = nombreDe(requisito);
        if (nombre == null) continue;
        if (cvCubreVariantes([nombre])) {
          cubiertas++;
          cubiertos.add(nombre);
        } else {
          faltantes.add((nombre: nombre, obligatorio: obligatorio));
        }
      }
      return cubiertas;
    }

    final cubiertasO = procesar(obligatorias, true);
    final cubiertasD = procesar(deseables, false);
    final totalO = obligatorias.length, totalD = deseables.length;

    // Análisis de la descripción de la oferta frente al CV.
    final descripcionRaw = (oferta['descripcion'] as String? ?? '').trim();
    final descripcionNorm = normalizar(descripcionRaw);
    final descCubiertas = <String>[];
    final descFaltantes = <String>[];

    if (descripcionNorm.isNotEmpty) {
      final candidatos = <String, List<String>>{
        for (final item in _terminosClave) item.etiqueta: item.variantes,
      };
      for (final r in requisitos) {
        final n = nombreDe(r);
        if (n != null && !candidatos.containsKey(n)) {
          candidatos[n] = [n];
        }
      }

      for (final entry in candidatos.entries) {
        final todas = [entry.key, ...entry.value];
        final enOferta = todas.any((v) => _apareceEnTexto(descripcionNorm, v));
        if (!enOferta) continue;
        if (cvCubreVariantes(todas)) {
          descCubiertas.add(entry.key);
        } else {
          descFaltantes.add(entry.key);
        }
      }
    }

    final totalDesc = descCubiertas.length + descFaltantes.length;
    final porcentajeDesc = totalDesc == 0
        ? 0
        : ((descCubiertas.length / totalDesc) * 100).round();

    final score = _computarScore(
      cubiertasO: cubiertasO,
      totalO: totalO,
      cubiertasD: cubiertasD,
      totalD: totalD,
      cubiertasDesc: descCubiertas.length,
      totalDesc: totalDesc,
    );

    // Hallazgo: qué requisito o término faltante impulsa más el match.
    ({String nombre, int nuevoScore})? mejorHallazgo;
    final descFaltantesNorm = descFaltantes.map(normalizar).toSet();
    for (final f in faltantes) {
      final sumaO = f.obligatorio ? 1 : 0;
      final sumaD = f.obligatorio ? 0 : 1;
      final sumaDesc = descFaltantesNorm.contains(normalizar(f.nombre)) ? 1 : 0;
      final simulado = _computarScore(
        cubiertasO: cubiertasO + sumaO,
        totalO: totalO,
        cubiertasD: cubiertasD + sumaD,
        totalD: totalD,
        cubiertasDesc: descCubiertas.length + sumaDesc,
        totalDesc: totalDesc,
      );
      if (simulado > score &&
          (mejorHallazgo == null || simulado > mejorHallazgo.nuevoScore)) {
        mejorHallazgo = (nombre: f.nombre, nuevoScore: simulado);
      }
    }
    if (mejorHallazgo == null && descFaltantes.isNotEmpty) {
      final simulado = _computarScore(
        cubiertasO: cubiertasO,
        totalO: totalO,
        cubiertasD: cubiertasD,
        totalD: totalD,
        cubiertasDesc: descCubiertas.length + 1,
        totalDesc: totalDesc,
      );
      if (simulado > score) {
        mejorHallazgo = (nombre: descFaltantes.first, nuevoScore: simulado);
      }
    }

    return MatchOferta(
      score: score,
      obligatoriasCubiertas: cubiertasO,
      obligatoriasTotal: totalO,
      deseablesCubiertas: cubiertasD,
      deseablesTotal: totalD,
      cubiertos: cubiertos,
      faltantes: faltantes,
      descripcionCubiertas: descCubiertas,
      descripcionFaltantes: descFaltantes,
      porcentajeDescripcion: porcentajeDesc,
      hallazgo: mejorHallazgo,
    );
  }
}

class OfertaDetalle extends StatefulWidget {
  const OfertaDetalle({super.key, required this.oferta, this.habilidadesCv});

  final Map<String, dynamic> oferta;

  /// Habilidades normalizadas del CV principal, si el listado ya las tiene.
  /// Si es null, el detalle las carga por su cuenta.
  final Set<String>? habilidadesCv;

  @override
  State<OfertaDetalle> createState() => _OfertaDetalleState();
}

class _OfertaDetalleState extends State<OfertaDetalle> {
  final _service = CandidatoService();
  final _chatService = ChatService();
  bool _cargando = false;
  Map<String, dynamic>? _postulacionExistente;
  String? _error;
  late Set<String>? _habilidadesCv = widget.habilidadesCv;

  String? get _ofertaId => widget.oferta['id'] as String?;

  Future<void> _contactarReclutador() async {
    final recruiter = widget.oferta['reclutador'] as Map<String, dynamic>?;
    final recruiterId = recruiter?['id'] as String?;
    if (recruiterId == null || _ofertaId == null) {
      setState(() => _error = 'No se pudo identificar al reclutador de esta oferta.');
      return;
    }
    try {
      final conversation = await _chatService.abrir(usuarioId: recruiterId, ofertaId: _ofertaId);
      final currentUser = conversation['candidato'] as Map<String, dynamic>?;
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatThreadPage(
        conversacion: {...conversation, 'interlocutor': conversation['reclutador'] ?? recruiter},
        usuarioId: currentUser?['id'] as String? ?? '',
      )));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    _comprobarPostulacionExistente();
    if (_habilidadesCv == null) _cargarHabilidadesCv();
  }

  Future<void> _cargarHabilidadesCv() async {
    try {
      final habilidades = await MatchOferta.cargarHabilidadesCv(_service);
      if (mounted) setState(() => _habilidadesCv = habilidades);
    } catch (_) {
      // Sin CV legible se muestra el match con cero habilidades cubiertas.
      if (mounted) setState(() => _habilidadesCv = <String>{});
    }
  }

  Future<void> _comprobarPostulacionExistente() async {
    final ofertaId = _ofertaId;
    if (ofertaId == null) return;
    try {
      final postulaciones = await _service.listarPostulaciones();
      for (final postulacion in postulaciones) {
        final oferta = postulacion['oferta'] as Map<String, dynamic>?;
        if (oferta?['id'] == ofertaId) {
          if (mounted) setState(() => _postulacionExistente = postulacion);
          return;
        }
      }
    } catch (_) {
      // El detalle sigue visible aunque el historial no pueda cargarse; el
      // endpoint de creación vuelve a proteger contra duplicados.
    }
  }

  Future<void> _postularse() async {
    if (_cargando || _ofertaId == null) return;
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final cvs = await _service.listarCvs();
      Map<String, dynamic>? cvSeleccionado;
      if (cvs.isEmpty) {
        if (!mounted) return;
        cvSeleccionado = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(builder: (_) => const MisCvsPage()),
        );
        if (cvSeleccionado == null) return;
      } else {
        if (!mounted) return;
        cvSeleccionado = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.micro,
                AppSpacing.screen,
                AppSpacing.screen,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Elegir el CV para esta candidatura'),
                  const SizedBox(height: AppSpacing.gap),
                  for (final cv in cvs) ...[
                    SecondaryButton(
                      label: cv['titulo'] as String? ?? 'Currículum',
                      leading: const Icon(Icons.description_outlined, size: 20),
                      onPressed: () => Navigator.pop(context, cv),
                    ),
                    const SizedBox(height: AppSpacing.group),
                  ],
                  SecondaryButton(
                    label: 'Subir otro CV',
                    leading: const Icon(Icons.add, size: 20),
                    onPressed: () async {
                      final nuevo = await Navigator.of(context)
                          .push<Map<String, dynamic>>(
                            MaterialPageRoute(
                              builder: (_) => const MisCvsPage(),
                            ),
                          );
                      if (context.mounted && nuevo != null) {
                        Navigator.pop(context, nuevo);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
        if (cvSeleccionado == null) return;
      }

      final resultado = await _service.postular(
        ofertaId: _ofertaId!,
        cvId: cvSeleccionado['id'] as String,
      );
      if (!mounted) return;
      setState(() => _postulacionExistente = resultado);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Tu candidatura se ha enviado!')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final oferta = widget.oferta;
    final empresa = oferta['empresa'] as Map<String, dynamic>?;
    final titulo = oferta['titulo'] as String? ?? 'Oferta';
    final nombreEmpresa = empresa?['nombre'] as String?;
    final modalidad = oferta['modalidad'] as String?;
    final salario = (oferta['salario'] as String?)?.trim();
    final subtitulo = [
      ?nombreEmpresa,
      if (modalidad != null) etiquetaModalidad(modalidad),
      if (salario != null && salario.isNotEmpty) salario,
    ].join(' · ');
    final hayRequisitos = (oferta['requisitos'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .isNotEmpty;
    final estaAbierta =
        oferta['estado'] == null || oferta['estado'] == 'ABIERTA';
    final yaPostulada = _postulacionExistente != null;
    final habilidades = _habilidadesCv;
    final match = habilidades == null
        ? null
        : MatchOferta.calcular(oferta, habilidades);

    final puedePostular =
        !_cargando && !yaPostulada && estaAbierta && hayRequisitos;
    final etiquetaPostular = yaPostulada
        ? 'Ya te has postulado'
        : !hayRequisitos
        ? 'Pendiente de requisitos'
        : !estaAbierta
        ? 'Oferta cerrada'
        : 'Postular con mi CV';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AppIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Volver a ofertas',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(height: AppSpacing.gap),
            ScreenHeader(
              title: titulo,
              subtitle: subtitulo.isEmpty ? null : subtitulo,
            ),
            const SizedBox(height: AppSpacing.gap),
            if (match == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: AppSpinner(size: 24)),
              )
            else ...[
              _bloqueMatch(match),
              const SizedBox(height: AppSpacing.gap),
              _requisitos(match, hayRequisitos),
              if ((oferta['descripcion'] as String?)?.trim().isNotEmpty ==
                  true) ...[
                const SizedBox(height: AppSpacing.gap),
                _seccionDescripcion(oferta, match),
              ],
            ],
            const SizedBox(height: AppSpacing.gap),
            if (_error != null) ...[
              Notice(message: _error!, variant: StatusVariant.error),
              const SizedBox(height: AppSpacing.gap),
            ],
            if (puedePostular || _cargando)
              PrimaryButton(
                label: etiquetaPostular,
                loading: _cargando,
                loadingLabel: 'Enviando candidatura…',
                onPressed: _postularse,
              )
            else
              SecondaryButton(label: etiquetaPostular, onPressed: null),
            const SizedBox(height: AppSpacing.group),
            SecondaryButton(
              label: 'Escribir al reclutador',
              onPressed: _contactarReclutador,
            ),
          ],
        ),
      ),
    );
  }

  /// Match grande con sus pasos y el desglose obligatorias / deseables / descripción.
  Widget _bloqueMatch(MatchOferta match) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Match del ${match.score} %',
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${match.score} %', style: AppText.display),
                const SizedBox(width: AppSpacing.gap),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.micro),
                  child: Steps(filled: pasosDeMatch(match.score), animar: true),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.group),
        Text(
          match.descripcionTotal > 0
              ? 'de match con tu CV principal. Obligatorias 50 %, deseables 20 %, descripción 30 %.'
              : 'de match con tu CV principal. Obligatorias 70 %, deseables 30 %.',
          style: AppText.mutedBody,
        ),
        if (match.hallazgo != null) ...[
          const SizedBox(height: AppSpacing.group),
          Text(
            'Con ${match.hallazgo!.nombre} pasarías de ${match.score} % a ${match.hallazgo!.nuevoScore} %.',
            style: AppText.bodyStrong,
          ),
        ],
        const SizedBox(height: AppSpacing.gap),
        const Divider(),
        _FilaCifra(
          etiqueta: 'Obligatorias',
          valor: '${match.obligatoriasCubiertas} de ${match.obligatoriasTotal}',
        ),
        const Divider(),
        _FilaCifra(
          etiqueta: 'Deseables',
          valor: '${match.deseablesCubiertas} de ${match.deseablesTotal}',
        ),
        if (match.descripcionTotal > 0) ...[
          const Divider(),
          _FilaCifra(
            etiqueta: 'Encaje con la descripción',
            valor:
                '${match.descripcionCubiertas.length} de ${match.descripcionTotal} (${match.porcentajeDescripcion} %)',
          ),
        ],
        if (((widget.oferta['salario'] as String?) ?? '').trim().isNotEmpty) ...[
          const Divider(),
          _FilaCifra(
            etiqueta: 'Salario ofrecido',
            valor: (widget.oferta['salario'] as String).trim(),
          ),
        ],
      ],
    ),
  );

  /// Lista de requisitos en un solo panel: Cubierto / Falta por fila.
  Widget _requisitos(MatchOferta match, bool hayRequisitos) {
    if (!hayRequisitos) {
      return SizedBox(
        width: double.infinity,
        child: Panel(
          child: Text(
            'Esta oferta todavía no tiene requisitos definidos.',
            style: AppText.mutedBody,
          ),
        ),
      );
    }
    final cubiertosNorm = match.cubiertos.map(MatchOferta.normalizar).toSet();
    final requisitos = (widget.oferta['requisitos'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (r) => (
            nombre: (r['habilidad'] as Map<String, dynamic>?)?['nombre']
                as String?,
            obligatorio: r['obligatorio'] != false,
          ),
        )
        .where((r) => r.nombre != null)
        .toList()
      ..sort((a, b) => a.obligatorio == b.obligatorio
          ? 0
          : a.obligatorio
          ? -1
          : 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Requisitos'),
        const SizedBox(height: AppSpacing.group),
        PanelList(
          children: [
            for (final r in requisitos)
              ListRow(
                title: r.nombre!,
                lines: [r.obligatorio ? 'Obligatoria' : 'Deseable'],
                strongTitle: false,
                trailing: cubiertosNorm.contains(MatchOferta.normalizar(r.nombre!))
                    ? const StatusTag(
                        label: 'Cubierto',
                        variant: StatusVariant.success,
                      )
                    : const StatusTag(
                        label: 'Falta',
                        variant: StatusVariant.error,
                      ),
              ),
          ],
        ),
      ],
    );
  }

  /// Descripción completa de la oferta y términos clave detectados frente al CV.
  Widget _seccionDescripcion(Map<String, dynamic> oferta, MatchOferta match) {
    final descripcion = (oferta['descripcion'] as String? ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Descripción de la oferta'),
        const SizedBox(height: AppSpacing.group),
        SizedBox(
          width: double.infinity,
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(descripcion, style: AppText.body),
                if (match.descripcionTotal > 0) ...[
                  const SizedBox(height: AppSpacing.gap),
                  const Divider(),
                  const SizedBox(height: AppSpacing.group),
                  Text(
                    'Términos clave detectados en la descripción',
                    style: AppText.meta,
                  ),
                  const SizedBox(height: AppSpacing.group),
                  Wrap(
                    spacing: AppSpacing.group,
                    runSpacing: AppSpacing.group,
                    children: [
                      for (final termino in match.descripcionCubiertas)
                        StatusTag(
                          label: '$termino · En tu CV',
                          variant: StatusVariant.success,
                        ),
                      for (final termino in match.descripcionFaltantes)
                        StatusTag(
                          label: '$termino · Falta en CV',
                          variant: StatusVariant.warning,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Fila «Obligatorias · 3 de 4» dentro del panel del match.
class _FilaCifra extends StatelessWidget {
  const _FilaCifra({
    required this.etiqueta,
    required this.valor,
  });

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.group),
    child: Row(
      children: [
        Expanded(child: Text(etiqueta, style: AppText.body)),
        const SizedBox(width: AppSpacing.group),
        Text(valor, style: AppText.numInline),
      ],
    ),
  );
}
