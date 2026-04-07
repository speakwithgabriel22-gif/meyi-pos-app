// import 'package:comedor_app/utils/api_helper.dart';
// import 'package:comedor_app/models/login_unificado_response.dart';
// import 'package:comedor_app/utils/constants.dart';

// // import 'package:comedor/utils/constants.dart'; // Descomenta si lo necesitas

// class AuthService {
//   final ApiHelper _apiHelper = ApiHelper();

//   /// Servicio para loguearse con teléfono y PIN (Modo 0 Fricción)
//   Future<LoginUnificadoResponse> login(String telefono, String pin) async {
//     try {
//       final body = {
//         "telefono": telefono,
//         "pin": pin,
//         "fcmToken": Constants.fcmToken
//       };

//       // Llamada POST a tu endpoint unificado
//       // Asegúrate de que la ruta coincida con cómo tienes armada la base_url en tu ApiHelper.
//       // Si el ApiHelper ya incluye "/api", entonces solo pon "auth/login".
//       final result = await _apiHelper.post('api/auth/login', data: body);

//       // Convierte el resultado dinámico en nuestro modelo tipado
//       return LoginUnificadoResponse.fromJson(result);
      
//     } catch (e) {
//       // Retornamos el error para que la UI lo capture y muestre un SnackBar o Dialog
//       return Future.error(e.toString());
//     }
//   }
// }