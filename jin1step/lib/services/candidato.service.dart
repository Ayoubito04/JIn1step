import 'package:dio/dio.dart';

import '../core/api_client.dart';

class CandidatoService {
  Future<List<Map<String, dynamic>>> listarCvs() async {
    try {
      final respuesta = await ApiClient.dio.get('/cv');
      return (respuesta.data as List).cast<Map<String, dynamic>>();
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<Map<String, dynamic>> subirCv({
    required String titulo,
    required String nombreArchivo,
    required List<int> bytes,
  }) async {
    try {
      final datos = FormData.fromMap({
        'titulo': titulo,
        'archivo': MultipartFile.fromBytes(
          bytes,
          filename: nombreArchivo,
          contentType: DioMediaType.parse('application/pdf'),
        ),
      });
      final respuesta = await ApiClient.dio.post('/cv', data: datos);
      return respuesta.data as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<Map<String, dynamic>> postular({
    required String ofertaId,
    required String cvId,
  }) async {
    try {
      final respuesta = await ApiClient.dio.post(
        '/postulaciones',
        data: {'ofertaId': ofertaId, 'cvId': cvId},
      );
      return respuesta.data as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listarPostulaciones() async {
    try {
      final respuesta = await ApiClient.dio.get('/postulaciones/mias');
      return (respuesta.data as List).cast<Map<String, dynamic>>();
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<Map<String, dynamic>> obtenerPreferenciasAutopilot() async {
    try {
      final respuesta = await ApiClient.dio.get('/preferencias-autopilot');
      return respuesta.data as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<Map<String, dynamic>> guardarPreferenciasAutopilot(
    Map<String, dynamic> preferencias,
  ) async {
    try {
      final respuesta = await ApiClient.dio.patch(
        '/preferencias-autopilot',
        data: preferencias,
      );
      return respuesta.data as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<Map<String, dynamic>?> obtenerSuscripcionActiva() async {
    try {
      final respuesta = await ApiClient.dio.get('/suscripciones/mia');
      return respuesta.data as Map<String, dynamic>?;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<Map<String, dynamic>> ejecutarAutopilot() async {
    try {
      final respuesta = await ApiClient.dio.post(
        '/postulaciones-autopilot/ejecutar',
      );
      return respuesta.data as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<String> iniciarSuscripcion() async {
    try {
      final respuesta = await ApiClient.dio.post(
        '/suscripciones',
        data: {'tipoPlan': 'MENSUAL', 'proveedorPago': 'STRIPE'},
      );
      return (respuesta.data as Map<String, dynamic>)['urlPago'] as String;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }
}
