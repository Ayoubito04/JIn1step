import '../core/api_client.dart';

/// Rol con el que se registra un usuario.
///
/// Va aquí, fuera de la clase: Dart no permite declarar un enum dentro de una
/// función ni de una clase, solo al nivel más alto de un archivo.
///
/// Cada valor lleva su texto para el backend, que exige exactamente
/// 'CANDIDATO' o 'RECLUTADOR' en mayúsculas. Así no hay que convertirlo a mano
/// en cada sitio, y el compilador impide pasar un rol que no existe.
enum Rol {
  candidato('CANDIDATO'),
  reclutador('RECLUTADOR');

  const Rol(this.valorApi);

  /// Lo que se manda al backend.
  final String valorApi;
}

/// Llamadas de autenticación al backend (/api/auth).
///
/// No es `final` a propósito: los tests lo sustituyen por una versión falsa
/// para probar la pantalla de login sin necesitar el servidor encendido.
class AuthService {
  /// Inicia sesión y guarda los tokens en el almacenamiento cifrado.
  ///
  /// Devuelve los datos públicos del usuario ({id, nombre, apellidos, email,
  /// rol}). Si falla, lanza siempre un ApiException con un mensaje listo para
  /// enseñar en pantalla.
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final respuesta = await ApiClient.dio.post(
        '/auth/login',
        // Solo estas dos claves: el schema del backend es .strict() y
        // rechaza cualquier campo que sobre.
        data: {'email': email, 'password': password},
      );

      final datos = respuesta.data as Map<String, dynamic>;

      await ApiClient.storage.write(
        key: ApiClient.claveAccessToken,
        value: datos['accessToken'] as String,
      );
      await ApiClient.storage.write(
        key: ApiClient.claveRefreshToken,
        value: datos['refreshToken'] as String,
      );

      return datos['usuario'] as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }
  //Antes del registroi,vamos a definir el rol del usuario

  /// Cierra la sesión borrando los tokens del dispositivo.
  Future<void> logout() async {
    await ApiClient.storage.delete(key: ApiClient.claveAccessToken);
    await ApiClient.storage.delete(key: ApiClient.claveRefreshToken);
  }

  /// Crea la cuenta y deja la sesión iniciada, igual que login.
  ///
  /// Devuelve Map y no void: al registrarse, el backend ya devuelve el usuario
  /// y sus tokens, así que no hace falta hacer un login aparte después.
  Future<Map<String, dynamic>> register(
    String nombre,
    String apellidos,
    String email,
    String password,
    Rol rol,
  ) async {
    //Todo lo encerramos en un try catch
    try {
      final res = await ApiClient.dio.post(
        '/auth/register',
        //Qué datos usamos para un registro(nombre,apellidos,email,conttraseña y un rol de usuario)
        data: {
          'nombre': nombre,
          'apellidos': apellidos,
          'email': email,
          'password': password,
          //valorApi convierte Rol.candidato en 'CANDIDATO', que es lo que
          //exige el backend. Solo estas cinco claves: el schema es .strict()
          //y rechaza cualquier campo que sobre.
          'rol': rol.valorApi,
        },

        //Una vez que tengamos estos datos,tocaría mapear los datos que ya ha creadoi el usuario para verificar
      );
      final datos = res.data as Map<String, dynamic>;
      await ApiClient.storage.write(
        //Guardamos los datos en el almacenamiento cifrado
        key: ApiClient.claveAccessToken,
        value: datos['accessToken'] as String,
      );
      await ApiClient.storage.write(
        key: ApiClient.claveRefreshToken,
        value: datos['refreshToken'] as String,
      );
      return datos['usuario'] as Map<String, dynamic>;
    } catch (error) {
      throw ApiClient.traducirError(error);
    }
  }
}
