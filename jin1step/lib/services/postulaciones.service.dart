import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/api_client.dart';

class PostulacionesService {
  Future<List<Map<String, dynamic>>> listarDeOferta(String ofertaId) async {
    try {
      final response = await ApiClient.dio.get('/postulaciones/oferta/$ofertaId');
      return (response.data as List).cast<Map<String, dynamic>>();
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<Map<String, dynamic>> obtenerCv(String postulacionId) async {
    try {
      final response = await ApiClient.dio.get(
        '/postulaciones/$postulacionId/cv',
      );
      return response.data as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<Uint8List> descargarCv(String postulacionId) async {
    try {
      final response = await ApiClient.dio.get<List<int>>(
        '/postulaciones/$postulacionId/cv/archivo',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const <int>[]);
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<Map<String, dynamic>> actualizarEstado(
    String postulacionId,
    String estado,
  ) async {
    try {
      final response = await ApiClient.dio.patch(
        '/postulaciones/$postulacionId',
        data: {'estado': estado},
      );
      return response.data as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }
}
