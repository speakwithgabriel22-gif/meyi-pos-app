import 'dart:async';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Clase que mapea a la entidad UpcCatalog de Spring Boot
class UpcCatalog {
  final String upc;
  final String nombre;
  final String? marca;
  final String measurementUnit;

  UpcCatalog({
    required this.upc,
    required this.nombre,
    this.marca,
    this.measurementUnit = 'PZA',
  });

  factory UpcCatalog.fromMap(Map<String, dynamic> map) {
    return UpcCatalog(
      upc: map['upc']?.toString() ?? '',
      nombre: map['nombre'] ?? '',
      marca: map['marca'],
      measurementUnit: map['measurementUnit'] ?? 'PZA',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'upc': upc,
      'nombre': nombre,
      'marca': marca,
      'measurementUnit': measurementUnit,
    };
  }
}

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  Database? _database;
  Completer<Database>? _initCompleter;

  Future<Database> get database async {
    if (_database != null) return _database!;

    // Evitar múltiples inicializaciones concurrentes
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<Database>();

    try {
      final db = await _initDatabase();
      _database = db;
      _initCompleter!.complete(db);
    } catch (e) {
      _initCompleter!.completeError(e);
      rethrow;
    }

    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'meyisoft_offline.db');

    final exists = await databaseExists(path);

    if (!exists) {
      // Primera instalación: intentar copiar desde assets
      try {
        await Directory(dirname(path)).create(recursive: true);
        final ByteData data =
            await rootBundle.load('assets/db/meyisoft_offline.db');
        final List<int> bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
        print('✅ Base de datos copiada desde assets (catálogo UPC precargado)');
      } catch (e) {
        print('⚠️ No se pudo copiar BD desde assets: $e');
      }
    }

    // Abrir la base de datos
    final db = await openDatabase(
      path,
      version: 3,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute(
                "ALTER TABLE store_products ADD COLUMN product_type TEXT DEFAULT 'STANDARD'");
            print('✅ Migración a v2 exitosa: product_type agregado.');
          } catch (e) {
            print('⚠️ Error en migración a v2: $e');
          }
        }
        if (oldVersion < 3) {
          try {
            await db.execute(
                "ALTER TABLE store_products ADD COLUMN measurement_unit TEXT DEFAULT 'PZA'");
            print('✅ Migración a v3 exitosa: measurement_unit agregado.');
          } catch (e) {
            print('⚠️ Error en migración a v3: $e');
          }
        }
      },
    );

    // Verificar y crear tablas faltantes
    await _ensureAllTablesExist(db);

    // Verificar el catálogo UPC
    await _verifyUpcCatalog(db);

    return db;
  }

  /// Asegura que todas las tablas necesarias existan
  Future<void> _ensureAllTablesExist(Database db) async {
    // Verificar si existe una tabla clave (store_products)
    final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='store_products'");

    if (result.isEmpty) {
      print('🆕 Creando tablas de la aplicación...');
      await _createCoreTables(db);
      print('✅ Tablas creadas exitosamente');
    } else {
      print('📂 Tablas ya existentes, no es necesario crearlas');
    }
  }

  Future<void> _verifyUpcCatalog(Database db) async {
    try {
      final result =
          await db.rawQuery('SELECT COUNT(*) as count FROM upc_catalog');
      final count = result.first['count'] as int;
      print('📚 Catálogo UPC cargado: $count productos');
    } catch (e) {
      print('⚠️ Error verificando catálogo UPC: $e');
    }
  }

  Future<void> _createCoreTables(Database db) async {
    // TENANTS
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tenants (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT,
        plan_type TEXT,
        subscription_status TEXT DEFAULT 'TRIAL',
        trial_ends_at TEXT,
        is_active INTEGER DEFAULT 1,
        synced_at TEXT
      )
    ''');

    // USERS
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        full_name TEXT NOT NULL,
        phone TEXT NOT NULL,
        pin_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        is_active INTEGER DEFAULT 1
      )
    ''');

    // CASH SESSIONS
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_sessions (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        initial_amount REAL NOT NULL,
        total_sales REAL DEFAULT 0,
        cash_total REAL DEFAULT 0,
        card_total REAL DEFAULT 0,
        transfer_total REAL DEFAULT 0,
        opened_at TEXT NOT NULL,
        closed_at TEXT,
        is_dirty INTEGER DEFAULT 0,
        synced_at TEXT
      )
    ''');

    // 🆕 RESTRICT: Solo una sesión abierta (closed_at IS NULL) por tenant
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_one_open_session_per_tenant 
      ON cash_sessions (tenant_id) 
      WHERE closed_at IS NULL
    ''');

    // STORE PRODUCTS
    await db.execute('''
      CREATE TABLE IF NOT EXISTS store_products (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        upc TEXT NOT NULL,
        cost_price REAL,
        supplier_id TEXT,
        price REAL NOT NULL,
        name TEXT,
        stock REAL NOT NULL,
        min_stock REAL DEFAULT 3,
        measurement_unit TEXT DEFAULT 'PZA',
        product_type TEXT DEFAULT 'STANDARD',
        is_active INTEGER DEFAULT 1,
        reg_borrado INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_dirty INTEGER DEFAULT 0,
        synced_at TEXT,
        UNIQUE(tenant_id, upc)
      )
    ''');

    // SALES
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        cash_session_id TEXT NOT NULL,
        folio TEXT NOT NULL,
        total REAL NOT NULL,
        payment_type TEXT NOT NULL,
        reg_borrado INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_dirty INTEGER DEFAULT 0,
        synced_at TEXT
      )
    ''');

    // SALE ITEMS
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        upc TEXT NOT NULL,
        product_name TEXT NOT NULL,
        measurement_unit TEXT NOT NULL,
        iva_amount REAL DEFAULT 0,
        ieps_amount REAL DEFAULT 0,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        is_dirty INTEGER DEFAULT 0,
        synced_at TEXT
      )
    ''');

    // EXPENSES
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        cash_session_id TEXT,
        category TEXT,
        amount REAL NOT NULL,
        payment_method TEXT DEFAULT 'CASH',
        description TEXT,
        note TEXT,
        reg_borrado INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_dirty INTEGER DEFAULT 0,
        synced_at TEXT
      )
    ''');

    // SUPPLIERS
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        name TEXT NOT NULL,
        contact_name TEXT,
        phone TEXT,
        category TEXT,
        visit_day TEXT,
        delivery_day TEXT,
        frequency TEXT,
        total_debt REAL DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        reg_borrado INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_dirty INTEGER DEFAULT 0,
        synced_at TEXT
      )
    ''');

    // REGISTRO FOLIOS
    await db.execute('''
      CREATE TABLE IF NOT EXISTS registro_folios (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        tipo TEXT NOT NULL,
        fecha TEXT NOT NULL,
        ultimo_folio INTEGER NOT NULL,
        is_dirty INTEGER DEFAULT 0,
        synced_at TEXT
      )
    ''');

    // SUPPLIER TRANSACTIONS
    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_transactions (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        supplier_id TEXT NOT NULL,
        cash_session_id TEXT,
        amount REAL NOT NULL,
        payment_method TEXT DEFAULT 'CASH',
        type TEXT NOT NULL,
        note TEXT,
        reg_borrado INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_dirty INTEGER DEFAULT 0,
        synced_at TEXT
      )
    ''');

    // RECEPTION ITEMS
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reception_items (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL,
        upc TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        cost_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        is_dirty INTEGER DEFAULT 0,
        synced_at TEXT
      )
    ''');

    // SYNC LOG
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_log (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        action TEXT NOT NULL,
        status TEXT NOT NULL,
        error_message TEXT,
        attempted_at TEXT NOT NULL
      )
    ''');

    // SYNC STATE
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_state (
        tenant_id TEXT PRIMARY KEY,
        last_sync_at TEXT NOT NULL,
        last_pull_at TEXT
      )
    ''');
  }

  // ==========================================
  // 🛒 CATÁLOGO UNIVERSAL OFFLINE (UPC)
  // ==========================================

  Future<UpcCatalog?> findUpc(String upcCode) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'upc_catalog',
      where: 'upc = ?',
      whereArgs: [upcCode],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return UpcCatalog.fromMap(result.first);
    }
    return null;
  }

  Future<void> insertUpc(UpcCatalog upc) async {
    final db = await database;
    await db.insert(
      'upc_catalog',
      upc.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<UpcCatalog>> searchUpcCatalog(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'upc_catalog',
      where: 'upc LIKE ? OR LOWER(nombre) LIKE LOWER(?)',
      whereArgs: ['%$query%', '%$query%'],
      limit: 50,
    );
    return result.map((m) => UpcCatalog.fromMap(m)).toList();
  }

  // ... resto de métodos (getDirtyRecords, markAsSynced, etc.)
  // ==========================================
  // 🔄 MÉTODOS DE SINCRONIZACIÓN
  // ==========================================

  /// Obtiene todos los registros modificados localmente (is_dirty = 1)
  /// para una tabla y tenant específicos.
  Future<List<Map<String, dynamic>>> getDirtyRecords(
      String tableName, String tenantId) async {
    final db = await database;

    if (tableName == 'sale_items') {
      return await db.rawQuery(
        '''
      SELECT si.* FROM sale_items si
      INNER JOIN sales s ON si.sale_id = s.id
      WHERE s.tenant_id = ? AND si.is_dirty = 1
      ''',
        [tenantId],
      );
    }

    if (tableName == 'reception_items') {
      return await db.rawQuery(
        '''
      SELECT ri.* FROM reception_items ri
      INNER JOIN supplier_transactions st ON ri.transaction_id = st.id
      WHERE st.tenant_id = ? AND ri.is_dirty = 1
      ''',
        [tenantId],
      );
    }

    return await db.query(
      tableName,
      where: 'tenant_id = ? AND is_dirty = 1',
      whereArgs: [tenantId],
    );
  }

  /// Marca un registro como sincronizado (is_dirty = 0, synced_at = now)
  Future<void> markAsSynced(String tableName, String recordId) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'is_dirty': 0,
        'synced_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [recordId],
    );
  }

  /// Marca múltiples registros como sincronizados
  Future<void> markMultipleAsSynced(
      String tableName, List<String> recordIds) async {
    if (recordIds.isEmpty) return;

    final db = await database;
    final placeholders = recordIds.map((_) => '?').join(',');
    await db.rawUpdate(
      'UPDATE $tableName SET is_dirty = 0, synced_at = ? WHERE id IN ($placeholders)',
      [DateTime.now().toIso8601String(), ...recordIds],
    );
  }

  /// Inserta o actualiza un registro proveniente del servidor.
  /// Se asume que el mapa contiene todas las columnas necesarias.
  Future<void> upsertFromRemote(
      String tableName, Map<String, dynamic> data) async {
    final db = await database;
    final id = data['id'];
    if (id == null) return;

    // Aseguramos que is_dirty sea 0 y synced_at se establezca
    final cleanData = Map<String, dynamic>.from(data);
    cleanData['is_dirty'] = 0;
    cleanData['synced_at'] = DateTime.now().toIso8601String();

    await db.insert(
      tableName,
      cleanData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserta o actualiza múltiples registros desde el servidor
  Future<void> upsertMultipleFromRemote(
      String tableName, List<Map<String, dynamic>> records) async {
    final db = await database;
    final batch = db.batch();

    for (var data in records) {
      final id = data['id'];
      if (id == null) continue;

      final cleanData = Map<String, dynamic>.from(data);
      cleanData['is_dirty'] = 0;
      cleanData['synced_at'] = DateTime.now().toIso8601String();

      batch.insert(
        tableName,
        cleanData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Registra un intento de sincronización en sync_log
  Future<void> logSyncAttempt({
    required String id,
    required String tableName,
    required String recordId,
    required String action, // 'PUSH', 'PULL'
    required String status, // 'PENDING', 'SUCCESS', 'FAILED'
    String? errorMessage,
  }) async {
    final db = await database;
    await db.insert(
      'sync_log',
      {
        'id': id,
        'table_name': tableName,
        'record_id': recordId,
        'action': action,
        'status': status,
        'error_message': errorMessage,
        'attempted_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obtiene los logs de sincronización pendientes o fallidos
  Future<List<Map<String, dynamic>>> getPendingSyncLogs() async {
    final db = await database;
    return await db.query(
      'sync_log',
      where: 'status IN (?, ?)',
      whereArgs: ['PENDING', 'FAILED'],
      orderBy: 'attempted_at ASC',
    );
  }

  /// Actualiza el estado de un log de sincronización
  Future<void> updateSyncLogStatus({
    required String id,
    required String status,
    String? errorMessage,
  }) async {
    final db = await database;
    await db.update(
      'sync_log',
      {
        'status': status,
        'error_message': errorMessage,
        'attempted_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Elimina logs de sincronización exitosos más antiguos que cierta fecha
  Future<void> cleanupOldSyncLogs({int daysToKeep = 7}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    await db.delete(
      'sync_log',
      where: 'status = ? AND attempted_at < ?',
      whereArgs: ['SUCCESS', cutoffDate.toIso8601String()],
    );
  }

  /// Actualiza la marca de tiempo de última sincronización para un tenant.
  Future<void> updateLastSync(String tenantId, {bool isPull = false}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'sync_state',
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
    );

    if (existing.isEmpty) {
      await db.insert('sync_state', {
        'tenant_id': tenantId,
        'last_sync_at': now,
        'last_pull_at': isPull ? now : null,
      });
    } else {
      final updates = <String, dynamic>{'last_sync_at': now};
      if (isPull) updates['last_pull_at'] = now;
      await db.update(
        'sync_state',
        updates,
        where: 'tenant_id = ?',
        whereArgs: [tenantId],
      );
    }
  }

  /// Obtiene la última fecha de sincronización (pull) para un tenant.
  Future<DateTime?> getLastPullTime(String tenantId) async {
    final db = await database;
    final result = await db.query(
      'sync_state',
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
    );

    if (result.isNotEmpty && result.first['last_pull_at'] != null) {
      return DateTime.parse(result.first['last_pull_at'] as String);
    }
    return null;
  }

  /// Obtiene la última fecha de sincronización (push) para un tenant.
  Future<DateTime?> getLastPushTime(String tenantId) async {
    final db = await database;
    final result = await db.query(
      'sync_state',
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
    );

    if (result.isNotEmpty && result.first['last_sync_at'] != null) {
      return DateTime.parse(result.first['last_sync_at'] as String);
    }
    return null;
  }

  /// Obtiene el estado completo de sincronización para un tenant
  Future<Map<String, dynamic>?> getSyncState(String tenantId) async {
    final db = await database;
    final result = await db.query(
      'sync_state',
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  /// Elimina lógicamente un registro (reg_borrado = 0) en tablas que lo soportan.
  Future<void> softDelete(String tableName, String id) async {
    final db = await database;

    // Verificar si la tabla tiene columna reg_borrado
    final columns = await db.rawQuery("PRAGMA table_info('$tableName')");
    final hasRegBorrado = columns.any((col) => col['name'] == 'reg_borrado');

    if (hasRegBorrado) {
      await db.update(
        tableName,
        {
          'reg_borrado': 0,
          'is_dirty': 1,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      // Si no tiene, borrado físico (poco recomendado)
      await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
    }
  }

  /// Elimina lógicamente múltiples registros
  Future<void> softDeleteMultiple(String tableName, List<String> ids) async {
    if (ids.isEmpty) return;

    final db = await database;
    final columns = await db.rawQuery("PRAGMA table_info('$tableName')");
    final hasRegBorrado = columns.any((col) => col['name'] == 'reg_borrado');

    final placeholders = ids.map((_) => '?').join(',');

    if (hasRegBorrado) {
      await db.rawUpdate(
        'UPDATE $tableName SET reg_borrado = 0, is_dirty = 1, updated_at = ? WHERE id IN ($placeholders)',
        [DateTime.now().toIso8601String(), ...ids],
      );
    } else {
      await db.rawDelete(
        'DELETE FROM $tableName WHERE id IN ($placeholders)',
        ids,
      );
    }
  }

  // ==========================================
  // 🧩 MÉTODOS DE CONVENIENCIA PARA SINCRONIZACIÓN
  // ==========================================

  /// Obtiene todas las tablas que participan en la sincronización.
  List<String> getSyncTables() {
    return [
      'tenants',
      'users',
      'cash_sessions',
      'store_products',
      'sales',
      'sale_items',
      'expenses',
      'suppliers',
      'registro_folios',
      'supplier_transactions',
      'reception_items',
    ];
  }

  /// Obtiene el conteo de registros pendientes de sincronizar por tabla
  /// Obtiene el conteo de registros pendientes de sincronizar por tabla
  /// SOLO para tablas que tienen columnas tenant_id e is_dirty
  Future<Map<String, int>> getDirtyCounts(String tenantId) async {
    final db = await database;
    final result = <String, int>{};

    // 🆕 Solo tablas que TIENEN tenant_id e is_dirty
    final syncableTables = [
      'suppliers',
      'cash_sessions',
      'store_products',
      'registro_folios',
      'sales',
      'expenses',
      'supplier_transactions',
      // 'sale_items' y 'reception_items' no tienen tenant_id directo
    ];

    for (var table in syncableTables) {
      try {
        final count = Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(*) FROM $table WHERE tenant_id = ? AND is_dirty = 1',
                [tenantId],
              ),
            ) ??
            0;
        result[table] = count;
      } catch (e) {
        debugPrint('⚠️ Error consultando $table: $e');
        result[table] = 0;
      }
    }

    // 🆕 Para sale_items y reception_items, contar a través de su tabla padre
    try {
      // sale_items: contar via JOIN con sales
      final saleItemsCount = Sqflite.firstIntValue(
            await db.rawQuery(
              '''
            SELECT COUNT(*) FROM sale_items si
            INNER JOIN sales s ON si.sale_id = s.id
            WHERE s.tenant_id = ? AND si.is_dirty = 1
            ''',
              [tenantId],
            ),
          ) ??
          0;
      result['sale_items'] = saleItemsCount;
    } catch (e) {
      debugPrint('⚠️ Error consultando sale_items: $e');
      result['sale_items'] = 0;
    }

    try {
      // reception_items: contar via JOIN con supplier_transactions
      final receptionItemsCount = Sqflite.firstIntValue(
            await db.rawQuery(
              '''
            SELECT COUNT(*) FROM reception_items ri
            INNER JOIN supplier_transactions st ON ri.transaction_id = st.id
            WHERE st.tenant_id = ? AND ri.is_dirty = 1
            ''',
              [tenantId],
            ),
          ) ??
          0;
      result['reception_items'] = receptionItemsCount;
    } catch (e) {
      debugPrint('⚠️ Error consultando reception_items: $e');
      result['reception_items'] = 0;
    }

    return result;
  }

  /// Verifica si hay registros pendientes de sincronizar
  Future<bool> hasDirtyRecords(String tenantId) async {
    final counts = await getDirtyCounts(tenantId);
    return counts.values.any((count) => count > 0);
  }

  /// Prepara un mapa de datos de una venta con sus items para enviar al backend.
  Future<Map<String, dynamic>> buildSalePayload(String saleId) async {
    final db = await database;

    final sale = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [saleId],
    );

    if (sale.isEmpty) throw Exception('Venta no encontrada');

    final items = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );

    return {
      'sale': sale.first,
      'items': items,
    };
  }

  /// Prepara un mapa de datos de una recepción con sus items para enviar al backend.
  Future<Map<String, dynamic>> buildReceptionPayload(String receptionId) async {
    final db = await database;

    final reception = await db.query(
      'supplier_transactions',
      where: 'id = ? AND type = ?',
      whereArgs: [receptionId, 'RECEPTION'],
    );

    if (reception.isEmpty) throw Exception('Recepción no encontrada');

    final items = await db.query(
      'reception_items',
      where: 'transaction_id = ?',
      whereArgs: [receptionId],
    );

    return {
      'reception': reception.first,
      'items': items,
    };
  }

  // ==========================================
  // 🧹 MANTENIMIENTO Y UTILIDADES
  // ==========================================

  /// Cierra la conexión a la base de datos
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _initCompleter = null;
    }
  }

  /// Elimina y recrea la base de datos (útil para desarrollo)
  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'meyisoft_offline.db');

    await close();

    if (await databaseExists(path)) {
      await deleteDatabase(path);
      print('🗑️ Base de datos eliminada');
    }

    _database = null;
    _initCompleter = null;
  }

  /// Obtiene el tamaño de la base de datos en bytes
  Future<int> getDatabaseSize() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'meyisoft_offline.db');

    if (await databaseExists(path)) {
      return await File(path).length();
    }
    return 0;
  }

  /// Ejecuta VACUUM para optimizar la base de datos
  Future<void> vacuum() async {
    final db = await database;
    await db.rawQuery('VACUUM');
    print('✅ VACUUM ejecutado - Base de datos optimizada');
  }

  /// Verifica la integridad de la base de datos
  Future<bool> checkIntegrity() async {
    final db = await database;
    final result = await db.rawQuery('PRAGMA integrity_check');
    return result.first.values.first == 'ok';
  }

  /// Obtiene información de todas las tablas
  Future<Map<String, int>> getTableRowCounts() async {
    final db = await database;
    final result = <String, int>{};

    final tables =
        await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");

    for (var table in tables) {
      final tableName = table['name'] as String;
      final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $tableName'),
          ) ??
          0;
      result[tableName] = count;
    }

    return result;
  }

  /// Exporta la base de datos a un archivo (para debug)
  Future<String> exportDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'meyisoft_offline.db');

    final exportPath = join(await getDatabasesPath(),
        'export_${DateTime.now().millisecondsSinceEpoch}.db');
    await File(path).copy(exportPath);

    print('✅ Base de datos exportada a: $exportPath');
    return exportPath;
  }

// Métodos de sincronización
  Future<List<Map<String, dynamic>>> getDirtySuppliers(String tenantId) async {
    final db = await database;
    return await db.query(
      'suppliers',
      where: 'tenant_id = ? AND is_dirty = 1',
      whereArgs: [tenantId],
    );
  }

  Future<void> markSuppliersAsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = ids.map((_) => '?').join(',');
    await db.rawUpdate(
      'UPDATE suppliers SET is_dirty = 0, synced_at = ? WHERE id IN ($placeholders)',
      [DateTime.now().toIso8601String(), ...ids],
    );
  }
}
