import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_config.dart';

/// Error ya traducido a un mensaje que se le puede enseñar al usuario.
///
/// Las pantallas nunca ven un DioException: solo esto. Así no tienen que
/// saber nada de HTTP, códigos de estado ni del formato de error del backend.
class ApiException implements Exception {
  const ApiException(this.mensaje, {this.status});

  final String mensaje;
  final int? status;

  @override
  String toString() => mensaje;
}

/// Cliente HTTP compartido por toda la app.
class ApiClient {
  ApiClient._();

  static const claveAccessToken = 'accessToken';
  static const claveRefreshToken = 'refreshToken';

  /// Almacenamiento cifrado del móvil. Los tokens NO van en
  /// SharedPreferences: ahí se guardan en texto plano y cualquier app con
  /// acceso root los podría leer.
  static const storage = FlutterSecureStorage();

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      // Sin límite, si el backend está apagado el botón se quedaría
      // cargando indefinidamente.
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        // Añade el token a TODAS las peticiones desde un único sitio, en vez
        // de repetirlo en cada servicio.
        onRequest: (options, handler) async {
          final token = await storage.read(key: claveAccessToken);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

  /// Convierte cualquier error de red en un ApiException con un mensaje
  /// legible.
  ///
  /// El backend responde los errores como {"error": "..."} y, en los de
  /// validación, añade {"detalles": [{"campo", "mensaje"}]}. Se prefiere el
  /// primer detalle porque dice QUÉ campo falla, que es más útil que el
  /// genérico "Datos inválidos".
  static ApiException traducirError(Object error) {
    if (error is ApiException) return error;

    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.connectionError:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return const ApiException(
            'No se puede conectar con el servidor. ¿Está encendido el backend?',
          );
        default:
          break;
      }

      final status = error.response?.statusCode;
      final data = error.response?.data;

      if (data is Map && data['error'] is String) {
        final detalles = data['detalles'];
        if (detalles is List &&
            detalles.isNotEmpty &&
            detalles.first is Map &&
            (detalles.first as Map)['mensaje'] is String) {
          return ApiException(
            (detalles.first as Map)['mensaje'] as String,
            status: status,
          );
        }
        return ApiException(data['error'] as String, status: status);
      }

      return ApiException(
        'Error inesperado del servidor${status != null ? ' ($status)' : ''}',
        status: status,
      );
    }

    return const ApiException('Ha ocurrido un error inesperado');
  }
}
