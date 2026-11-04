import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/api_client.dart';

/// Las propuestas del autopiloto sin decidir y las descartadas no son
/// candidaturas enviadas: la empresa no las ve.
bool esCandidaturaEnviada(Map<String, dynamic> postulacion) =>
    postulacion['estado'] != 'PROPUESTA' &&
    postulacion['estado'] != 'DESCARTADA';

class CandidatoService {
  static const _esperaAutopilot = Duration(minutes: 4);

  /// Aprueba una propuesta del autopiloto: pasa a enviada.
  Future<Map<String, dynamic>> aprobarPostulacion(String id) async {
    try {
      final respuesta = await ApiClient.dio.post('/postulaciones/$id/aprobar');
      return respuesta.data as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  /// Descarta una propuesta del autopiloto: no se envía y no se vuelve a proponer.
  Future<Map<String, dynamic>> descartarPostulacion(String id) async {
    try {
      final respuesta = await ApiClient.dio.post('/postulaciones/$id/descartar');
      return respuesta.data as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  /// Últimas ejecuciones del autopiloto, de la más reciente a la más antigua.
  Future<List<Map<String, dynamic>>> obtenerHistorialAutopilot() async {
    try {
      final respuesta = await ApiClient.dio.get(
        '/postulaciones-autopilot/historial',
      );
      return (respuesta.data as List).cast<Map<String, dynamic>>();
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  /// El PDF original de un CV propio, para previsualizarlo.
  Future<Uint8List> descargarArchivoCv(String cvId) async {
    try {
      final respuesta = await ApiClient.dio.get<List<int>>(
        '/cv/$cvId/archivo',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(respuesta.data ?? const []);
    } on DioException catch (error) {
      // Con responseType bytes, el cuerpo del error también llega en bytes.
      final cuerpo = error.response?.data;
      if (cuerpo is List<int>) {
        try {
          final json = jsonDecode(utf8.decode(cuerpo));
          if (json is Map && json['error'] is String) {
            throw ApiException(
              json['error'] as String,
              status: error.response?.statusCode,
            );
          }
        } on FormatException {
          // No era JSON: se traduce como cualquier otro error.
        }
      }
      throw ApiClient.traducirError(error);
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<Map<String, dynamic>> obtenerMiPerfil() async {
    try {
      final respuesta = await ApiClient.dio.get('/perfil-candidato/mio');
      return respuesta.data as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  /// Guarda ubicación, disponibilidad y expectativa salarial; `null` borra ese dato.
  Future<Map<String, dynamic>> guardarMiPerfil({
    required String? ubicacion,
    required String? disponibilidad,
    int? expectativaSalarial,
    String? banner,
  }) async {
    try {
      final respuesta = await ApiClient.dio.patch(
        '/perfil-candidato/mio',
        data: {
          'ubicacion': ubicacion,
          'disponibilidad': disponibilidad,
          'expectativaSalarial': expectativaSalarial,
          'banner': ?banner,
        },
      );
      return respuesta.data as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  /// Sube una imagen (JPG, PNG, WEBP o GIF) como foto de portada (banner) del perfil.
  Future<Map<String, dynamic>> subirBannerPerfil({
    required String nombreArchivo,
    required List<int> bytes,
  }) async {
    try {
      final ext = nombreArchivo.toLowerCase();
      final mime = ext.endsWith('.png')
          ? 'image/png'
          : ext.endsWith('.webp')
          ? 'image/webp'
          : ext.endsWith('.gif')
          ? 'image/gif'
          : 'image/jpeg';
      final datos = FormData.fromMap({
        'archivo': MultipartFile.fromBytes(
          bytes,
          filename: nombreArchivo,
          contentType: DioMediaType.parse(mime),
        ),
      });
      final respuesta = await ApiClient.dio.post(
        '/perfil-candidato/mio/banner',
        data: datos,
      );
      return respuesta.data as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  /// Elimina la foto de portada (banner) del perfil del candidato.
  Future<Map<String, dynamic>> borrarBannerPerfil() async {
    try {
      final respuesta = await ApiClient.dio.delete(
        '/perfil-candidato/mio/banner',
      );
      return respuesta.data as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listarHabilidadesCv(String cvId) async {
    try {
      final respuesta = await ApiClient.dio.get('/habilidades/cv/$cvId');
      return (respuesta.data as List).cast<Map<String, dynamic>>();
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<void> asignarHabilidadCv(
    String cvId,
    String habilidadId,
    String? nivel,
  ) async {
    try {
      await ApiClient.dio.post(
        '/habilidades/cv/$cvId',
        data: {'habilidadId': habilidadId, 'nivel': nivel},
      );
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<void> actualizarNivelHabilidadCv(
    String cvId,
    String habilidadId,
    String? nivel,
  ) async {
    try {
      await ApiClient.dio.patch(
        '/habilidades/cv/$cvId/$habilidadId',
        data: {'nivel': nivel},
      );
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

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

  /// Retira una candidatura propia que la empresa aún no ha revisado.
  Future<Map<String, dynamic>> retirarPostulacion(String id) async {
    try {
      final respuesta = await ApiClient.dio.post('/postulaciones/$id/retirar');
      return respuesta.data as Map<String, dynamic>;
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
        options: Options(receiveTimeout: _esperaAutopilot),
      );
      return respuesta.data as Map<String, dynamic>;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.receiveTimeout) {
        throw const ApiException(
          'El autopiloto está tardando demasiado. Puede seguir procesando: '
          'revisa tus propuestas y candidaturas antes de volver a intentarlo.',
        );
      }
      throw ApiClient.traducirError(error);
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }

  Future<Map<String, dynamic>> previsualizarAutopilot() async {
    try {
      final respuesta = await ApiClient.dio.post(
        '/postulaciones-autopilot/previsualizar',
        options: Options(receiveTimeout: _esperaAutopilot),
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
