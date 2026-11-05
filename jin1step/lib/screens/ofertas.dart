import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/candidato.service.dart';
import '../services/ofertas.services.dart';
import '../widgets/design_system.dart';
import 'oferta_detalle.dart';

class Ofertas extends StatefulWidget {
  const Ofertas({super.key, this.ofertaService});

  final OfertasService? ofertaService;

  /// Extrae el salario base (mínimo garantizado de la horquilla) en euros
  /// anuales a partir de textos como "30.000 - 38.000 € brutos/año" (-> 30000),
  /// "45k" (-> 45000) o "40000 €" (-> 40000).
  static int? extraerSalarioOferta(String? textoSalario) =>
      _OfertasState.extraerSalarioOferta(textoSalario);

  @override
  State<Ofertas> createState() => _OfertasState();
}

class _OfertasState extends State<Ofertas> {
  late final OfertasService _ofertasService =
      widget.ofertaService ?? OfertasService();

  late Future<List<Map<String, dynamic>>> _futuroOfertas = _ofertasService
      .getAllOfertas();
  final _candidatoService = CandidatoService();
  Set<String> _habilidadesCv = {};
  bool _cvCargado = false;

  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';
  // null = "Todas". Los otros valores son exactamente los del enum
  // Modalidad del backend, así el filtro nunca desincroniza con la API.
  String? _modalidadFiltro;
  String? _ubicacionFiltro;
  int? _diasPublicacionFiltro;
  int? _salarioMinimoFiltro;

  // (etiqueta visible, valor real del backend o null para "Todas").
  static const _opcionesModalidad = <(String, String?)>[
    ('Todas', null),
    ('Remoto', 'REMOTO'),
    ('Híbrido', 'HIBRIDO'),
    ('Presencial', 'PRESENCIAL'),
  ];

  static const _opcionesFecha = <(String, int?)>[
    ('Cualquier fecha', null),
    ('Últimas 24 h', 1),
    ('Últimos 7 días', 7),
    ('Últimos 15 días', 15),
    ('Últimos 30 días', 30),
  ];

  static const _opcionesSalarioMinimo = <int?>[
    null,
    25000,
    30000,
    35000,
    40000,
    45000,
    50000,
    55000,
  ];

  @override
  void initState() {
    super.initState();
    _cargarHabilidadesCv();
  }

  Future<void> _cargarHabilidadesCv() async {
    try {
      final nombres = await MatchOferta.cargarHabilidadesCv(_candidatoService);
      if (mounted) {
        setState(() {
          _habilidadesCv = nombres;
          _cvCargado = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cvCargado = true);
    }
  }

  Future<void> _recargarOfertas() async {
    final nuevoFuturo = _ofertasService.getAllOfertas();
    setState(() {
      _futuroOfertas = nuevoFuturo;
    });
    await nuevoFuturo;
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  bool get _hayFiltrosActivos =>
      _busqueda.trim().isNotEmpty ||
      _modalidadFiltro != null ||
      _ubicacionFiltro != null ||
      _diasPublicacionFiltro != null ||
      _salarioMinimoFiltro != null;

  void _limpiarTodosLosFiltros() {
    _busquedaCtrl.clear();
    setState(() {
      _busqueda = '';
      _modalidadFiltro = null;
      _ubicacionFiltro = null;
      _diasPublicacionFiltro = null;
      _salarioMinimoFiltro = null;
    });
  }

  /// Normaliza minúsculas y elimina tildes para que buscar "malaga" o "diseno"
  /// encuentre "Málaga" o "Diseño".
  static String _normalizarTexto(String texto) {
    return texto
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('ü', 'u')
        .trim();
  }

  /// Extrae el salario base (mínimo garantizado de la horquilla) en euros
  /// anuales a partir de textos como "30.000 - 38.000 € brutos/año" (-> 30000),
  /// "45k" (-> 45000) o "40000 €" (-> 40000).
  static int? extraerSalarioOferta(String? textoSalario) {
    if (textoSalario == null || textoSalario.trim().isEmpty) return null;
    var limpio = textoSalario.toLowerCase();
    final milesRegex = RegExp(r'(\d)[.,](\d{3})(?!\d)');
    while (milesRegex.hasMatch(limpio)) {
      limpio = limpio.replaceAllMapped(
        milesRegex,
        (m) => '${m.group(1)}${m.group(2)}',
      );
    }
    final coincidencias = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(k)?',
    ).allMatches(limpio);
    int? minimo;
    for (final m in coincidencias) {
      final numero = double.tryParse((m.group(1) ?? '').replaceAll(',', '.'));
      if (numero == null) continue;
      final esMiles = m.group(2) == 'k' || (numero >= 12 && numero < 200);
      final anual = (esMiles ? numero * 1000 : numero).round();
      if (anual >= 1000 && (minimo == null || anual < minimo)) {
        minimo = anual;
      }
    }
    return minimo;
  }

  static String _formatearEuros(int valor) {
    final s = valor.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return '$buffer €';
  }

  static String? _textoFechaRelativa(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final fecha = DateTime.tryParse(iso)?.toLocal();
    if (fecha == null) return null;
    final diff = DateTime.now().difference(fecha);
    if (diff.inHours < 24) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d';
    if (diff.inDays < 30) return 'Hace ${(diff.inDays / 7).floor()} sem';
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  bool _cumpleFiltros(
    Map<String, dynamic> oferta, {
    required DateTime ahora,
    required List<String> terminosBusqueda,
    bool ignorarModalidad = false,
    bool ignorarUbicacion = false,
    bool ignorarFecha = false,
    bool ignorarSalario = false,
  }) {
    if (!ignorarModalidad &&
        _modalidadFiltro != null &&
        oferta['modalidad'] != _modalidadFiltro) {
      return false;
    }

    final empresa = oferta['empresa'] as Map<String, dynamic>?;
    final ubicacionEmpresa = (empresa?['ubicacion'] as String?)?.trim() ?? '';

    if (!ignorarUbicacion &&
        _ubicacionFiltro != null &&
        _normalizarTexto(ubicacionEmpresa) !=
            _normalizarTexto(_ubicacionFiltro!)) {
      return false;
    }

    if (!ignorarFecha && _diasPublicacionFiltro != null) {
      final fechaStr = oferta['fechaPublicacion'] as String?;
      final fecha = fechaStr != null ? DateTime.tryParse(fechaStr) : null;
      if (fecha == null) return false;
      final limite = ahora.subtract(Duration(days: _diasPublicacionFiltro!));
      if (fecha.isBefore(limite)) return false;
    }

    if (!ignorarSalario && _salarioMinimoFiltro != null) {
      final salarioOferta = extraerSalarioOferta(oferta['salario'] as String?);
      if (salarioOferta == null || salarioOferta < _salarioMinimoFiltro!) {
        return false;
      }
    }

    if (terminosBusqueda.isEmpty) return true;

    final titulo = _normalizarTexto(oferta['titulo'] as String? ?? '');
    final descripcion = _normalizarTexto(
      oferta['descripcion'] as String? ?? '',
    );
    final salario = _normalizarTexto(oferta['salario'] as String? ?? '');
    final nombreEmpresa = _normalizarTexto(empresa?['nombre'] as String? ?? '');
    final ubicacion = _normalizarTexto(ubicacionEmpresa);
    final modalidad = _normalizarTexto(
      etiquetaModalidad(oferta['modalidad'] as String? ?? ''),
    );
    final requisitos = oferta['requisitos'] as List? ?? const [];
    final habilidades = requisitos
        .whereType<Map<String, dynamic>>()
        .map(
          (requisito) => _normalizarTexto(
            (requisito['habilidad'] as Map<String, dynamic>?)?['nombre']
                    as String? ??
                '',
          ),
        )
        .toList();

    // Cada palabra buscada debe aparecer en alguno de los campos de la oferta
    // (permite búsquedas combinadas como "react madrid" o "python remoto").
    for (final termino in terminosBusqueda) {
      final coincide =
          titulo.contains(termino) ||
          descripcion.contains(termino) ||
          salario.contains(termino) ||
          nombreEmpresa.contains(termino) ||
          ubicacion.contains(termino) ||
          modalidad.contains(termino) ||
          habilidades.any((habilidad) => habilidad.contains(termino));
      if (!coincide) return false;
    }
    return true;
  }

  List<String> get _terminosBusqueda => _normalizarTexto(_busqueda)
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  /// Filtra en el cliente sobre la lista ya cargada.
  List<Map<String, dynamic>> _filtrar(List<Map<String, dynamic>> ofertas) {
    final ahora = DateTime.now();
    final terminos = _terminosBusqueda;
    return ofertas
        .where(
          (oferta) => _cumpleFiltros(
            oferta,
            ahora: ahora,
            terminosBusqueda: terminos,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _futuroOfertas,
          builder: (context, snapshot) => RefreshIndicator(
            onRefresh: _recargarOfertas,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                const ScreenHeader(
                  title: 'Ofertas',
                  subtitle: 'Ordenadas por lo bien que encajan con tu CV',
                ),
                const SizedBox(height: AppSpacing.gap),
                SearchField(
                  controller: _busquedaCtrl,
                  label: 'Buscar ofertas',
                  hint: 'Puesto, empresa, ciudad o tecnología',
                  onChanged: (valor) => setState(() => _busqueda = valor),
                ),
                const SizedBox(height: AppSpacing.gap),
                _filtrosModalidad(snapshot.data),
                const SizedBox(height: AppSpacing.group),
                _filtrosAvanzados(snapshot.data),
                const SizedBox(height: AppSpacing.gap),
                _contenido(snapshot),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filtrosModalidad(List<Map<String, dynamic>>? ofertas) {
    final ahora = DateTime.now();
    final terminos = _terminosBusqueda;
    final baseSinModalidad = ofertas
        ?.where(
          (o) => _cumpleFiltros(
            o,
            ahora: ahora,
            terminosBusqueda: terminos,
            ignorarModalidad: true,
          ),
        )
        .toList();

    return Wrap(
      spacing: AppSpacing.group,
      runSpacing: AppSpacing.group,
      children: [
        for (final (etiqueta, valor) in _opcionesModalidad)
          FilterChipButton(
            label: etiqueta,
            selected: _modalidadFiltro == valor,
            count: baseSinModalidad == null
                ? null
                : valor == null
                ? baseSinModalidad.length
                : baseSinModalidad.where((o) => o['modalidad'] == valor).length,
            onTap: () => setState(() => _modalidadFiltro = valor),
          ),
      ],
    );
  }

  Widget _filtrosAvanzados(List<Map<String, dynamic>>? ofertas) {
    final etiquetaUbicacion = _ubicacionFiltro == null
        ? 'Ubicación'
        : 'Ubicación: $_ubicacionFiltro';

    final etiquetaFecha = switch (_diasPublicacionFiltro) {
      1 => 'Fecha: Últimas 24 h',
      7 => 'Fecha: Últimos 7 días',
      15 => 'Fecha: Últimos 15 días',
      30 => 'Fecha: Últimos 30 días',
      _ => 'Fecha de publicación',
    };

    final etiquetaSalario = _salarioMinimoFiltro == null
        ? 'Salario mínimo'
        : 'Salario ≥ ${_formatearEuros(_salarioMinimoFiltro!)}';

    return Wrap(
      spacing: AppSpacing.group,
      runSpacing: AppSpacing.group,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChipButton(
          label: etiquetaUbicacion,
          selected: _ubicacionFiltro != null,
          onTap: () => _elegirUbicacion(ofertas ?? const []),
        ),
        FilterChipButton(
          label: etiquetaFecha,
          selected: _diasPublicacionFiltro != null,
          onTap: () => _elegirFechaPublicacion(ofertas ?? const []),
        ),
        FilterChipButton(
          label: etiquetaSalario,
          selected: _salarioMinimoFiltro != null,
          onTap: () => _elegirSalarioMinimo(ofertas ?? const []),
        ),
        if (_hayFiltrosActivos)
          LinkAction(
            label: 'Limpiar filtros',
            onTap: _limpiarTodosLosFiltros,
          ),
      ],
    );
  }

  Future<void> _elegirUbicacion(List<Map<String, dynamic>> ofertas) async {
    final ahora = DateTime.now();
    final terminos = _terminosBusqueda;
    final base = ofertas.where(
      (o) => _cumpleFiltros(
        o,
        ahora: ahora,
        terminosBusqueda: terminos,
        ignorarUbicacion: true,
      ),
    );

    final conteoPorCiudad = <String, int>{};
    for (final oferta in base) {
      final empresa = oferta['empresa'] as Map<String, dynamic>?;
      final ciudad = (empresa?['ubicacion'] as String?)?.trim() ?? '';
      if (ciudad.isNotEmpty) {
        conteoPorCiudad[ciudad] = (conteoPorCiudad[ciudad] ?? 0) + 1;
      }
    }
    // Aseguramos que todas las ciudades existentes en el catálogo aparezcan
    // aunque con los demás filtros activos tengan 0 resultados.
    for (final oferta in ofertas) {
      final empresa = oferta['empresa'] as Map<String, dynamic>?;
      final ciudad = (empresa?['ubicacion'] as String?)?.trim() ?? '';
      if (ciudad.isNotEmpty) {
        conteoPorCiudad.putIfAbsent(ciudad, () => 0);
      }
    }

    final totalBase = base.length;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => _HojaFiltroUbicacion(
        conteoPorCiudad: conteoPorCiudad,
        totalOfertas: totalBase,
        seleccionada: _ubicacionFiltro,
        onSeleccionar: (ciudad) {
          setState(() => _ubicacionFiltro = ciudad);
          Navigator.of(sheetCtx).pop();
        },
      ),
    );
  }

  Future<void> _elegirFechaPublicacion(
    List<Map<String, dynamic>> ofertas,
  ) async {
    final ahora = DateTime.now();
    final terminos = _terminosBusqueda;
    final base = ofertas
        .where(
          (o) => _cumpleFiltros(
            o,
            ahora: ahora,
            terminosBusqueda: terminos,
            ignorarFecha: true,
          ),
        )
        .toList();

    int contarEnDias(int? dias) {
      if (dias == null) return base.length;
      final limite = ahora.subtract(Duration(days: dias));
      return base.where((o) {
        final f = DateTime.tryParse(o['fechaPublicacion'] as String? ?? '');
        return f != null && !f.isBefore(limite);
      }).length;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Fecha de publicación', style: AppText.h2),
              const SizedBox(height: AppSpacing.gap),
              PanelList(
                children: [
                  for (final (etiqueta, dias) in _opcionesFecha)
                    ListRow(
                      title: etiqueta,
                      trailing: _diasPublicacionFiltro == dias
                          ? const StatusTag(
                              label: 'Activo',
                              variant: StatusVariant.success,
                            )
                          : Text(
                              '${contarEnDias(dias)}',
                              style: AppText.numInline,
                            ),
                      onTap: () {
                        setState(() => _diasPublicacionFiltro = dias);
                        Navigator.of(sheetCtx).pop();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _elegirSalarioMinimo(List<Map<String, dynamic>> ofertas) async {
    final ahora = DateTime.now();
    final terminos = _terminosBusqueda;
    final base = ofertas
        .where(
          (o) => _cumpleFiltros(
            o,
            ahora: ahora,
            terminosBusqueda: terminos,
            ignorarSalario: true,
          ),
        )
        .toList();

    int contarDesdeSalario(int? minEuros) {
      if (minEuros == null) return base.length;
      return base.where((o) {
        final s = extraerSalarioOferta(o['salario'] as String?);
        return s != null && s >= minEuros;
      }).length;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => _HojaFiltroSalario(
        salarioInicial: _salarioMinimoFiltro,
        opciones: _opcionesSalarioMinimo,
        contarDesdeSalario: contarDesdeSalario,
        onAplicar: (nuevoSalario) {
          setState(() => _salarioMinimoFiltro = nuevoSalario);
          Navigator.of(sheetCtx).pop();
        },
      ),
    );
  }

  Widget _contenido(AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
    if (snapshot.hasError) {
      return const _PanelMensaje(
        'No se pudieron cargar las ofertas. Inténtalo de nuevo más tarde.',
      );
    }

    // El match depende de las habilidades del CV: se espera a tenerlas para
    // no pintar porcentajes provisionales.
    if (snapshot.connectionState == ConnectionState.waiting || !_cvCargado) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: AppSpinner(size: 24)),
      );
    }

    final todas = snapshot.data ?? [];
    if (todas.isEmpty) {
      return const _PanelMensaje('No hay ofertas disponibles.');
    }

    final ofertas = _filtrar(todas);
    if (ofertas.isEmpty) {
      // Hay ofertas, pero ninguna encaja con el filtro: es un caso distinto
      // a "no hay ofertas" y merece su propio mensaje.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelMensaje('Ninguna oferta coincide con la búsqueda.'),
          if (_hayFiltrosActivos) ...[
            const SizedBox(height: AppSpacing.group),
            SecondaryButton(
              label: 'Restablecer todos los filtros',
              onPressed: _limpiarTodosLosFiltros,
            ),
          ],
        ],
      );
    }

    // Una sola lista dentro de un solo panel, de mayor a menor match.
    final conMatch = [
      for (final oferta in ofertas)
        (oferta, MatchOferta.calcular(oferta, _habilidadesCv)),
    ]..sort((a, b) => b.$2.score.compareTo(a.$2.score));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hayFiltrosActivos) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.group),
            child: Text(
              'Mostrando ${ofertas.length} de ${todas.length} ofertas',
              style: AppText.meta,
            ),
          ),
        ],
        PanelList(
          children: [
            for (final (oferta, match) in conMatch) _filaOferta(oferta, match),
          ],
        ),
      ],
    );
  }

  Widget _filaOferta(Map<String, dynamic> oferta, MatchOferta match) {
    // empresa?['ubicacion'] y no oferta['ubicacion']: el modelo Oferta del
    // backend no tiene campo de ubicación propio, la ubicación es de la
    // empresa (ver prisma/schema.prisma, modelo Empresa).
    final empresa = oferta['empresa'] as Map<String, dynamic>?;
    final titulo = oferta['titulo'] as String? ?? 'Sin título';
    final nombreEmpresa = empresa?['nombre'] as String? ?? 'Empresa';
    final ubicacion = (empresa?['ubicacion'] as String?)?.trim();
    final modalidad = oferta['modalidad'] as String?;
    final salario = (oferta['salario'] as String?)?.trim();
    final fechaRelativa = _textoFechaRelativa(
      oferta['fechaPublicacion'] as String?,
    );
    final lineaEmpresa = [
      nombreEmpresa,
      if (ubicacion != null && ubicacion.isNotEmpty) ubicacion,
      if (modalidad != null) etiquetaModalidad(modalidad),
      if (salario != null && salario.isNotEmpty) salario,
      ?fechaRelativa,
    ].join(' · ');

    return ListRow(
      title: titulo,
      lines: [
        lineaEmpresa,
        _resumen(match),
      ],
      trailing: MatchIndicator(match: match.score),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                OfertaDetalle(oferta: oferta, habilidadesCv: _habilidadesCv),
          ),
        );
      },
    );
  }

  /// Obligatorias cubiertas, encaje con la descripción y primer requisito que falta.
  String _resumen(MatchOferta match) {
    final partes = [
      if (match.obligatoriasTotal > 0)
        '${match.obligatoriasCubiertas} de ${match.obligatoriasTotal} obligatorias',
      if (match.descripcionTotal > 0)
        '${match.porcentajeDescripcion} % descripción',
      if (match.faltantes.isNotEmpty) 'Falta ${match.faltantes.first.nombre}',
    ];
    return partes.isEmpty ? 'Sin requisitos definidos' : partes.join(' · ');
  }
}

class _HojaFiltroUbicacion extends StatefulWidget {
  const _HojaFiltroUbicacion({
    required this.conteoPorCiudad,
    required this.totalOfertas,
    required this.seleccionada,
    required this.onSeleccionar,
  });

  final Map<String, int> conteoPorCiudad;
  final int totalOfertas;
  final String? seleccionada;
  final ValueChanged<String?> onSeleccionar;

  @override
  State<_HojaFiltroUbicacion> createState() => _HojaFiltroUbicacionState();
}

class _HojaFiltroUbicacionState extends State<_HojaFiltroUbicacion> {
  final _ctrlCiudad = TextEditingController();
  String _filtroCiudad = '';

  @override
  void dispose() {
    _ctrlCiudad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ciudades = widget.conteoPorCiudad.keys.toList()..sort();
    final buscado = _OfertasState._normalizarTexto(_filtroCiudad);
    final filtradas = buscado.isEmpty
        ? ciudades
        : ciudades
              .where(
                (c) => _OfertasState._normalizarTexto(c).contains(buscado),
              )
              .toList();

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          children: [
            Text('Filtrar por ubicación', style: AppText.h2),
            const SizedBox(height: AppSpacing.group),
            SearchField(
              controller: _ctrlCiudad,
              label: 'Buscar ciudad',
              hint: 'Ej. Madrid, Barcelona, Málaga…',
              onChanged: (v) => setState(() => _filtroCiudad = v),
            ),
            const SizedBox(height: AppSpacing.gap),
            if (filtradas.isEmpty)
              const _PanelMensaje('Ninguna ciudad coincide con la búsqueda.')
            else
              PanelList(
                children: [
                  ListRow(
                    title: 'Todas las ubicaciones',
                    trailing: widget.seleccionada == null
                        ? const StatusTag(
                            label: 'Activo',
                            variant: StatusVariant.success,
                          )
                        : Text(
                            '${widget.totalOfertas}',
                            style: AppText.numInline,
                          ),
                    onTap: () => widget.onSeleccionar(null),
                  ),
                  for (final ciudad in filtradas)
                    ListRow(
                      title: ciudad,
                      trailing: widget.seleccionada == ciudad
                          ? const StatusTag(
                              label: 'Activo',
                              variant: StatusVariant.success,
                            )
                          : Text(
                              '${widget.conteoPorCiudad[ciudad] ?? 0}',
                              style: AppText.numInline,
                            ),
                      onTap: () => widget.onSeleccionar(ciudad),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _HojaFiltroSalario extends StatefulWidget {
  const _HojaFiltroSalario({
    required this.salarioInicial,
    required this.opciones,
    required this.contarDesdeSalario,
    required this.onAplicar,
  });

  final int? salarioInicial;
  final List<int?> opciones;
  final int Function(int?) contarDesdeSalario;
  final ValueChanged<int?> onAplicar;

  @override
  State<_HojaFiltroSalario> createState() => _HojaFiltroSalarioState();
}

class _HojaFiltroSalarioState extends State<_HojaFiltroSalario> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.salarioInicial?.toString() ?? '',
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Salario mínimo esperado', style: AppText.h2),
              const SizedBox(height: AppSpacing.micro),
              Text(
                'Muestra las ofertas cuyo salario base partirá como mínimo de esta cantidad bruta anual.',
                style: AppText.mutedBody,
              ),
              const SizedBox(height: AppSpacing.gap),
              Wrap(
                spacing: AppSpacing.group,
                runSpacing: AppSpacing.group,
                children: [
                  for (final opcion in widget.opciones)
                    FilterChipButton(
                      label: opcion == null
                          ? 'Sin mínimo'
                          : '≥ ${_OfertasState._formatearEuros(opcion)}',
                      count: widget.contarDesdeSalario(opcion),
                      selected: widget.salarioInicial == opcion,
                      onTap: () => widget.onAplicar(opcion),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.gap),
              AppTextField(
                controller: _ctrl,
                label: 'O indica un importe exacto (€ brutos/año)',
                hint: 'Ej. 32000',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.gap),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Quitar mínimo',
                      onPressed: () => widget.onAplicar(null),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.group),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Aplicar',
                      onPressed: () {
                        final limpio = _ctrl.text
                            .trim()
                            .replaceAll('.', '')
                            .replaceAll(',', '');
                        final valor = int.tryParse(limpio);
                        widget.onAplicar(
                          (valor != null && valor > 0) ? valor : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vacío y error: mantienen el marco del panel y una frase, sin ilustración.
class _PanelMensaje extends StatelessWidget {
  const _PanelMensaje(this.mensaje);

  final String mensaje;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Panel(child: Text(mensaje, style: AppText.mutedBody)),
  );
}
