// import 'package:comedor_app/models/cancelacion_response.dart';
// import 'package:comedor_app/models/crear_consumo_request.dart';
// import 'package:comedor_app/models/estado_pedido_response.dart';
// import 'package:comedor_app/models/pedido_response.dart';
// import 'package:comedor_app/utils/api_helper.dart';
// import 'package:comedor_app/models/estado_pedido_simple.dart';

// class ConsumoService {
//   final ApiHelper _apiHelper = ApiHelper();

//   /// Verifica si el empleado tiene comida en la parrilla (Modo Ultraligero)
//   Future<EstadoPedidoSimple> verificarPedidoActivo() async {
//     try {
//       // Llamada GET usando tu helper.
//       // Le pasamos el header personalizado que armamos en Spring Boot.
//       final result = await _apiHelper.get(
//         'api/movil/verificar',
//       );

//       // Convertimos el mapa dinámico que devuelve tu ApiHelper a nuestro objeto tipado
//       return EstadoPedidoSimple.fromJson(result);
//     } catch (e) {
//       // Retornamos el error para que el Splash Screen lo atrape y mande al Home seguro
//       return Future.error(e.toString());
//     }
//   }


//   /// 🛒 POST /api/movil/crear-pedido
//   /// Envía la lista de productos y modificadores para generar el folio y QR.
//   Future<PedidoResponse> generarPedido(CrearConsumoRequest request) async {
//     try {
//       final result = await _apiHelper.post(
//         'api/movil/crear-pedido',
//         data: request.toJson(),
//       );

//       return PedidoResponse.fromJson(result);
//     } catch (e) {
//       // Aquí atrapamos el error HOR_002 (Fuera de horario) o cualquier otro
//       return Future.error(e.toString());
//     }
//   }

//   /// 🔍 GET /api/movil/estado
//   /// Consulta si el pedido está en CREADO, PREPARANDO, LISTO, etc.
//   Future<EstadoPedidoResponse> consultarEstadoPedido() async {
//     try {
//       final result = await _apiHelper.get(
//         'api/movil/estado',
//       );

//       return EstadoPedidoResponse.fromJson(result);
//     } catch (e) {
//       return Future.error("No se pudo obtener el estado actual");
//     }
//   }

//   /// ❌ POST /api/movil/cancelar-pedido
//   Future<CancelacionResponse> cancelarMiPedido() async {
//     try {
//       final result = await _apiHelper.post('api/movil/cancelar-pedido');
//       return CancelacionResponse.fromJson(result);
//     } catch (e) {
//       // Atrapamos errores CON_012 (No hay pedido) o CON_013 (Ya validado)
//       return Future.error(e.toString());
//     }
//   }
  
// }
