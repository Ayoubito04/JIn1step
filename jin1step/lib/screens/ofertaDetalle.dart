// Ficha de una oferta. Versión mínima: solo pinta lo que llega, sin llamadas
// propias a la API todavía.
//
// OJO de estilo: el archivo se llama ofertaDetalle.dart (camelCase), pero la
// convención de Dart para archivos es snake_case (oferta_detalle.dart). No lo
// he renombrado para no romper el import que ya tienes en ofertas.dart; si
// quieres corregirlo más adelante, hay que cambiar el nombre del archivo Y el
// import a la vez.
import 'package:flutter/material.dart';

class OfertaDetalle extends StatelessWidget {
  const OfertaDetalle({super.key, required this.oferta});

  final Map<String, dynamic> oferta;

  @override
  Widget build(BuildContext context) {
    // ['empresa']?['nombre'] con el operador ?. : la oferta puede llegar sin
    // empresa incluida según qué endpoint la trajo, y sin esto un valor nulo
    // reventaría con "NoSuchMethodError" al intentar leer 'nombre' de null.
    final empresa = oferta['empresa'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(title: Text(oferta['titulo'] as String? ?? 'Oferta')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            oferta['titulo'] as String? ?? '',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (empresa != null) ...[
            const SizedBox(height: 4),
            Text(
              empresa['nombre'] as String? ?? '',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          const SizedBox(height: 16),
          Text(oferta['descripcion'] as String? ?? 'Sin descripción'),
          // TODO: postularse (POST /postulaciones), ver requisitos
          // (GET /ofertas/:id/requisitos) y el match calculado
          // (POST /postulaciones/simular-match).
        ],
      ),
    );
  }
}
