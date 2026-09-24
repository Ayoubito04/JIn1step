import 'package:flutter/foundation.dart';

/// Dirección del backend, en un único sitio.
///
/// Si mañana cambia el puerto o el backend se despliega en un servidor, solo
/// se toca este archivo.
class ApiConfig {
  ApiConfig._();

  static String get baseUrl {
    // En web la app corre en el navegador del propio PC, así que localhost
    // sí apunta al backend.
    if (kIsWeb) return 'http://localhost:3000/api';

    // El emulador de Android NO ve tu PC como localhost: para él, localhost
    // es el propio emulador. 10.0.2.2 es la dirección que Android reserva
    // para llegar al ordenador que lo está ejecutando.
    //
    // Se usa defaultTargetPlatform y no dart:io porque dart:io no existe en
    // web y rompería la compilación para Chrome.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }

    // Escritorio (Windows) o iOS en simulador.
    return 'http://localhost:3000/api';
  }
}
