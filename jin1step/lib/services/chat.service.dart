import '../core/api_client.dart';

class ChatService {
  Future<List<Map<String, dynamic>>> listarConversaciones() async {
    try {
      final response = await ApiClient.dio.get('/conversaciones');
      return (response.data as List).cast<Map<String, dynamic>>();
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<Map<String, dynamic>> abrir({required String usuarioId, String? ofertaId}) async {
    try {
      final response = await ApiClient.dio.post('/conversaciones', data: {
        'usuarioId': usuarioId,
        if (ofertaId != null) 'ofertaId': ofertaId,
      });
      return response.data as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<List<Map<String, dynamic>>> mensajes(String conversacionId) async {
    try {
      final response = await ApiClient.dio.get('/conversaciones/$conversacionId/mensajes');
      return (response.data as List).cast<Map<String, dynamic>>();
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<Map<String, dynamic>> enviar(String conversacionId, String contenido) async {
    try {
      final response = await ApiClient.dio.post('/conversaciones/$conversacionId/mensajes', data: {'contenido': contenido});
      return response.data as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }
}
