import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/candidato.service.dart';
import '../services/ofertas.services.dart';
import '../widgets/design_system.dart';
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

  // (etiqueta visible, valor real del backend o null para "Todas").
  static const _opcionesModalidad = <(String, String?)>[
    ('Todas', null),
    ('Remoto', 'REMOTO'),
    ('Híbrido', 'HIBRIDO'),
    ('Presencial', 'PRESENCIAL'),
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
      final descripcion = (oferta['descripcion'] as String? ?? '').toLowerCase();
      final salario = (oferta['salario'] as String? ?? '').toLowerCase();
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
          descripcion.contains(texto) ||
          salario.contains(texto) ||
          nombreEmpresa.contains(texto) ||
          ubicacion.contains(texto) ||
          habilidades.any((habilidad) => habilidad.contains(texto));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _futuroOfertas,
          builder: (context, snapshot) => ListView(
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
                hint: 'Puesto, empresa o tecnología',
                onChanged: (valor) => setState(() => _busqueda = valor),
              ),
              const SizedBox(height: AppSpacing.gap),
              _filtrosModalidad(snapshot.data),
              const SizedBox(height: AppSpacing.gap),
              _contenido(snapshot),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filtrosModalidad(List<Map<String, dynamic>>? ofertas) => Wrap(
    spacing: AppSpacing.group,
    runSpacing: AppSpacing.group,
    children: [
      for (final (etiqueta, valor) in _opcionesModalidad)
        FilterChipButton(
          label: etiqueta,
          selected: _modalidadFiltro == valor,
          count: ofertas == null
              ? null
              : valor == null
              ? ofertas.length
              : ofertas.where((o) => o['modalidad'] == valor).length,
          onTap: () => setState(() => _modalidadFiltro = valor),
        ),
    ],
  );

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
      return const _PanelMensaje('Ninguna oferta coincide con la búsqueda.');
    }

    // Una sola lista dentro de un solo panel, de mayor a menor match.
    final conMatch = [
      for (final oferta in ofertas)
        (oferta, MatchOferta.calcular(oferta, _habilidadesCv)),
    ]..sort((a, b) => b.$2.score.compareTo(a.$2.score));

    return PanelList(
      children: [
        for (final (oferta, match) in conMatch) _filaOferta(oferta, match),
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
    final modalidad = oferta['modalidad'] as String?;
    final salario = (oferta['salario'] as String?)?.trim();
    final lineaEmpresa = [
      nombreEmpresa,
      if (modalidad != null) etiquetaModalidad(modalidad),
      if (salario != null && salario.isNotEmpty) salario,
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
