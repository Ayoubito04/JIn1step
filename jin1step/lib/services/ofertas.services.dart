//Aquí vamos a implementar un sistema para poder ver las ofertas que hay en la app de jin1step
//Primero de todo importamos el APIClient para conectarnos a la API y poder recoger los datos
import 'package:jin1step/core/api_client.dart';

class OfertasService {
  //Aquí se mostraran todos los servicios para las ofertas de empleo
  Future<List<Map<String, dynamic>>> getAllOfertas() async {
    try {
      final respuesta = await ApiClient.dio.get('/ofertas');
      //Devuelve todas las ofertas de empleo
      //
      // "as List<Map<String, dynamic>>" directo sobre respuesta.data NO
      // funciona: dio decodifica un array JSON como List<dynamic>, que para
      // Dart no es el mismo tipo que List<Map<String, dynamic>>. El cast
      // directo lanza una excepción en cuanto llega una oferta real.
      // .cast() sí convierte elemento a elemento.
      return (respuesta.data as List).cast<Map<String, dynamic>>();
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<List<Map<String, dynamic>>> getMisOfertas() async {
    try {
      final respuesta = await ApiClient.dio.get('/ofertas/mias');
      return (respuesta.data as List).cast<Map<String, dynamic>>();
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listarRequisitos(String ofertaId) async {
    try {
      final respuesta = await ApiClient.dio.get('/ofertas/$ofertaId/requisitos');
      return (respuesta.data as List).cast<Map<String, dynamic>>();
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<void> reemplazarRequisitos({
    required String ofertaId,
    required List<Map<String, dynamic>> requisitos,
  }) async {
    try {
      await ApiClient.dio.put(
        '/ofertas/$ofertaId/requisitos',
        data: {'requisitos': requisitos},
      );
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  //Ahora vamos a publicar ofertas
  Future<Map<String, dynamic>> crearOferta({
    required String empresaId,
    required String titulo,
    required String descripcion,
    required String modalidad, // 'REMOTO' | 'HIBRIDO' | 'PRESENCIAL'
    required List<Map<String, dynamic>> requisitos,
  }) async {
    try {
      final respuesta = await ApiClient.dio.post(
        '/ofertas',
        data: {
          'empresaId': empresaId,
          'titulo': titulo,
          'descripcion': descripcion,
          'modalidad': modalidad,
          'requisitos': requisitos,
        },
      );
      return respuesta.data as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  //Ahora vamos a crear una funcion para poder borrar ofertas
  Future<void> borrarOferta(String id) async {
    try {
      await ApiClient.dio.delete('/ofertas/$id', data: {'estado': 'CERRADA'});
      //Esto nos va a permitir poder borrar ofertas
      return;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  //Ahora vamos a ver las ofertas del reclutador
  Future<Map<String, dynamic>> verOfertasReclutador(String id) async {
    try {
      final respuesta = await ApiClient.dio.get('/ofertas/reclutador/$id');
      return respuesta.data as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  //Ahora una función donde veremos al reclutador sus ofertas
  //Para saber la informacion de una oferta en concreto
}
