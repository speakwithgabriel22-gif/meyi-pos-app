import 'package:flutter/foundation.dart';
import '../../utils/api_helper.dart';
import '../local/db_helper.dart';

/// Servicio encargado de la sincronización de datos con el backend.
class SyncService {
  final ApiHelper _apiHelper = ApiHelper();
  final DbHelper _dbHelper = DbHelper();

  // ==========================================
  // 🏢 SUPPLIERS
  // ==========================================

  Future<bool> syncSuppliers({required String tenantId}) async {
    try {
      final dirtyRecords =
          await _dbHelper.getDirtyRecords('suppliers', tenantId);

      if (dirtyRecords.isEmpty) {
        debugPrint('📭 No hay suppliers pendientes para sincronizar');
        return true;
      }

      debugPrint('📤 Enviando ${dirtyRecords.length} suppliers al backend...');

      final response = await _apiHelper.post<Map<String, dynamic>>(
        'api/v1/sync/suppliers',
        data: {
          'tenantId': tenantId,
          'records': _cleanRecords(dirtyRecords),
        },
      );

      if (response['success'] == true) {
        final ids = dirtyRecords.map((r) => r['id'] as String).toList();
        await _dbHelper.markMultipleAsSynced('suppliers', ids);
        debugPrint(
            '✅ Suppliers sincronizados: ${response['processed']}/${response['total']}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error en syncSuppliers: $e');
      return false;
    }
  }

  // ==========================================
  // 💵 CASH SESSIONS
  // ==========================================

  Future<bool> syncCashSessions({required String tenantId}) async {
    try {
      final dirtyRecords =
          await _dbHelper.getDirtyRecords('cash_sessions', tenantId);

      if (dirtyRecords.isEmpty) {
        debugPrint('📭 No hay cash_sessions pendientes');
        return true;
      }

      debugPrint('📤 Enviando ${dirtyRecords.length} cash_sessions...');

      final response = await _apiHelper.post<Map<String, dynamic>>(
        'api/v1/sync/cash-sessions',
        data: {
          'tenantId': tenantId,
          'records': dirtyRecords.map((r) {
            final map = Map<String, dynamic>.from(r);
            map['opened_at'] = _toIso8601WithZ(map['opened_at']);
            map['closed_at'] =
                (map['closed_at'] == null || map['closed_at'] == '')
                    ? null
                    : _toIso8601WithZ(map['closed_at']);
            map.remove('is_dirty');
            map.remove('synced_at');
            return map;
          }).toList(),
        },
      );

      if (response['success'] == true) {
        final ids = dirtyRecords.map((r) => r['id'] as String).toList();
        await _dbHelper.markMultipleAsSynced('cash_sessions', ids);
        debugPrint(
            '✅ Cash sessions sincronizadas: ${response['processed']}/${response['total']}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error en syncCashSessions: $e');
      return false;
    }
  }

  // ==========================================
  // 🧾 EXPENSES
  // ==========================================

  Future<bool> syncExpenses({required String tenantId}) async {
    return await _syncTable('expenses', tenantId, 'api/v1/sync/expenses');
  }

  // ==========================================
  // 🚚 SUPPLIER TRANSACTIONS
  // ==========================================

  Future<bool> syncSupplierTransactions({required String tenantId}) async {
    return await _syncTable(
        'supplier_transactions', tenantId, 'api/v1/sync/supplier-transactions');
  }

  // ==========================================
  // 🛒 STORE PRODUCTS
  // ==========================================

  Future<bool> syncStoreProducts({required String tenantId}) async {
    return await _syncTable(
        'store_products', tenantId, 'api/v1/sync/store-products');
  }

  // ==========================================
  // 🏷️ REGISTRO FOLIOS
  // ==========================================

  Future<bool> syncRegistroFolios({required String tenantId}) async {
    return await _syncTable(
        'registro_folios', tenantId, 'api/v1/sync/registro-folios');
  }

  // ==========================================
  // 🛍️ SALES (con items incluidos)
  // ==========================================

  Future<bool> syncSales({required String tenantId}) async {
    try {
      final dirtyRecords = await _dbHelper.getDirtyRecords('sales', tenantId);

      if (dirtyRecords.isEmpty) {
        debugPrint('📭 No hay sales pendientes');
        return true;
      }

      debugPrint('📤 Enviando ${dirtyRecords.length} sales...');

      final db = await _dbHelper.database;
      final recordsWithItems = <Map<String, dynamic>>[];

      for (var sale in dirtyRecords) {
        final saleId = sale['id'] as String;

        // 🆕 Obtener items directamente con JOIN (más seguro)
        final items = await db.rawQuery(
          '''
        SELECT si.* FROM sale_items si
        WHERE si.sale_id = ? AND si.is_dirty = 1
        ''',
          [saleId],
        );

        final cleanSale = _cleanRecord(sale);
        cleanSale['items'] = items.map((item) => _cleanRecord(item)).toList();
        recordsWithItems.add(cleanSale);
      }

      final response = await _apiHelper.post<Map<String, dynamic>>(
        'api/v1/sync/sales',
        data: {
          'tenantId': tenantId,
          'records': recordsWithItems,
        },
      );

      // 🆕 Validación más estricta
      if (response['success'] == true && response['processed'] > 0) {
        final ids = dirtyRecords.map((r) => r['id'] as String).toList();
        await _dbHelper.markMultipleAsSynced('sales', ids);

        // 🆕 Marcar items como sincronizados
        for (var sale in dirtyRecords) {
          await db.rawUpdate(
            'UPDATE sale_items SET is_dirty = 0, synced_at = ? WHERE sale_id = ? AND is_dirty = 1',
            [DateTime.now().toUtc().toIso8601String(), sale['id']],
          );
        }

        debugPrint(
            '✅ Sales sincronizadas: ${response['processed']}/${response['total']}');
        return true;
      }

      debugPrint('⚠️ Sync sales no exitoso: ${response['message']}');
      return false;
    } catch (e) {
      debugPrint('❌ Error en syncSales: $e');
      return false;
    }
  }
  // ==========================================
  // 📦 RECEPTION ITEMS
  // ==========================================

  Future<bool> syncReceptionItems({required String tenantId}) async {
    return await _syncTable(
        'reception_items', tenantId, 'api/v1/sync/reception-items');
  }

  // ==========================================
  // 🔄 MÉTODOS AUXILIARES
  // ==========================================

  /// Método genérico para sincronizar una tabla simple
  Future<bool> _syncTable(
      String tableName, String tenantId, String endpoint) async {
    try {
      final dirtyRecords = await _dbHelper.getDirtyRecords(tableName, tenantId);

      if (dirtyRecords.isEmpty) {
        debugPrint('📭 No hay $tableName pendientes');
        return true;
      }

      debugPrint('📤 Enviando ${dirtyRecords.length} $tableName...');

      final response = await _apiHelper.post<Map<String, dynamic>>(
        endpoint,
        data: {
          'tenantId': tenantId,
          'records': _cleanRecords(dirtyRecords),
        },
      );

      if (response['success'] == true) {
        final ids = dirtyRecords.map((r) => r['id'] as String).toList();
        await _dbHelper.markMultipleAsSynced(tableName, ids);
        debugPrint(
            '✅ $tableName sincronizados: ${response['processed']}/${response['total']}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error en syncTable($tableName): $e');
      return false;
    }
  }

  /// Limpia una lista de registros (formatea fechas, elimina is_dirty y synced_at)
  List<Map<String, dynamic>> _cleanRecords(List<Map<String, dynamic>> records) {
    return records.map((r) => _cleanRecord(r)).toList();
  }

  /// Limpia un registro individual
  Map<String, dynamic> _cleanRecord(Map<String, dynamic> record) {
    final map = Map<String, dynamic>.from(record);

    if (map.containsKey('is_active')) {
      map['is_active'] = map['is_active'] == 1 ? true : false;
    }

    // Formatear fechas comunes
    if (map.containsKey('created_at'))
      map['created_at'] = _toIso8601WithZ(map['created_at']);
    if (map.containsKey('updated_at'))
      map['updated_at'] = _toIso8601WithZ(map['updated_at']);
    if (map.containsKey('opened_at'))
      map['opened_at'] = _toIso8601WithZ(map['opened_at']);

    // Manejar closed_at
    if (map.containsKey('closed_at')) {
      map['closed_at'] = (map['closed_at'] == null || map['closed_at'] == '')
          ? null
          : _toIso8601WithZ(map['closed_at']);
    }

    // 🆕 Formatear fecha de registro_folios (20260408 → 2026-04-08)
    if (map.containsKey('fecha') && map['fecha'] is String) {
      final fecha = map['fecha'] as String;
      if (fecha.length == 8 && !fecha.contains('-')) {
        map['fecha'] =
            '${fecha.substring(0, 4)}-${fecha.substring(4, 6)}-${fecha.substring(6, 8)}';
      }
    }

    // 🆕 Asegurar que name no sea null
    if (map.containsKey('name') && map['name'] == null) {
      map['name'] = 'Producto ${map['upc'] ?? 'desconocido'}';
    }

    // Eliminar campos de sincronización
    map.remove('is_dirty');
    map.remove('synced_at');

    return map;
  }

  /// Asegura que el string de fecha tenga el sufijo Z (UTC) para el backend
  String _toIso8601WithZ(dynamic date) {
    if (date == null) return '';
    final String dateStr = date.toString();
    if (dateStr.isEmpty) return '';
    if (dateStr.endsWith('Z')) return dateStr;
    if (dateStr.contains(RegExp(r'[+-]\d{2}(:?\d{2})?$'))) return dateStr;
    return '${dateStr}Z';
  }

  // ==========================================
  // 📋 SINCRONIZACIÓN COMPLETA
  // ==========================================

  /// Sincroniza TODAS las tablas en orden correcto (respeta dependencias FK)
  Future<Map<String, bool>> syncAll({required String tenantId}) async {
    final results = <String, bool>{};

    final tablesInOrder = [
      'suppliers',
      'cash_sessions',
      'store_products',
      'registro_folios',
      'expenses',
      'supplier_transactions',
      'sales',
      'reception_items',
    ];

    for (var table in tablesInOrder) {
      bool success;
      switch (table) {
        case 'suppliers':
          success = await syncSuppliers(tenantId: tenantId);
          break;
        case 'cash_sessions':
          success = await syncCashSessions(tenantId: tenantId);
          break;
        case 'store_products':
          success = await syncStoreProducts(tenantId: tenantId);
          break;
        case 'registro_folios':
          success = await syncRegistroFolios(tenantId: tenantId);
          break;
        case 'expenses':
          success = await syncExpenses(tenantId: tenantId);
          break;
        case 'supplier_transactions':
          success = await syncSupplierTransactions(tenantId: tenantId);
          break;
        case 'sales':
          success = await syncSales(tenantId: tenantId);
          break;
        case 'reception_items':
          success = await syncReceptionItems(tenantId: tenantId);
          break;
        default:
          success = false;
      }
      results[table] = success;
    }

    return results;
  }

  /// Mapea nombre de tabla a endpoint
  String getEndpointForTable(String tableName) {
    return switch (tableName) {
      'suppliers' => 'api/v1/sync/suppliers',
      'cash_sessions' => 'api/v1/sync/cash-sessions',
      'store_products' => 'api/v1/sync/store-products',
      'registro_folios' => 'api/v1/sync/registro-folios',
      'expenses' => 'api/v1/sync/expenses',
      'supplier_transactions' => 'api/v1/sync/supplier-transactions',
      'sales' => 'api/v1/sync/sales',
      'sale_items' => 'api/v1/sync/sale-items',
      'reception_items' => 'api/v1/sync/reception-items',
      _ => 'api/v1/sync/$tableName',
    };
  }
}
