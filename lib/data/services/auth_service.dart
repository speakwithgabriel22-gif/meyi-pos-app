import 'package:sqflite/sqflite.dart';
import '../local/db_helper.dart';
import '../models/login_response.dart';
import '../../models/error_response.dart';
import '../../utils/api_helper.dart';
import '../../utils/constants.dart';

class AuthService {
  Future<LoginResponse> _persistAuthResult({
    required Map<String, dynamic> result,
    required String fallbackPhone,
    required String fallbackName,
    required String fallbackRole,
  }) async {
    final user = result['user'] ?? {};
    final tenant = result['tenant'] ?? {};
    final role = result['role'] ?? user['role'] ?? fallbackRole;

    final newTenantId = tenant['id']?.toString() ?? '';
    final phone = user['phone']?.toString() ?? fallbackPhone;
    final userName = user['fullName']?.toString() ?? fallbackName;
    final newId = user['id']?.toString() ?? '';

    // 🔥 FIX 1: Si el endpoint (ej. /init) no devuelve JWT, conservamos el que ya tenemos.
    final newToken = result['jwt']?.toString() ?? '';
    final finalToken = newToken.isNotEmpty ? newToken : Constants.token;

    // 🔥 FIX 2: Si el endpoint no devuelve tenantId, conservamos el activo.
    final finalTenantId =
        newTenantId.isNotEmpty ? newTenantId : (Constants.tenantId ?? '');

    // 🔥 FIX 3: Evitar borrar el userId si /init viene incompleto
    final finalUserId = newId.isNotEmpty ? newId : Constants.userId;

    // Guardar en memoria y Secure Storage sin destruir datos previos
    await Constants.saveSesion(
      idParam: finalUserId,
      nombreParam: userName,
      rolParam: role,
      tokenParam: finalToken,
      phoneParam: phone,
      tenantIdParam: finalTenantId,
      tenantIdsParam:
          finalTenantId.isEmpty ? Constants.tenantIds : [finalTenantId],
    );

    final db = await DbHelper().database;

    // Solo actualizar base de datos local si realmente llegó un tenant
    if (finalTenantId.isNotEmpty) {
      await db.insert(
        'tenants',
        {
          'id': finalTenantId,
          'name': tenant['name'] ?? 'Mi Tienda',
          'is_active': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    if (finalUserId.isNotEmpty) {
      await db.insert(
        'users',
        {
          'id': finalUserId,
          'tenant_id': finalTenantId,
          'full_name': userName,
          'phone': phone,
          'pin_hash':
              '', // Se actualiza fuera de esta función si es login/register
          'role': role,
          'is_active': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    return LoginResponse(
      success: true,
      userName: userName,
      role: role,
      isNew: false,
      tenantId: finalTenantId,
    );
  }

  Future<LoginResponse> login(String phone, String pin) async {
    await Future.delayed(const Duration(milliseconds: Constants.uiDelayMs));

    try {
      final response = await ApiHelper().post<Map<String, dynamic>>(
        'api/v1/public/auth/login',
        data: {
          'phone': phone,
          'pin': pin,
        },
      );

      if (response['ok'] == true && response['result'] != null) {
        final result = response['result'];
        final bool isVerified = result['isVerified'] ?? false;

        if (!isVerified) {
          return const LoginResponse(
            success: true,
            userName: '',
            role: '',
            isNew: true,
            tenantId: '',
          );
        }

        final login = await _persistAuthResult(
          result: result,
          fallbackPhone: phone,
          fallbackName: 'Usuario',
          fallbackRole: 'OWNER',
        );
        final db = await DbHelper().database;
        await db.update(
          'users',
          {'pin_hash': pin},
          where: 'id = ?',
          whereArgs: [result['user']?['id']?.toString() ?? ''],
        );
        return login;
      }

      return const LoginResponse(
        success: false,
        userName: '',
        role: '',
        isNew: false,
        tenantId: '',
      );
    } catch (e) {
      var errorMessage = 'Error al iniciar sesion';
      if (e is ErrorResponse) {
        errorMessage = e.message;
      }
      return LoginResponse(
        success: false,
        userName: '',
        role: '',
        isNew: false,
        tenantId: '',
        message: errorMessage,
      );
    }
  }

  Future<LoginResponse> register({
    required String storeName,
    required String ownerName,
    required String phone,
    required String email,
    required String pin,
  }) async {
    await Future.delayed(const Duration(milliseconds: Constants.uiDelayMs));

    try {
      final response = await ApiHelper().post<Map<String, dynamic>>(
        'api/v1/public/auth/register',
        data: {
          'storeName': storeName,
          'ownerName': ownerName,
          'phone': phone,
          'email': email,
          'pin': pin,
        },
      );

      if (response['ok'] == true && response['result'] != null) {
        final result = response['result'];
        final login = await _persistAuthResult(
          result: result,
          fallbackPhone: phone,
          fallbackName: ownerName,
          fallbackRole: 'OWNER',
        );
        final db = await DbHelper().database;
        await db.update(
          'users',
          {'pin_hash': pin},
          where: 'id = ?',
          whereArgs: [result['user']?['id']?.toString() ?? ''],
        );
        return login;
      }

      return const LoginResponse(
        success: false,
        userName: '',
        role: '',
        isNew: false,
        tenantId: '',
      );
    } catch (e) {
      var errorMessage = 'Error en el registro';
      if (e is ErrorResponse) {
        errorMessage = e.message;
      }
      return LoginResponse(
        success: false,
        userName: '',
        role: '',
        isNew: false,
        tenantId: '',
        message: errorMessage,
      );
    }
  }

  Future<bool> verifySession() async {
    await Future.delayed(const Duration(milliseconds: Constants.uiDelayMs));

    try {
      final response = await ApiHelper().get<Map<String, dynamic>>(
        'api/v1/user/init',
      );

      if (response['ok'] == true && response['result'] != null) {
        final result = response['result'] as Map<String, dynamic>;
        await _persistAuthResult(
          result: result,
          fallbackPhone: Constants.phoneNumber,
          fallbackName:
              Constants.nombre.isNotEmpty ? Constants.nombre : 'Usuario',
          fallbackRole: Constants.rol.isNotEmpty ? Constants.rol : 'OWNER',
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
