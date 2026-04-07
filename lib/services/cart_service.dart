// import 'dart:convert';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// // 🔥 Asegúrate de poner la ruta correcta hacia tu modelo
// import 'package:comedor_app/models/cart_item.dart'; 

// class CartService {
//   final _storage = const FlutterSecureStorage();
  
//   // Llave única para Transportes Elola
//   final String _cartKey = 'elola_cart_data';

//   /// 📥 Carga el carrito guardado al abrir la app
//   Future<List<CartItem>> loadCart() async {
//     try {
//       final String? cartString = await _storage.read(key: _cartKey);
      
//       if (cartString != null && cartString.isNotEmpty) {
//         final List<dynamic> decoded = jsonDecode(cartString);
//         // Aquí ocurre la magia: CartItem.fromJson hace todo el trabajo pesado
//         return decoded.map((item) => CartItem.fromJson(item)).toList();
//       }
//     } catch (e) {
//       print("\x1B[31m⚠️ Log: Error al cargar carrito local: $e\x1B[0m");
//     }
    
//     // Si no hay nada, el storage está limpio o hubo error, devolvemos lista vacía
//     return []; 
//   }

//   /// 💾 Sobrescribe el carrito en memoria cada vez que se agrega/quita algo
//   Future<void> saveCart(List<CartItem> items) async {
//     try {
//       // Convertimos la lista de CartItems a una lista de Mapas, y luego a String JSON
//       final String encoded = jsonEncode(items.map((i) => i.toJson()).toList());
//       await _storage.write(key: _cartKey, value: encoded);
      
//       print("\x1B[32m✅ Carrito guardado en memoria con ${items.length} items.\x1B[0m");
//     } catch (e) {
//       print("\x1B[31m⚠️ Log: Error al guardar carrito local: $e\x1B[0m");
//     }
//   }

//   /// 🧹 Limpia la memoria (Llamar a este método cuando la cocina confirme el pedido)
//   Future<void> clearCart() async {
//     await _storage.delete(key: _cartKey);
//     print("\x1B[33m🧹 Carrito limpiado de la memoria.\x1B[0m");
//   }
// }