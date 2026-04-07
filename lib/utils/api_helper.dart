// import 'dart:convert';
// import 'package:dio/dio.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import '../models/error_response.dart';
// import '../utils/constants.dart';

// class ApiHelper {
//   late Dio _dio;

//   static final ApiHelper _instance = ApiHelper._internal();
//   factory ApiHelper() => _instance;

//   ApiHelper._internal() {
//     _dio = Dio(BaseOptions(
//       baseUrl: Constants.apiUrl,
//       connectTimeout: const Duration(seconds: 15),
//       receiveTimeout: const Duration(seconds: 15),
//       contentType: 'application/json',
//     ));

//     _dio.interceptors.add(InterceptorsWrapper(
//       onRequest: (options, handler) async {
//         /// 🔌 INTERNET
//         if (!await _hasInternet()) {
//           return handler.reject(
//             DioException(
//               requestOptions: options,
//               error: 'Sin conexión a Internet',
//               type: DioExceptionType.connectionError,
//             ),
//           );
//         }

//         /// 🔐 TOKEN
//         final token = Constants.token;
//         if (token.isNotEmpty) {
//           options.headers['Authorization'] = 'Bearer $token';
//         }

//         /// 🚀 HEADERS DINÁMICOS
//         final isMovil = options.path.contains('api/movil/');
//         final isPedidosV1 = options.path.contains('api/v1/pedidos/');

//         if (Constants.id > 0 && (isMovil || isPedidosV1)) {
//           if (Constants.isStaff) {
//             options.headers['X-Usuario-Id'] = Constants.id.toString();
//             options.headers.remove('X-Empleado-Id');
//           } else {
//             options.headers['X-Empleado-Id'] = Constants.id.toString();
//             options.headers.remove('X-Usuario-Id');
//           }
//         }

//         _printRequest(options);
//         return handler.next(options);
//       },

//       onResponse: (response, handler) {
//         _printResponse(response);
//         return handler.next(response);
//       },

//       onError: (DioException e, handler) {
//         _printError(e);
//         return handler.next(e);
//       },
//     ));
//   }

//   // ==========================================
//   // ⚡ MÉTODOS HTTP (TIPADOS)
//   // ==========================================

//   Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
//     try {
//       final response = await _dio.get(path, queryParameters: queryParameters);
//       return response.data as T;
//     } on DioException catch (e) {
//       throw _handleError(e);
//     }
//   }

//   Future<T> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
//     try {
//       final response = await _dio.post(path, data: data, queryParameters: queryParameters);
//       return response.data as T;
//     } on DioException catch (e) {
//       throw _handleError(e);
//     }
//   }

//   Future<T> put<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
//     try {
//       final response = await _dio.put(path, data: data, queryParameters: queryParameters);
//       return response.data as T;
//     } on DioException catch (e) {
//       throw _handleError(e);
//     }
//   }

//   Future<T> patch<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
//     try {
//       final response = await _dio.patch(path, data: data, queryParameters: queryParameters);
//       return response.data as T;
//     } on DioException catch (e) {
//       throw _handleError(e);
//     }
//   }

//   // ==========================================
//   // 🌐 INTERNET
//   // ==========================================

//   Future<bool> _hasInternet() async {
//     final result = await Connectivity().checkConnectivity();
//     return result != ConnectivityResult.none;
//   }

//   // ==========================================
//   // 🛡️ ERROR HANDLER (CLAVE)
//   // ==========================================

//   ErrorResponse _handleError(DioException e) {
//     /// 🔌 SIN INTERNET
//     if (e.type == DioExceptionType.connectionError ||
//         e.type == DioExceptionType.connectionTimeout) {
//       return ErrorResponse.defaultError(
//         message: 'No hay conexión a internet. Revisa tu red.',
//         code: 'NO_INTERNET',
//       );
//     }

//     /// ⏳ TIMEOUT
//     if (e.type == DioExceptionType.receiveTimeout) {
//       return ErrorResponse.defaultError(
//         message: 'El servidor no respondió a tiempo.',
//         code: 'ERR_TIMEOUT',
//       );
//     }

//     /// ❌ CANCELADO
//     if (e.type == DioExceptionType.cancel) {
//       return ErrorResponse.defaultError(
//         message: 'Petición cancelada.',
//         code: 'REQUEST_CANCELLED',
//       );
//     }

//     /// 📦 BACKEND RESPONSE
//     if (e.response != null) {
//       final data = e.response!.data;

//       try {
//         /// ✅ JSON correcto
//         if (data is Map<String, dynamic>) {
//           return ErrorResponse.fromJson(data);
//         }

//         /// 🧪 Map dinámico
//         if (data is Map) {
//           return ErrorResponse.fromJson(Map<String, dynamic>.from(data));
//         }

//         /// 🧾 String plano
//         if (data is String) {
//           return ErrorResponse.defaultError(
//             message: data,
//             code: 'ERR_SERVER',
//           );
//         }
//       } catch (_) {
//         return ErrorResponse.defaultError(
//           message: 'Error al procesar respuesta del servidor',
//           code: 'ERR_PARSE',
//         );
//       }
//     }

//     /// 🚨 FALLBACK
//     return ErrorResponse.defaultError(
//       message: e.message ?? 'Error desconocido',
//       code: 'API_ERR',
//     );
//   }

//   // ==========================================
//   // 🟢 LOGS
//   // ==========================================

//   void _printRequest(RequestOptions options) {
//     print('\x1B[35m' + '=' * 50 + '\x1B[0m');
//     print('\x1B[36m📤 REQUEST: ${options.method} ${options.uri}\x1B[0m');

//     print('\x1B[33m🔑 Headers:\x1B[0m');
//     options.headers.forEach((k, v) => print('  $k: $v'));

//     if (options.data != null) {
//       print('\x1B[33m📦 Body:\x1B[0m');
//       try {
//         final pretty = const JsonEncoder.withIndent('  ').convert(options.data);
//         print('\x1B[37m$pretty\x1B[0m');
//       } catch (_) {
//         print(options.data);
//       }
//     }

//     print('\x1B[35m' + '=' * 50 + '\x1B[0m');
//   }

//   void _printResponse(Response response) {
//     print('\x1B[32m' + '✅' * 25 + '\x1B[0m');
//     print('\x1B[32m📥 RESPONSE [${response.statusCode}]\x1B[0m');

//     try {
//       final pretty = const JsonEncoder.withIndent('  ').convert(response.data);
//       print('\x1B[37m$pretty\x1B[0m');
//     } catch (_) {
//       print(response.data);
//     }

//     print('\x1B[32m' + '✅' * 25 + '\x1B[0m');
//   }

//   void _printError(DioException e) {
//     print('\x1B[31m' + '❌' * 25 + '\x1B[0m');
//     print('\x1B[31m🚨 ERROR [${e.response?.statusCode}] => ${e.requestOptions.uri}\x1B[0m');

//     if (e.response?.data != null) {
//       print('\x1B[33m🧨 BODY:\x1B[0m');
//       try {
//         final pretty = const JsonEncoder.withIndent('  ').convert(e.response!.data);
//         print('\x1B[37m$pretty\x1B[0m');
//       } catch (_) {
//         print(e.response!.data);
//       }
//     }

//     print('\x1B[31m' + '❌' * 25 + '\x1B[0m');
//   }
// }