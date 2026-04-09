import 'package:comedor_app/data/services/sync_event_bus_service.dart';

import '../local/db_helper.dart';
import '../../utils/constants.dart';
import '../../utils/uuid_generator.dart';

class CashService {
  final DbHelper _dbHelper = DbHelper();

  // ===============================================
  // 📊 CARGA INICIAL DEL DASHBOARD
  // ===============================================
  Future<Map<String, dynamic>> loadDashboard() async {
    await Future.delayed(const Duration(milliseconds: Constants.uiDelayMs));
    final db = await _dbHelper.database;

    try {
      // 1. Buscar sesión abierta para el tenant
      final List<Map<String, dynamic>> maps = await db.query(
        'cash_sessions',
        where: 'tenant_id = ? AND closed_at IS NULL',
        whereArgs: [Constants.tenantId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        final sessionMap = Map<String, dynamic>.from(maps.first);
        final sessionId = sessionMap['id'];

        // 2. Calcular Gastos Acumulados (Lógica Java)
        final double totalExpenses = await _sumExpenses(sessionId);

        // 3. Calcular Pagos a Proveedores (Lógica Java)
        final double supplierPayments = await _sumSupplierPayments(sessionId);

        // 4. Mapeo a CamelCase para compatibilidad con el BLoC
        final normalizedSession = {
          'id': sessionMap['id'],
          'initialAmount':
              (sessionMap['initial_amount'] as num?)?.toDouble() ?? 0.0,
          'totalSales': (sessionMap['total_sales'] as num?)?.toDouble() ?? 0.0,
          'cashTotal': (sessionMap['cash_total'] as num?)?.toDouble() ?? 0.0,
          'cardTotal': (sessionMap['card_total'] as num?)?.toDouble() ?? 0.0,
          'transferTotal':
              (sessionMap['transfer_total'] as num?)?.toDouble() ?? 0.0,
          'totalExpenses': totalExpenses,
          'supplierPayments': supplierPayments,
          'openedAt': sessionMap['opened_at'],
          'availableCash': (sessionMap['initial_amount'] ?? 0.0) +
              (sessionMap['cash_total'] ?? 0.0) -
              totalExpenses -
              supplierPayments,
        };

        return {
          'hasOpenCashSession': true,
          'cashSession': normalizedSession,
          'messages': []
        };
      }

      // Buscar la última sesión cerrada para mostrar resumen opcional
      final List<Map<String, dynamic>> lastMaps = await db.query(
        'cash_sessions',
        where: 'tenant_id = ? AND closed_at IS NOT NULL',
        whereArgs: [Constants.tenantId],
        orderBy: 'closed_at DESC',
        limit: 1,
      );

      Map<String, dynamic>? lastSession;
      if (lastMaps.isNotEmpty) {
        final last = lastMaps.first;
        lastSession = {
          'id': last['id'],
          'initialAmount': (last['initial_amount'] as num?)?.toDouble() ?? 0.0,
          'totalSales': (last['total_sales'] as num?)?.toDouble() ?? 0.0,
          'cashTotal': (last['cash_total'] as num?)?.toDouble() ?? 0.0,
          'openedAt': last['opened_at'],
          'closedAt': last['closed_at'],
        };
      }

      return {
        'hasOpenCashSession': false,
        'cashSession': null,
        'lastClosedSession': lastSession,
        'messages': ['No hay sesión de caja abierta']
      };
    } catch (e) {
      print('CashService.loadDashboard Offline Error: $e');
      return {
        'hasOpenCashSession': false,
        'cashSession': null,
        'messages': ['Error al cargar datos locales']
      };
    }
  }

  // ===============================================
  // 🔓 ABRIR CAJA
  // ===============================================
  Future<Map<String, dynamic>?> openCash(double initialAmount) async {
    final db = await _dbHelper.database;

    try {
      // 1. Validar sesión única INMEDIATAMENTE (Evita condición de carrera por clics rápidos)
      final existing = await db.query(
        'cash_sessions',
        where: 'tenant_id = ? AND closed_at IS NULL',
        whereArgs: [Constants.tenantId],
      );

      if (existing.isNotEmpty) {
        throw Exception('Ya existe una sesión de caja abierta');
      }

      // Delay visual solo después de validar la integridad
      await Future.delayed(const Duration(milliseconds: Constants.uiDelayMs));

      // 2. Crear sesión
      final sessionId = UuidGenerator.generate();
      final session = {
        'id': sessionId,
        'tenant_id': Constants.tenantId,
        'user_id': Constants.userId,
        'initial_amount': initialAmount,
        'opened_at': DateTime.now().toUtc().toIso8601String(),
        'is_dirty': 1,
      };

      await db.insert('cash_sessions', session);
      SyncEventBus().notifyDataChanged();

      // 3. Normalizar respuesta a camelCase para compatibilidad con el BLoC
      return {
        'id': session['id'],
        'initialAmount': session['initial_amount'],
        'totalSales': 0.0,
        'cashTotal': 0.0,
        'cardTotal': 0.0,
        'transferTotal': 0.0,
        'totalExpenses': 0.0,
        'openedAt': session['opened_at'],
      };
    } catch (e) {
      print('CashService.openCash Offline Error: $e');
      rethrow;
    }
  }

  // ===============================================
  // 🔒 CERRAR CAJA (CORTE)
  // ===============================================
  Future<Map<String, dynamic>?> closeCash(double actualCash) async {
    await Future.delayed(const Duration(milliseconds: Constants.uiDelayMs));
    final db = await _dbHelper.database;

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'cash_sessions',
        where: 'tenant_id = ? AND closed_at IS NULL',
        whereArgs: [Constants.tenantId],
        limit: 1,
      );

      if (maps.isEmpty) throw Exception('No hay sesión abierta para cerrar');

      final session = maps.first;
      final sessionId = session['id'];
      final now = DateTime.now().toUtc().toIso8601String();

      // Calcular Efectivo Esperado (Fórmula Java)
      final double totalExpenses = await _sumExpenses(sessionId);
      final double supplierPayments = await _sumSupplierPayments(sessionId);
      final double expectedCash =
          (session['initial_amount'] as num).toDouble() +
              (session['cash_total'] as num).toDouble() -
              totalExpenses -
              supplierPayments;

      final difference = actualCash - expectedCash;

      await db.update(
        'cash_sessions',
        {
          'closed_at': now,
          'is_dirty': 1,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      SyncEventBus().notifyDataChanged();

      return {
        'id': sessionId,
        'expectedCash': expectedCash,
        'actualCash': actualCash,
        'difference': difference,
        'supplierPayments': supplierPayments,
        'openedAt': session['opened_at'],
        'closedAt': now,
      };
    } catch (e) {
      print('CashService.closeCash Offline Error: $e');
      rethrow;
    }
  }

  // ===============================================
  // 📤 REGISTRAR GASTO
  // ===============================================
  Future<bool> addExpense({
    required String cashSessionId,
    required String category,
    required String description,
    required double amount,
    String? note,
    String paymentMethod = 'CASH',
  }) async {
    await Future.delayed(const Duration(milliseconds: Constants.uiDelayMs));
    final db = await _dbHelper.database;

    try {
      if (amount <= 0) throw Exception('El monto debe ser mayor a cero');

      // 1. Validar Efectivo Disponible (Lógica Java)
      if (paymentMethod == 'CASH') {
        final available = await getAvailableCash(cashSessionId);
        if (available < amount) {
          throw Exception(
              'No hay suficiente efectivo en caja (Disponible: \$$available)');
        }
      }

      final expenseId = UuidGenerator.generate();
      final now = DateTime.now().toUtc().toIso8601String();

      await db.insert('expenses', {
        'id': expenseId,
        'tenant_id': Constants.tenantId,
        'cash_session_id': cashSessionId,
        'category': category,
        'description': description,
        'amount': amount,
        'payment_method': paymentMethod,
        'note': note ?? '',
        'created_at': now,
        'updated_at': now,
        'is_dirty': 1,
      });

      await db.update(
        'cash_sessions',
        {'is_dirty': 1},
        where: 'id = ?',
        whereArgs: [cashSessionId],
      );

      SyncEventBus().notifyDataChanged();

      return true;
    } catch (e) {
      print('CashService.addExpense Offline Error: $e');
      rethrow;
    }
  }

  // ===============================================
  // 🧮 LÓGICA DE NEGOCIO (COMO EN JAVA)
  // ===============================================

  Future<double> getAvailableCash(String sessionId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cash_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    if (maps.isEmpty) return 0.0;

    final session = maps.first;
    final double totalExpenses = await _sumExpenses(sessionId);
    final double supplierPayments = await _sumSupplierPayments(sessionId);

    // Fondo + Ventas Cash - Gastos - Pagos Proveedor (Regla #4)
    return (session['initial_amount'] as num).toDouble() +
        (session['cash_total'] as num).toDouble() -
        totalExpenses -
        supplierPayments;
  }

  Future<double> _sumExpenses(String sessionId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM expenses WHERE cash_session_id = ? AND reg_borrado = 1 AND payment_method = "CASH"',
        [sessionId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> _sumSupplierPayments(String sessionId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM supplier_transactions WHERE cash_session_id = ? AND type = "PAYMENT" AND payment_method = "CASH"',
        [sessionId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<String?> get currentSessionId async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cash_sessions',
      columns: ['id'],
      where: 'tenant_id = ? AND closed_at IS NULL',
      whereArgs: [Constants.tenantId],
      limit: 1,
    );
    return maps.isNotEmpty ? maps.first['id']?.toString() : null;
  }

  void reset() {}
}
