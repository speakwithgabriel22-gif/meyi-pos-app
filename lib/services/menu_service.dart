// import 'package:comedor_app/utils/api_helper.dart';
// import 'package:comedor_app/models/categoria_menu_pos_dto.dart';
// import 'package:comedor_app/models/menu_response.dart';
// import 'package:comedor_app/utils/constants.dart'; // 🔥 ¡Súper importante importar tus constantes!

// class MenuService {
//   final ApiHelper _apiHelper = ApiHelper();

//   /// Obtiene el menú activo dependiendo de la hora actual y el comedor
//   Future<MenuResponse> obtenerMenuActivo(int comedorId) async {
//     try {
//       // 1. Llamada GET a tu controlador en Spring Boot
//       final result = await _apiHelper.get('api/menu/$comedorId');
      
//       // 2. Convertimos el JSON dinámico en nuestro objeto tipado
//       final response = MenuResponse.fromJson(result);

//       // 3. ⚡ LA MAGIA: Guardamos las horas de caducidad en el celular
//       // Solo hacemos esto si el que está pidiendo el menú es un EMPLEADO.
//       if (Constants.isEmpleado || Constants.isCocina) {
//         await Constants.saveMenuSession(
//           comedorIdParam: comedorId,
//           tipoConsumoIdParam: response.tipoConsumoId,
//           horaInicioParam: response.horaInicio,
//           horaFinParam: response.horaFin,
//         );
//       }

//       // 4. Retornamos la respuesta ya lista para la pantalla
//       return response;
      
//     } catch (e) {
//       // Retornamos el error limpio para que tu Bloc o Provider lo atrape
//       return Future.error("Error al cargar el menú: ${e.toString()}");
//     }
//   }

//   /// Obtiene el menú agrupado para POS/Caja: GET /api/menu/pos/{comedorId}
//   Future<List<CategoriaMenuPosDTO>> obtenerMenuCaja(int comedorId) async {
//     try {
//       final result = await _apiHelper.get('api/menu/pos/$comedorId');
//       if (result is! List) return <CategoriaMenuPosDTO>[];
//       return result.map((e) => CategoriaMenuPosDTO.fromJson(e)).toList().cast<CategoriaMenuPosDTO>();
//     } catch (e) {
//       return Future.error("Error al cargar el menú de caja: ${e.toString()}");
//     }
//   }
// }
