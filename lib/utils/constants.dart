// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// class Constants {
//   static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
//     aOptions: AndroidOptions(encryptedSharedPreferences: true),
//     iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
//   );

//   // ── API ───────────────────────────────────────────────────
// static const String apiUrl = "https://runtgenographically-heptarchal-keturah.ngrok-free.dev/";
//   static const Map<String, String> headers = {
//     HttpHeaders.contentTypeHeader: 'application/json'
//   };

//   // ── SESIÓN UNIFICADA ──────────────────────────────────────
//   static String phoneNumber = '';
//   static int id = 0;
//   static String nombre = '';
//   static String rol = '';
//   static int? comedorId; 
//   static List<int> comedoresIds = []; 
//   static String token = ''; 
//   static String fcmToken = ''; // 🔥 Nuevo: Para notificaciones

//   // ── SESIÓN DEL MENÚ / QR (SOLO EMPLEADOS) ─────────────────
//   static int? qrComedorId;
//   static int? menuTipoConsumoId;
//   static String? menuHoraInicio;
//   static String? menuHoraFin;
//   static String? qrFechaEscaneo;

//   // ══════════════════════════════════════════════════════════
//   // AYUDANTES DE ROLES
//   // ══════════════════════════════════════════════════════════
//   static bool get isEmpleado => rol == 'ROLE_EMPLEADO';
//   static bool get isCajero => rol == 'ROLE_CAJERO';
//   static bool get isCocina => rol == 'ROLE_COCINA';
//   static bool get isJefeComedor => rol == 'ROLE_JEFE_COMEDOR';
//   static bool get isAdmin => rol == 'ROLE_ADMIN';
//   static bool get isStaff => isCajero || isCocina || isJefeComedor || isAdmin;


// // ══════════════════════════════════════════════════════════
//   // GESTIÓN DE TELÉFONO (UX)
//   // ══════════════════════════════════════════════════════════
  
//   /// Guarda el teléfono para autocompletar en el próximo login
//   static Future<void> savePhoneNumber(String phoneParam) async {
//     await _secureStorage.write(key: 'user_phone', value: phoneParam);
//     phoneNumber = phoneParam;
//   }

//   /// Carga el teléfono guardado (Se llama en loadSesion)
//   static Future<void> loadPhoneNumber() async {
//     phoneNumber = await _secureStorage.read(key: 'user_phone') ?? '';
//   }
  
//   // ══════════════════════════════════════════════════════════
//   // GESTIÓN DE NOTIFICACIONES (FCM)
//   // ══════════════════════════════════════════════════════════
  
//   /// Guarda el token de Firebase en memoria y storage
//   static Future<void> saveFcmToken(String tokenParam) async {
//     await _secureStorage.write(key: 'fcm_token', value: tokenParam);
//     fcmToken = tokenParam;
//   }

//   /// Carga el token de Firebase (llamarlo en el splash)
//   static Future<void> loadFcmToken() async {
//     fcmToken = await _secureStorage.read(key: 'fcm_token') ?? '';
//   }

//   // ══════════════════════════════════════════════════════════
//   // GUARDAR SESIÓN PRINCIPAL
//   // ══════════════════════════════════════════════════════════
//   static Future<void> saveSesion({
//     required int idParam,
//     required String nombreParam,
//     required String rolParam,
//     int? comedorIdParam,
//     List<int>? comedoresIdsParam,
//     required String tokenParam,
//   }) async {
//     final data = jsonEncode({
//       'id': idParam,
//       'nombre': nombreParam,
//       'rol': rolParam,
//       'comedorId': comedorIdParam,
//       'comedoresIds': comedoresIdsParam ?? [],
//       'token': tokenParam,
//     });

//     await _secureStorage.write(key: 'sesion', value: data);

//     id = idParam;
//     nombre = nombreParam;
//     rol = rolParam;
//     comedorId = comedorIdParam;
//     comedoresIds = comedoresIdsParam ?? [];
//     token = tokenParam;
//   }

//   // ══════════════════════════════════════════════════════════
//   // CARGAR SESIONES
//   // ══════════════════════════════════════════════════════════
//   static Future<bool> loadSesion() async {
//     // Cargamos tokens de notificaciones primero
//     await loadFcmToken();

//     final jsonStr = await _secureStorage.read(key: 'sesion');
//     if (jsonStr == null) return false;

//     try {
//       final data = jsonDecode(jsonStr);
//       id = data['id'] ?? 0;
//       nombre = data['nombre'] ?? '';
//       rol = data['rol'] ?? '';
//       comedorId = data['comedorId'];
//       comedoresIds = data['comedoresIds'] != null ? List<int>.from(data['comedoresIds']) : [];
//       token = data['token'] ?? '';

//       await loadMenuSession();
//       return true;
//     } catch (_) {
//       await clearSesion();
//       return false;
//     }
//   }

//   // ══════════════════════════════════════════════════════════
//   // MÉTODOS DEL MENÚ Y QR
//   // ══════════════════════════════════════════════════════════
//   static Future<void> saveMenuSession({
//     required int comedorIdParam,
//     int? tipoConsumoIdParam,
//     String? horaInicioParam,
//     String? horaFinParam,
//   }) async {
//     final data = jsonEncode({
//       'qrComedorId': comedorIdParam,
//       'menuTipoConsumoId': tipoConsumoIdParam,
//       'menuHoraInicio': horaInicioParam,
//       'menuHoraFin': horaFinParam,
//       'qrFechaEscaneo': DateTime.now().toIso8601String().split('T')[0], 
//     });

//     await _secureStorage.write(key: 'menu_session', value: data);

//     qrComedorId = comedorIdParam;
//     menuTipoConsumoId = tipoConsumoIdParam;
//     menuHoraInicio = horaInicioParam;
//     menuHoraFin = horaFinParam;
//     qrFechaEscaneo = DateTime.now().toIso8601String().split('T')[0];
//   }

//   static Future<void> loadMenuSession() async {
//     final jsonStr = await _secureStorage.read(key: 'menu_session');
//     if (jsonStr != null) {
//       final data = jsonDecode(jsonStr);
//       qrComedorId = data['qrComedorId'];
//       menuTipoConsumoId = data['menuTipoConsumoId'];
//       menuHoraInicio = data['menuHoraInicio'];
//       menuHoraFin = data['menuHoraFin'];
//       qrFechaEscaneo = data['qrFechaEscaneo'];
//     }
//   }

//   static Future<void> clearMenuSession() async {
//     await _secureStorage.delete(key: 'menu_session');
//     qrComedorId = null;
//     menuTipoConsumoId = null;
//     menuHoraInicio = null;
//     menuHoraFin = null;
//     qrFechaEscaneo = null;
//   }

//   static bool isMenuValid() {
//     if (isStaff && comedorId != null) return true;
//     if (!isEmpleado || qrComedorId == null || qrFechaEscaneo == null) return false;

//     final hoyStr = DateTime.now().toIso8601String().split('T')[0];
//     if (qrFechaEscaneo != hoyStr) return false;
//     if (menuHoraFin == null) return true;

//     try {
//       final ahora = DateTime.now();
//       final finParts = menuHoraFin!.split(':');
//       final limite = DateTime(
//         ahora.year, ahora.month, ahora.day, 
//         int.parse(finParts[0]), int.parse(finParts[1]), int.parse(finParts[2])
//       );
//       return ahora.isBefore(limite);
//     } catch (e) {
//       return false;
//     }
//   }

//   // ══════════════════════════════════════════════════════════
//   // UTILIDADES
//   // ══════════════════════════════════════════════════════════
//   static bool hasSesion() => id > 0 && token.isNotEmpty;

//   static Map<String, String> getAuthHeaders() {
//     return {
//       HttpHeaders.contentTypeHeader: 'application/json',
//       HttpHeaders.authorizationHeader: 'Bearer $token',
//     };
//   }

//   static Future<void> clearSesion() async {
//     await _secureStorage.delete(key: 'sesion');
//     // No borramos el fcmToken porque el dispositivo sigue siendo el mismo
//     await clearMenuSession();
//     id = 0;
//     nombre = '';
//     rol = '';
//     comedorId = null;
//     comedoresIds = [];
//     token = '';
//   }
// }