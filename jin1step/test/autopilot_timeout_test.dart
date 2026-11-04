import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jin1step/core/api_client.dart';
import 'package:jin1step/services/candidato.service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Interceptor> interceptoresOriginales;

  setUp(() {
    interceptoresOriginales = ApiClient.dio.interceptors.toList();
    ApiClient.dio.interceptors.clear();
  });

  tearDown(() {
    ApiClient.dio.interceptors.clear();
    ApiClient.dio.interceptors.addAll(interceptoresOriginales);
  });

  test('el autopiloto y su previsualización permiten esperas largas', () async {
    final peticiones = <RequestOptions>[];
    ApiClient.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opciones, handler) {
          peticiones.add(opciones);
          handler.resolve(
            Response(requestOptions: opciones, data: <String, dynamic>{}),
          );
        },
      ),
    );

    final servicio = CandidatoService();
    await servicio.ejecutarAutopilot();
    await servicio.previsualizarAutopilot();

    expect(peticiones.map((peticion) => peticion.path), [
      '/postulaciones-autopilot/ejecutar',
      '/postulaciones-autopilot/previsualizar',
    ]);
    expect(peticiones.map((peticion) => peticion.receiveTimeout), [
      const Duration(minutes: 4),
      const Duration(minutes: 4),
    ]);
    expect(ApiClient.dio.options.receiveTimeout, const Duration(seconds: 15));
  });

  test(
    'avisa de que la ejecución puede continuar tras una espera agotada',
    () async {
      ApiClient.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (opciones, handler) => handler.reject(
            DioException(
              requestOptions: opciones,
              type: DioExceptionType.receiveTimeout,
            ),
          ),
        ),
      );

      await expectLater(
        CandidatoService().ejecutarAutopilot(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.mensaje,
            'mensaje',
            contains('revisa tus propuestas y candidaturas'),
          ),
        ),
      );
    },
  );

  test('distingue una espera agotada de un fallo de conexión', () {
    final opciones = RequestOptions(path: '/prueba');
    final espera = ApiClient.traducirError(
      DioException(
        requestOptions: opciones,
        type: DioExceptionType.receiveTimeout,
      ),
    );
    final conexion = ApiClient.traducirError(
      DioException(
        requestOptions: opciones,
        type: DioExceptionType.connectionError,
      ),
    );

    expect(espera.mensaje, contains('tardó demasiado'));
    expect(conexion.mensaje, contains('No se puede conectar'));
  });
}
