import 'package:flutter/material.dart';

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

  late final Future<List<Map<String, dynamic>>> _futuroOfertas =
      _ofertasService.getAllOfertas();

  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';
  String? _ubicacionFiltro;

  // null = "Todas". Los otros tres son exactamente los valores del enum
  // Modalidad del backend, así el filtro nunca desincroniza con la API.
  String? _modalidadFiltro;

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
      final ubicacion = (empresa?['ubicacion'] as String? ?? '').trim();
      if (_ubicacionFiltro != null && ubicacion != _ubicacionFiltro) {
        return false;
      }

      if (texto.isEmpty) return true;

      final titulo = (oferta['titulo'] as String? ?? '').toLowerCase();
      final nombreEmpresa = (empresa?['nombre'] as String? ?? '').toLowerCase();
      final requisitos = oferta['requisitos'] as List? ?? const [];
      final habilidades = requisitos
          .whereType<Map<String, dynamic>>()
          .map((requisito) =>
              ((requisito['habilidad'] as Map<String, dynamic>?)?['nombre']
                      as String? ??
                  '')
              .toLowerCase());

      return titulo.contains(texto) ||
          nombreEmpresa.contains(texto) ||
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
          'Ofertas de empleo',
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

                final ubicaciones = todas
                    .map((oferta) =>
                        (oferta['empresa'] as Map<String, dynamic>?)?['ubicacion']
                            as String?)
                    .whereType<String>()
                    .map((ubicacion) => ubicacion.trim())
                    .where((ubicacion) => ubicacion.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();

                return Column(
                  children: [
                    _filtrosModalidad(theme),
                    const SizedBox(height: 8),
                    _filtroUbicacion(theme, ubicaciones),
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
          hintText: 'Buscar por puesto, empresa o habilidad',
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
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _filtroUbicacion(ThemeData theme, List<String> ubicaciones) {
    final valor = ubicaciones.contains(_ubicacionFiltro) ? _ubicacionFiltro : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: DropdownButtonFormField<String?>(
        initialValue: valor,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Ubicación de la empresa',
          prefixIcon: const Icon(Icons.location_on_outlined),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Todas las ubicaciones')),
          for (final ubicacion in ubicaciones)
            DropdownMenuItem<String?>(value: ubicacion, child: Text(ubicacion)),
        ],
        onChanged: (value) => setState(() => _ubicacionFiltro = value),
      ),
    );
  }

  Widget _filtrosModalidad(ThemeData theme) {
    // (etiqueta visible, valor real del backend o null para "Todas").
    const opciones = <(String, String?)>[
      ('Todas', null),
      ('Remoto', 'REMOTO'),
      ('Híbrido', 'HIBRIDO'),
      ('Presencial', 'PRESENCIAL'),
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
            Text(titulo, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (subtitulo != null) ...[
              const SizedBox(height: 8),
              Text(subtitulo, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
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
    final ubicacion = empresa?['ubicacion'] as String?;
    final modalidad = oferta['modalidad'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => OfertaDetalle(oferta: oferta)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.business_outlined,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nombreEmpresa,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.outline),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                titulo,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (ubicacion != null)
                    Chip(
                      avatar: const Icon(Icons.location_on_outlined, size: 18),
                      label: Text(ubicacion),
                    ),
                  if (modalidad != null)
                    Chip(
                      avatar: const Icon(Icons.work_outline, size: 18),
                      label: Text(_etiquetaModalidad(modalidad)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _etiquetaModalidad(String valor) => switch (valor) {
        'REMOTO' => 'Remoto',
        'HIBRIDO' => 'Híbrido',
        'PRESENCIAL' => 'Presencial',
        _ => valor,
      };
}
