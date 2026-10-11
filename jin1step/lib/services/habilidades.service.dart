import '../core/api_client.dart';

class HabilidadesService {
  Future<List<Map<String, dynamic>>> listarCatalogo() async {
    try {
      final respuesta = await ApiClient.dio.get('/habilidades');
      return (respuesta.data as List).cast<Map<String, dynamic>>();
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }
}
