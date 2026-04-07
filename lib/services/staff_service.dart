// import 'package:comedor_app/models/PedidoCajeroDTO.dart';
// import 'package:comedor_app/models/comanda_kds_response.dart';
// import 'package:comedor_app/models/consumo_directo_request.dart';
// import 'package:comedor_app/models/consumo_response.dart';
// import 'package:comedor_app/models/empleado_dto.dart';
// import 'package:comedor_app/models/panel_despacho_response.dart';
// import 'package:comedor_app/models/pantalla_tv_response.dart';
// import 'package:comedor_app/models/pedido_response.dart';
// import 'package:comedor_app/models/ticket_tv_dto.dart';
// import 'package:comedor_app/models/validacion_qr_response.dart';
// import 'package:comedor_app/utils/api_helper.dart';
// import 'package:comedor_app/models/error_response.dart';

// class StaffService {
//   final ApiHelper _apiHelper = ApiHelper();

//   Future<List<EmpleadoDTO>> buscarEmpleados(String termino) async {
//     try {
//       final result = await _apiHelper.get<List>(
//         'api/movil/buscar',
//         queryParameters: {'q': termino},
//       );

//       return result.map((e) => EmpleadoDTO.fromJson(e)).toList();
//     } on ErrorResponse {
//       rethrow;
//     } catch (e) {
//       throw ErrorResponse.defaultError(message: e.toString(), code: 'SERVICE_ERROR');
//     }
//   }

//   Future<List<ComandaKdsResponse>> verPedidosPendientes(int comedorId) async {
//     try {
//       final result = await _apiHelper.get<List>('api/movil/pedidos/$comedorId');
//       return result.map((e) => ComandaKdsResponse.fromJson(e)).toList();
//     } on ErrorResponse {
//       rethrow;
//     } catch (e) {
//       throw ErrorResponse.defaultError(message: e.toString(), code: 'SERVICE_ERROR');
//     }
//   }

//   Future<ConsumoResponse> marcarPreparando(int consumoId) async {
//     try {
//       final result = await _apiHelper.post<Map<String, dynamic>>(
//         'api/movil/preparar/$consumoId',
//       );
//       return ConsumoResponse.fromJson(result);
//     } on ErrorResponse {
//       rethrow;
//     } catch (e) {
//       throw ErrorResponse.defaultError(message: e.toString(), code: 'SERVICE_ERROR');
//     }
//   }

//   Future<ConsumoResponse> marcarListo(int consumoId) async {
//     try {
//       final result = await _apiHelper.post<Map<String, dynamic>>(
//         'api/movil/listo/$consumoId',
//       );
//       return ConsumoResponse.fromJson(result);
//     } on ErrorResponse {
//       rethrow;
//     } catch (e) {
//       throw ErrorResponse.defaultError(message: e.toString(), code: 'SERVICE_ERROR');
//     }
//   }

//   Future<PantallaTvResponse> obtenerPantallaTv(int comedorId) async {
//     try {
//       final result = await _apiHelper.get<Map<String, dynamic>>(
//         'api/movil/pantalla/$comedorId',
//       );
//       return PantallaTvResponse.fromJson(result);
//     } on ErrorResponse {
//       rethrow;
//     } catch (e) {
//       throw ErrorResponse.defaultError(message: e.toString(), code: 'SERVICE_ERROR');
//     }
//   }

//   Future<List<PedidoCajeroDTO>> obtenerPedidosListos(int comedorId) async {
//     try {
//       final result = await _apiHelper.get<List>('api/movil/listos/$comedorId');
//       return result.map((e) => PedidoCajeroDTO.fromJson(e)).toList();
//     } on ErrorResponse {
//       rethrow;
//     } catch (e) {
//       throw ErrorResponse.defaultError(message: e.toString(), code: 'SERVICE_ERROR');
//     }
//   }

//   Future<PanelDespachoResponse> obtenerPanelDespacho(int comedorId) async {
//     try {
//       final result = await _apiHelper.get<Map<String, dynamic>>(
//         'api/movil/panel/$comedorId',
//       );
//       return PanelDespachoResponse.fromJson(result);
//     } on ErrorResponse {
//       rethrow;
//     } catch (e) {
//       throw ErrorResponse.defaultError(message: e.toString(), code: 'SERVICE_ERROR');
//     }
//   }

//   Future<ValidacionQRResponse> validarQr(String token) async {
//     try {
//       final result = await _apiHelper.post<Map<String, dynamic>>(
//         'api/movil/validar/$token',
//       );
//       return ValidacionQRResponse.fromJson(result);
//     } on ErrorResponse {
//       rethrow;
//     } catch (e) {
//       throw ErrorResponse.defaultError(message: e.toString(), code: 'SERVICE_ERROR');
//     }
//   }

//   Future<ConsumoResponse> entregarPedido(int consumoId) async {
//     try {
//       final result = await _apiHelper.post<Map<String, dynamic>>(
//         'api/movil/entregar/$consumoId',
//       );
//       return ConsumoResponse.fromJson(result);
//     } on ErrorResponse {
//       rethrow;
//     } catch (e) {
//       throw ErrorResponse.defaultError(message: e.toString(), code: 'SERVICE_ERROR');
//     }
//   }

//   Future<ConsumoResponse> cancelarPedido(int consumoId, String motivo) async {
//     try {
//       final result = await _apiHelper.post<Map<String, dynamic>>(
//         'api/movil/cancelar/$consumoId',
//         queryParameters: {'motivo': motivo},
//       );
//       return ConsumoResponse.fromJson(result);
//     } on ErrorResponse {
//       rethrow;
//     } catch (e) {
//       throw ErrorResponse.defaultError(message: e.toString(), code: 'SERVICE_ERROR');
//     }
//   }

//   Future<PedidoResponse> ventaDirecta(ConsumoDirectoRequest request) async {
//     try {
//       final result = await _apiHelper.post<Map<String, dynamic>>(
//         'api/movil/directo',
//         data: request.toJson(),
//       );
//       return PedidoResponse.fromJson(result);
//     } on ErrorResponse {
//       rethrow;
//     } catch (e) {
//       throw ErrorResponse.defaultError(message: e.toString(), code: 'SERVICE_ERROR');
//     }
//   }
// }