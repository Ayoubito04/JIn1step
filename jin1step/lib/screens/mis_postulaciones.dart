import 'package:flutter/material.dart';

import '../services/candidato.service.dart';

class MisPostulacionesPage extends StatefulWidget {
  const MisPostulacionesPage({super.key});

  @override
  State<MisPostulacionesPage> createState() => _MisPostulacionesPageState();
}

class _MisPostulacionesPageState extends State<MisPostulacionesPage> {
  final _service = CandidatoService();
  String _filtro = 'Todas';
  late Future<List<Map<String, dynamic>>> _postulaciones = _service
      .listarPostulaciones();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis candidaturas')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _postulaciones,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => setState(
                        () => _postulaciones = _service.listarPostulaciones(),
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          final candidaturas = snapshot.data ?? [];
          if (candidaturas.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.send_outlined, size: 48, color: esquema.primary),
                    const SizedBox(height: 12),
                    Text(
                      'Todavía no tienes candidaturas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cuando te postules, podrás seguir aquí su estado y compatibilidad.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: esquema.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }
          final filtradas = candidaturas.where((item) {
            if (_filtro == 'Manuales') return item['postuladoPorIa'] != true;
            if (_filtro == 'Por IA') return item['postuladoPorIa'] == true;
            return true;
          }).toList();
          return Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 5,
                  ),
                  children: [
                    for (final filtro in ['Todas', 'Manuales', 'Por IA'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filtro),
                          selected: _filtro == filtro,
                          onSelected: (_) => setState(() => _filtro = filtro),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    final actualizadas = _service.listarPostulaciones();
                    setState(() => _postulaciones = actualizadas);
                    await actualizadas;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                    itemCount: filtradas.length,
                    itemBuilder: (context, index) {
                      final postulacion = filtradas[index];
                      final oferta =
                          postulacion['oferta'] as Map<String, dynamic>? ?? {};
                      final empresa =
                          oferta['empresa'] as Map<String, dynamic>? ?? {};
                      final score = (postulacion['matchScore'] as num?)
                          ?.round();
                      final porAutopilot =
                          postulacion['postuladoPorIa'] == true;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: esquema.primary.withValues(
                                        alpha: .1,
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Icon(
                                      Icons.work_outline,
                                      color: esquema.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          oferta['titulo'] as String? ??
                                              'Oferta',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          empresa['nombre'] as String? ??
                                              'Empresa',
                                          style: TextStyle(
                                            color: esquema.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (score != null)
                                    Text(
                                      '$score%',
                                      style: TextStyle(
                                        color: esquema.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _etiqueta(
                                    context,
                                    _estado(postulacion['estado'] as String?),
                                    Icons.flag_outlined,
                                  ),
                                  _etiqueta(
                                    context,
                                    porAutopilot ? 'Autopiloto' : 'Manual',
                                    porAutopilot
                                        ? Icons.auto_awesome
                                        : Icons.person_outline,
                                  ),
                                  if (postulacion['cv'] is Map<String, dynamic>)
                                    _etiqueta(
                                      context,
                                      (postulacion['cv']
                                                  as Map<
                                                    String,
                                                    dynamic
                                                  >)['titulo']
                                              as String? ??
                                          'CV',
                                      Icons.description_outlined,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _etiqueta(BuildContext context, String texto, IconData icono) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerHighest.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 15, color: esquema.primary),
          const SizedBox(width: 5),
          Text(
            texto,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _estado(String? estado) => switch (estado) {
    'PENDIENTE' => 'Pendiente de revisión',
    'ENVIADA' => 'Enviada automáticamente',
    'VISTA' => 'Vista por la empresa',
    'ENTREVISTA' => 'Entrevista',
    'RECHAZADA' => 'No seleccionada',
    _ => estado ?? 'Enviada',
  };
}
