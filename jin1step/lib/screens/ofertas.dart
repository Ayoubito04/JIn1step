import 'package:flutter/material.dart';

import '../services/candidato.service.dart';
import '../services/ofertas.services.dart';
import 'oferta_detalle.dart';

class Ofertas extends StatefulWidget {
  const Ofertas({super.key, this.ofertaService});

  final OfertasService? ofertaService;

  @override
  State<Ofertas> createState() => _OfertasState();
}

class _OfertasState extends State<Ofertas> {
  late final OfertasService _ofertasService =
      widget.ofertaService ?? OfertasService();

  late final Future<List<Map<String, dynamic>>> _futuroOfertas = _ofertasService
      .getAllOfertas();
  final _candidatoService = CandidatoService();
  Set<String> _habilidadesCv = {};
  bool _cvCargado = false;

  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';
  // null = "Todas". Los otros valores son exactamente los del enum
  // Modalidad del backend, así el filtro nunca desincroniza con la API.
  String? _modalidadFiltro;

  @override
  void initState() {
    super.initState();
    _cargarHabilidadesCv();
  }

  Future<void> _cargarHabilidadesCv() async {
    try {
      final cvs = await _candidatoService.listarCvs();
      if (cvs.isEmpty) {
        if (mounted) setState(() => _cvCargado = true);
        return;
      }
      final habilidades = await _candidatoService.listarHabilidadesCv(
        cvs.first['id'] as String,
      );
      final nombres = habilidades
          .map(
            (item) => (item['habilidad'] as Map<String, dynamic>?)?['nombre'],
          )
          .whereType<String>()
          .map(_normalizarHabilidad)
          .toSet();
      if (mounted)
        setState(() {
          _habilidadesCv = nombres;
          _cvCargado = true;
        });
    } catch (_) {
      if (mounted) setState(() => _cvCargado = true);
    }
  }

  String _normalizarHabilidad(String nombre) =>
      nombre.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  ({
    int score,
    int obligatoriasCubiertas,
    int obligatoriasTotal,
    int deseablesCubiertas,
    int deseablesTotal,
  })
  _calcularMatch(Map<String, dynamic> oferta) {
    final requisitos = (oferta['requisitos'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final obligatorias = requisitos.where((r) => r['obligatorio'] != false);
    final deseables = requisitos.where((r) => r['obligatorio'] == false);
    int cubiertas(Iterable<Map<String, dynamic>> lista) => lista.where((r) {
      final nombre =
          (r['habilidad'] as Map<String, dynamic>?)?['nombre'] as String?;
      return nombre != null &&
          _habilidadesCv.contains(_normalizarHabilidad(nombre));
    }).length;
    final totalO = obligatorias.length, totalD = deseables.length;
    final cubiertasO = cubiertas(obligatorias),
        cubiertasD = cubiertas(deseables);
    final ratioO = totalO == 0 ? 1.0 : cubiertasO / totalO;
    final ratioD = totalD == 0 ? 1.0 : cubiertasD / totalD;
    return (
      score: totalO + totalD == 0 ? 0 : (ratioO * 70 + ratioD * 30).round(),
      obligatoriasCubiertas: cubiertasO,
      obligatoriasTotal: totalO,
      deseablesCubiertas: cubiertasD,
      deseablesTotal: totalD,
    );
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  /// Filtra en el cliente sobre la lista ya cargada: no hace falta pedirle
  /// al backend un endpoint de búsqueda para esto, con 100 ofertas sobra con
  /// filtrar en memoria.
  List<Map<String, dynamic>> _filtrar(List<Map<String, dynamic>> ofertas) {
    final texto = _busqueda.trim().toLowerCase();

    return ofertas.where((oferta) {
      if (_modalidadFiltro != null && oferta['modalidad'] != _modalidadFiltro) {
        return false;
      }

      final empresa = oferta['empresa'] as Map<String, dynamic>?;
      if (texto.isEmpty) return true;

      final titulo = (oferta['titulo'] as String? ?? '').toLowerCase();
      final nombreEmpresa = (empresa?['nombre'] as String? ?? '').toLowerCase();
      final ubicacion = (empresa?['ubicacion'] as String? ?? '').toLowerCase();
      final requisitos = oferta['requisitos'] as List? ?? const [];
      final habilidades = requisitos.whereType<Map<String, dynamic>>().map(
        (requisito) =>
            ((requisito['habilidad'] as Map<String, dynamic>?)?['nombre']
                        as String? ??
                    '')
                .toLowerCase(),
      );

      return titulo.contains(texto) ||
          nombreEmpresa.contains(texto) ||
          ubicacion.contains(texto) ||
          habilidades.any((habilidad) => habilidad.contains(texto));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Ofertas para ti',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        toolbarHeight: 68,
      ),
      body: Column(
        children: [
          _buscador(theme),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _futuroOfertas,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _estadoVacio(
                    theme,
                    icono: Icons.error_outline,
                    color: theme.colorScheme.error,
                    titulo: 'No se pudieron cargar las ofertas',
                    subtitulo: 'Inténtalo de nuevo más tarde.',
                  );
                }

                final todas = snapshot.data ?? [];
                final ofertas = _filtrar(todas);

                if (todas.isEmpty) {
                  return _estadoVacio(
                    theme,
                    icono: Icons.work_outline,
                    color: theme.colorScheme.primary,
                    titulo: 'No hay ofertas disponibles',
                  );
                }

                if (ofertas.isEmpty) {
                  // Hay ofertas, pero ninguna encaja con el filtro: es un
                  // caso distinto a "no hay ofertas" y merece su propio
                  // mensaje, o parecería que la app no tiene datos.
                  return _estadoVacio(
                    theme,
                    icono: Icons.search_off,
                    color: theme.colorScheme.onSurfaceVariant,
                    titulo: 'Ninguna oferta coincide con la búsqueda',
                  );
                }

                return Column(
                  children: [
                    _filtrosModalidad(theme),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: ofertas.length,
                        itemBuilder: (context, index) =>
                            _tarjetaOferta(theme, ofertas[index]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buscador(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: TextField(
        controller: _busquedaCtrl,
        onChanged: (valor) => setState(() => _busqueda = valor),
        decoration: InputDecoration(
          hintText: 'Buscar por puesto o habilidad',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _busqueda.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _busquedaCtrl.clear();
                    setState(() => _busqueda = '');
                  },
                ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE7E3F2)),
          ),
        ),
      ),
    );
  }

  Widget _filtrosModalidad(ThemeData theme) {
    // (etiqueta visible, valor real del backend o null para "Todas").
    const opciones = <(String, String?)>[
      ('Todas', null),
      ('Remoto', 'REMOTO'),
      ('Híbrido', 'HIBRIDO'),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: opciones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (etiqueta, valor) = opciones[i];
          final seleccionado = _modalidadFiltro == valor;

          return ChoiceChip(
            label: Text(etiqueta),
            selected: seleccionado,
            visualDensity: VisualDensity.compact,
            labelStyle: TextStyle(
              fontSize: 11,
              color: seleccionado ? Colors.white : theme.colorScheme.onSurface,
            ),
            onSelected: (_) => setState(() => _modalidadFiltro = valor),
          );
        },
      ),
    );
  }

  Widget _estadoVacio(
    ThemeData theme, {
    required IconData icono,
    required Color color,
    required String titulo,
    String? subtitulo,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: color),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitulo,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tarjetaOferta(ThemeData theme, Map<String, dynamic> oferta) {
    // empresa?['ubicacion'] y no oferta['ubicacion']: el modelo Oferta del
    // backend no tiene campo de ubicación propio, la ubicación es de la
    // empresa (ver prisma/schema.prisma, modelo Empresa).
    final empresa = oferta['empresa'] as Map<String, dynamic>?;
    final titulo = oferta['titulo'] as String? ?? 'Sin título';
    final nombreEmpresa = empresa?['nombre'] as String? ?? 'Empresa';
    final modalidad = oferta['modalidad'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OfertaDetalle(oferta: oferta),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EFF8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.business_center_outlined,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$nombreEmpresa${modalidad == null ? '' : ' · ${_etiquetaModalidad(modalidad)}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _cvCargado && _habilidadesCv.isNotEmpty
                        ? '${_calcularMatch(oferta).score}%'
                        : '—',
                    style: TextStyle(
                      color: _colorMatch(_calcularMatch(oferta).score),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: _chipsRequisitos(theme, oferta),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _chipsRequisitos(ThemeData theme, Map<String, dynamic> oferta) {
    final match = _calcularMatch(oferta);
    final requisitos = (oferta['requisitos'] as List? ?? const [])
        .whereType<Map<String, dynamic>>();
    final faltante = requisitos.cast<Map<String, dynamic>>().where((r) {
      final nombre =
          (r['habilidad'] as Map<String, dynamic>?)?['nombre'] as String?;
      return nombre != null &&
          !_habilidadesCv.contains(_normalizarHabilidad(nombre));
    }).firstOrNull;
    final primero = faltante == null
        ? '${match.obligatoriasCubiertas}/${match.obligatoriasTotal} obligatorias'
        : 'Falta: ${(faltante['habilidad'] as Map<String, dynamic>?)?['nombre'] ?? 'habilidad'}';
    return [
      _chip(primero, theme),
      _chip(
        '${match.deseablesCubiertas}/${match.deseablesTotal} deseables',
        theme,
      ),
    ];
  }

  Widget _chip(String texto, ThemeData theme) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFD7D0F4)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      texto,
      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface),
    ),
  );

  Color _colorMatch(int score) => score >= 80
      ? const Color(0xFF07884D)
      : score >= 60
      ? const Color(0xFFAA7200)
      : const Color(0xFF77738D);

  String _etiquetaModalidad(String valor) => switch (valor) {
    'REMOTO' => 'Remoto',
    'HIBRIDO' => 'Híbrido',
    'PRESENCIAL' => 'Presencial',
    _ => valor,
  };
}
