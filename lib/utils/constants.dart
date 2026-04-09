import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Constantes y estado de sesión para MEYISOFT POS (Tienda de Abarrotes).
///
/// - [FlutterSecureStorage] se centraliza aquí como única fuente de persistencia segura.
/// - Los campos de sesión se mantienen en memoria para acceso sincrónico.
/// - La persistencia se hace vía [saveSesion] / [loadSesion] / [clearSesion].
class Constants {
  // ── SECURE STORAGE CENTRALIZADO ────────────────────────────
  /// Instancia única de FlutterSecureStorage para toda la app.
  /// Cualquier módulo que necesite leer/escribir datos seguros DEBE pasar por aquí.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ── API CONFIG ─────────────────────────────────────────────
  /// URL base del backend. Cambiar según entorno (dev/staging/prod).
  static const String apiUrl =
      "https://runtgenographically-heptarchal-keturah.ngrok-free.dev/";

  /// Delay mínimo para UX en operaciones rápidas (evita parpadeos).
  static const int uiDelayMs = 200;

  // ── SESIÓN EN MEMORIA ──────────────────────────────────────
  /// ID del usuario autenticado (UUID string).
  static String userId = '';

  /// Teléfono del usuario (usado como identificador de login).
  static String phoneNumber = '';

  /// Nombre completo del usuario (para mostrar en UI).
  static String nombre = '';

  /// Rol del usuario: 'OWNER' o 'AGENT'.
  static String rol = '';

  /// JWT token para autenticación Bearer.
  static String token = '';

  /// Token de Firebase Cloud Messaging para push notifications.
  static String fcmToken = '';

  /// ID del tenant (tienda) activo seleccionado.
  static String? tenantId;

  /// Lista de IDs de tenants a los que el usuario tiene acceso.
  static List<String> tenantIds = [];

  // ── GETTERS DE ESTADO ──────────────────────────────────────
  /// Verdadero si hay sesión válida (tiene ID y token).
  static bool get hasSesion => userId.isNotEmpty && token.isNotEmpty;

  /// Verdadero si el usuario es dueño de la tienda.
  static bool get isAdmin => rol == 'OWNER';

  /// Verdadero si el usuario es un agente/empleado.
  static bool get isAgent => rol == 'AGENT';

  /// Retorna el ID del tenant activo, priorizando la selección manual.
  static String? get activeTenantId {
    if (tenantId != null && tenantId!.isNotEmpty) return tenantId;
    if (tenantIds.isNotEmpty) return tenantIds.first;
    return null;
  }

  /// Verdadero si hay un tenant activo seleccionado.
  static bool get hasActiveTenant => activeTenantId != null;

  // ── STORAGE PÚBLICO (para módulos externos) ────────────────

  /// Lee un valor seguro del storage por su [key].
  static Future<String?> readSecure(String key) async {
    return await _storage.read(key: key);
  }

  /// Escribe un valor seguro en el storage con la [key] dada.
  static Future<void> writeSecure(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Elimina un valor del storage por su [key].
  static Future<void> deleteSecure(String key) async {
    await _storage.delete(key: key);
  }

  // ── MÉTODOS DE PERSISTENCIA ─────────────────────────────────

  /// Guarda la sesión completa en SecureStorage y actualiza la memoria.
  ///
  /// Se llama después de un login o registro exitoso.
  static Future<void> saveSesion({
    required String idParam,
    required String nombreParam,
    required String rolParam,
    required String tokenParam,
    String? phoneParam,
    String? tenantIdParam,
    List<String>? tenantIdsParam,
  }) async {
    // Serializar todos los datos de sesión en un solo JSON
    final data = {
      'id': idParam,
      'nombre': nombreParam,
      'rol': rolParam,
      'token': tokenParam,
      'phone': phoneParam ?? phoneNumber,
      'tenantId': tenantIdParam,
      'tenantIds': tenantIdsParam ?? [],
    };

    // Persistir en storage seguro
    await _storage.write(key: 'sesion', value: jsonEncode(data));

    // Actualizar memoria para acceso sincrónico
    userId = idParam;
    nombre = nombreParam;
    rol = rolParam;
    token = tokenParam;
    if (phoneParam != null) phoneNumber = phoneParam;
    tenantId = tenantIdParam;
    tenantIds = tenantIdsParam ?? [];
  }

  /// Carga la sesión desde SecureStorage a memoria.
  ///
  /// Retorna `true` si la sesión cargó correctamente y es válida.
  /// Se llama en el SplashScreen al iniciar la app.

  static Future<bool> loadSesion() async {
    debugPrint('--- CARGANDO SESIÓN DESDE SECURE STORAGE ---');
    try {
      final jsonStr = await _storage.read(key: 'sesion');
      debugPrint('JSON leído: $jsonStr');

      if (jsonStr == null) {
        debugPrint('-> No se encontró sesión guardada (null).');
        return false;
      }

      final data = jsonDecode(jsonStr);
      debugPrint('Datos decodificados: $data');

      userId = data['id']?.toString() ?? '';
      nombre = data['nombre'] ?? '';
      rol = data['rol'] ?? '';
      token = data['token'] ?? '';
      phoneNumber = data['phone'] ?? '';
      tenantIds = List<String>.from(data['tenantIds'] ?? []);
      tenantId =
          data['tenantId'] ?? (tenantIds.isNotEmpty ? tenantIds.first : null);

      debugPrint(
          'Mapeo exitoso: userId=$userId, hasToken=${token.isNotEmpty}, tenantId=$tenantId');

      await loadFcmToken();
      final sessionValid = hasSesion;
      debugPrint('-> ¿Es válida la sesión (hasSesion)? $sessionValid');
      return sessionValid;
    } catch (e, stacktrace) {
      debugPrint('ERROR LEYENDO SESIÓN: $e');
      debugPrint('Stacktrace: $stacktrace');
      await clearSesion();
      return false;
    }
  }

  /// Limpia toda la sesión (Logout).
  ///
  /// Borra de SecureStorage y resetea la memoria.
  static Future<void> clearSesion() async {
    await _storage.delete(key: 'sesion');
    userId = '';
    nombre = '';
    rol = '';
    token = '';
    tenantId = null;
    tenantIds = [];
  }

  // ── TELÉFONO Y NOTIFICACIONES ──────────────────────────────

  /// Guarda el teléfono del usuario en storage y memoria.
  static Future<void> savePhoneNumber(String phone) async {
    await _storage.write(key: 'user_phone', value: phone);
    phoneNumber = phone;
  }

  /// Carga el teléfono del usuario desde storage.
  static Future<void> loadPhoneNumber() async {
    phoneNumber = await _storage.read(key: 'user_phone') ?? '';
  }

  /// Guarda el token FCM para push notifications.
  static Future<void> saveFcmToken(String tokenParam) async {
    await _storage.write(key: 'fcm_token', value: tokenParam);
    fcmToken = tokenParam;
  }

  /// Carga el token FCM desde storage.
  static Future<void> loadFcmToken() async {
    fcmToken = await _storage.read(key: 'fcm_token') ?? '';
  }

  // ── CABECERAS AUXILIARES ───────────────────────────────────
  /// Headers de autenticación para uso manual fuera de Dio.
  static Map<String, String> getAuthHeaders() {
    return {
      HttpHeaders.contentTypeHeader: 'application/json',
      if (token.isNotEmpty) HttpHeaders.authorizationHeader: 'Bearer $token',
    };
  }
}
