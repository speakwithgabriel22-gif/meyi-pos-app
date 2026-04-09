import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/error_response.dart';
import '../utils/constants.dart';

/// Cliente HTTP centralizado para MEYISOFT POS (Tienda de Abarrotes).
///
/// - Singleton: una sola instancia de Dio compartida en toda la app.
/// - Inyecta automáticamente el Bearer token desde [Constants].
/// - Verifica conectividad antes de cada request.
/// - Centraliza el manejo de errores con [ErrorResponse].
class ApiHelper {
  late Dio _dio;

  // ── SINGLETON ──────────────────────────────────────────────
  static final ApiHelper _instance = ApiHelper._internal();
  factory ApiHelper() => _instance;

  // ── CONSTRUCTOR INTERNO ────────────────────────────────────
  ApiHelper._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: Constants.apiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      contentType: 'application/json',
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        /// 🔌 Verificar conectividad antes de cada request
        if (!await hasInternet()) {
          return handler.reject(
            DioException(
              requestOptions: options,
              error: 'Sin conexión a Internet',
              type: DioExceptionType.connectionError,
            ),
          );
        }

        /// 🔐 Inyectar Bearer token automáticamente
        final token = Constants.token;
        if (token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        _printRequest(options);
        return handler.next(options);
      },
      onResponse: (response, handler) {
        _printResponse(response);
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        _printError(e);
        return handler.next(e);
      },
    ));
  }

  // ==========================================
  // ⚡ MÉTODOS HTTP (TIPADOS)
  // ==========================================

  /// GET tipado — retorna directamente el tipo [T] esperado.
  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST tipado — envía [data] como body y retorna [T].
  Future<T> post<T>(String path,
      {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response =
          await _dio.post(path, data: data, queryParameters: queryParameters);
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT tipado — reemplaza recurso completo.
  Future<T> put<T>(String path,
      {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response =
          await _dio.put(path, data: data, queryParameters: queryParameters);
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PATCH tipado — actualización parcial de recurso.
  Future<T> patch<T>(String path,
      {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response =
          await _dio.patch(path, data: data, queryParameters: queryParameters);
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE tipado — elimina recurso.
  Future<T> delete<T>(String path,
      {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response =
          await _dio.delete(path, data: data, queryParameters: queryParameters);
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ==========================================
  // 🌐 INTERNET
  // ==========================================

  /// Verifica si hay conectividad activa (WiFi, móvil, etc.) y si realmente hay
  /// salida a internet realizando un lookup rápido de DNS.
  Future<bool> hasInternet() async {
    // 🛡️ Capa de super-seguridad: No permitimos que TODO el proceso
    // (ni los plugins nativos ni el socket) excedan de 3 segundos bajo NINGUN motivo.
    try {
      return await _checkInternetLogic().timeout(const Duration(seconds: 3));
    } catch (_) {
      return false; // Si algo se cuelga (TimeoutException), asumimos Offline.
    }
  }

  Future<bool> _checkInternetLogic() async {
    final result = await Connectivity().checkConnectivity();
    if (result.contains(ConnectivityResult.none)) return false;

    try {
      final socket = await Socket.connect('1.1.1.1', 53);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // 🛡️ ERROR HANDLER
  // ==========================================

  ErrorResponse _handleError(DioException e) {
    /// 🔌 SIN INTERNET o timeout de conexión
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return ErrorResponse.defaultError(
        message: 'No hay conexión a internet. Revisa tu red.',
        code: 'NO_INTERNET',
      );
    }

    /// ⏳ TIMEOUT de respuesta del servidor
    if (e.type == DioExceptionType.receiveTimeout) {
      return ErrorResponse.defaultError(
        message: 'El servidor no respondió a tiempo.',
        code: 'ERR_TIMEOUT',
      );
    }

    /// ❌ Request CANCELADO
    if (e.type == DioExceptionType.cancel) {
      return ErrorResponse.defaultError(
        message: 'Petición cancelada.',
        code: 'REQUEST_CANCELLED',
      );
    }

    /// 📦 Respuesta del backend con error HTTP
    if (e.response != null) {
      final data = e.response!.data;

      try {
        /// JSON Map correcto → parsear con ErrorResponse
        if (data is Map<String, dynamic>) {
          return ErrorResponse.fromJson(data);
        }

        /// Map dinámico → convertir y parsear
        if (data is Map) {
          return ErrorResponse.fromJson(Map<String, dynamic>.from(data));
        }

        /// String plano del servidor
        if (data is String) {
          return ErrorResponse.defaultError(
            message: data,
            code: 'ERR_SERVER',
          );
        }
      } catch (_) {
        return ErrorResponse.defaultError(
          message: 'Error al procesar respuesta del servidor',
          code: 'ERR_PARSE',
        );
      }
    }

    /// 🚨 FALLBACK — error desconocido
    return ErrorResponse.defaultError(
      message: e.message ?? 'Error desconocido',
      code: 'API_ERR',
    );
  }

  // ==========================================
  // 🟢 LOGS (solo en debug)
  // ==========================================

  void _printRequest(RequestOptions options) {
    print('\x1B[35m' + '=' * 50 + '\x1B[0m');
    print('\x1B[36m📤 REQUEST: ${options.method} ${options.uri}\x1B[0m');

    print('\x1B[33m🔑 Headers:\x1B[0m');
    options.headers.forEach((k, v) => print('  $k: $v'));

    if (options.data != null) {
      print('\x1B[33m📦 Body:\x1B[0m');
      try {
        final pretty = const JsonEncoder.withIndent('  ').convert(options.data);
        print('\x1B[37m$pretty\x1B[0m');
      } catch (_) {
        print(options.data);
      }
    }

    print('\x1B[35m' + '=' * 50 + '\x1B[0m');
  }

  void _printResponse(Response response) {
    print('\x1B[32m' + '✅' * 25 + '\x1B[0m');
    print('\x1B[32m📥 RESPONSE [${response.statusCode}]\x1B[0m');

    try {
      final pretty = const JsonEncoder.withIndent('  ').convert(response.data);
      print('\x1B[37m$pretty\x1B[0m');
    } catch (_) {
      print(response.data);
    }

    print('\x1B[32m' + '✅' * 25 + '\x1B[0m');
  }

  void _printError(DioException e) {
    print('\x1B[31m' + '❌' * 25 + '\x1B[0m');
    print(
        '\x1B[31m🚨 ERROR [${e.response?.statusCode}] => ${e.requestOptions.uri}\x1B[0m');

    if (e.response?.data != null) {
      print('\x1B[33m🧨 BODY:\x1B[0m');
      try {
        final pretty =
            const JsonEncoder.withIndent('  ').convert(e.response!.data);
        print('\x1B[37m$pretty\x1B[0m');
      } catch (_) {
        print(e.response!.data);
      }
    }

    print('\x1B[31m' + '❌' * 25 + '\x1B[0m');
  }
}
