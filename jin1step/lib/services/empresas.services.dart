// Catálogo de empresas. Lo necesita el formulario de publicar oferta: el
// backend exige un empresaId real (GET /empresas es de lectura para ambos
// roles, la crea solo el reclutador vía POST, que aquí no hace falta todavía).
import 'package:jin1step/core/api_client.dart';

class EmpresasService {
  Future<List<Map<String, dynamic>>> listarEmpresas() async {
    try {
      final respuesta = await ApiClient.dio.get('/empresas');
      // Mismo motivo que en OfertasService: dio decodifica el array JSON
      // como List<dynamic>, no como List<Map<String, dynamic>>, así que un
      // "as" directo lanzaría una excepción en cuanto haya datos reales.
      return (respuesta.data as List).cast<Map<String, dynamic>>();
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }
}
