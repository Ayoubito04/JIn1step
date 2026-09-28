// Formulario para que un reclutador publique una oferta nueva.
//
// POST /ofertas exige empresaId, titulo, descripcion y modalidad, ni un
// campo más: el schema del backend es .strict() y rechaza cualquier clave
// que sobre (ver ofertas.schema.ts).
import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../services/empresas.services.dart';
import '../services/ofertas.services.dart';

class PublicarOferta extends StatefulWidget {
  const PublicarOferta({super.key, this.ofertasService, this.empresasService});

  /// Opcionales para poder inyectar servicios falsos en los tests, mismo
  /// patrón que el resto de pantallas (LoginScreen, Ofertas...).
  final OfertasService? ofertasService;
  final EmpresasService? empresasService;

  @override
  State<PublicarOferta> createState() => _PublicarOfertaState();
}

class _PublicarOfertaState extends State<PublicarOferta> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  late final OfertasService _ofertasService =
      widget.ofertasService ?? OfertasService();
  late final EmpresasService _empresasService =
      widget.empresasService ?? EmpresasService();
  late final Future<List<Map<String, dynamic>>> _futuroEmpresas =
      _empresasService.listarEmpresas();

  String? _empresaId;
  // Los tres valores exactos del enum Modalidad del backend.
  String _modalidad = 'REMOTO';
  bool _publicando = false;
  String? _error;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _publicar() async {
    if (!_formKey.currentState!.validate()) return;

    // _empresaId es obligatorio pero no lo valida un TextFormField (es un
    // Dropdown): se comprueba a mano antes de mandar la petición.
    if (_empresaId == null) {
      setState(() => _error = 'Elige una empresa');
      return;
    }

    setState(() {
      _publicando = true;
      _error = null;
    });

    try {
      // "url" NO se manda: Oferta no tiene ese campo en ningún sitio (ni en
      // el modelo de Prisma ni en el schema del backend), y crearOfertaSchema
      // es .strict(), así que mandarlo daría 400 aunque compilase.
      // El campo de texto de la URL sigue en el formulario (más abajo) sin
      // usarse todavía: hay que decidir qué hacer con él, ver el aviso.
      await _ofertasService.crearOferta(
        empresaId: _empresaId!,
        titulo: _tituloCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        modalidad: _modalidad,
      );

      if (!mounted) return;
      // true le dice a quien abrió este formulario (Navigator.push) que se
      // publicó una oferta de verdad, por si quiere refrescar su lista.
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _publicando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publicar oferta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _selectorEmpresa(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tituloCtrl,
                  enabled: !_publicando,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: (valor) {
                    final texto = valor?.trim() ?? '';
                    if (texto.isEmpty) return 'El título es obligatorio';
                    if (texto.length > 100) return 'Máximo 100 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _urlCtrl,
                  enabled: !_publicando,
                  decoration: const InputDecoration(labelText: 'URL'),
                  validator: (valor) {
                    final texto = valor?.trim() ?? '';

                    if (texto.length > 200) return 'Máximo 200 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descripcionCtrl,
                  enabled: !_publicando,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    alignLabelWithHint: true,
                  ),
                  validator: (valor) {
                    final texto = valor?.trim() ?? '';
                    if (texto.isEmpty) return 'La descripción es obligatoria';
                    if (texto.length > 1000) return 'Máximo 1000 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _selectorModalidad(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _publicando ? null : _publicar,
                  child: _publicando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Publicar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectorEmpresa() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futuroEmpresas,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (snapshot.hasError) {
          return Text(
            'No se pudieron cargar las empresas',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }

        final empresas = snapshot.data ?? [];

        return DropdownButtonFormField<String>(
          initialValue: _empresaId,
          decoration: const InputDecoration(labelText: 'Empresa'),
          items: [
            for (final empresa in empresas)
              DropdownMenuItem(
                value: empresa['id'] as String,
                child: Text(empresa['nombre'] as String? ?? 'Sin nombre'),
              ),
          ],
          onChanged: _publicando
              ? null
              : (valor) => setState(() {
                  _empresaId = valor;
                  _error = null;
                }),
        );
      },
    );
  }

  Widget _selectorModalidad() {
    const opciones = <(String, String)>[
      ('Remoto', 'REMOTO'),
      ('Híbrido', 'HIBRIDO'),
      ('Presencial', 'PRESENCIAL'),
    ];

    return SegmentedButton<String>(
      segments: [
        for (final (etiqueta, valor) in opciones)
          ButtonSegment(value: valor, label: Text(etiqueta)),
      ],
      selected: {_modalidad},
      onSelectionChanged: _publicando
          ? null
          : (seleccion) => setState(() => _modalidad = seleccion.first),
    );
  }
}
