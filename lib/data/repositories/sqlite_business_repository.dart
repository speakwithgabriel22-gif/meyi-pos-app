import 'dart:async';
import 'package:comedor_app/data/services/local_folio_service.dart';
import 'package:comedor_app/data/services/sync_event_bus_service.dart';
import 'package:sqflite/sqflite.dart';
import '../local/db_helper.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/sale.dart';
import '../models/reception.dart';
import '../models/cash_movement.dart';
import 'business_repository.dart';
import '../../utils/constants.dart';
import '../../utils/uuid_generator.dart';

class SqliteBusinessRepository implements BusinessRepository {
  final DbHelper _dbHelper = DbHelper();
  String get _activeTenantId => Constants.activeTenantId ?? 'offline-tenant';

  final _inventoryController = StreamController<List<Product>>.broadcast();
  final _suppliersController = StreamController<List<Supplier>>.broadcast();
  final _salesController = StreamController<List<Sale>>.broadcast();
  final _cashMovementsController =
      StreamController<List<CashMovement>>.broadcast();
  final LocalFolioService _folioService = LocalFolioService(); // 注入

  SqliteBusinessRepository() {
    _initStreams();
  }

  void _initStreams() async {
    // Carga inicial para llenar los streams
    _refreshInventory();
    _refreshSuppliers();
    _refreshSales();
    _refreshCashMovements();
  }

  Future<void> _refreshInventory() async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
    SELECT sp.*, COALESCE(sp.name, uc.nombre) as name 
    FROM store_products sp 
    LEFT JOIN upc_catalog uc ON sp.upc = uc.upc 
    WHERE sp.reg_borrado = 1 AND sp.tenant_id = ?
  ''', [_activeTenantId]);
    final products = maps.map((m) => Product.fromMap(m)).toList();
    _inventoryController.add(products);
  }

  Future<void> _refreshSuppliers() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'suppliers',
      where: 'reg_borrado = 1 AND tenant_id = ?',
      whereArgs: [_activeTenantId],
    );
    final suppliers = maps.map((m) => Supplier.fromMap(m)).toList();
    _suppliersController.add(suppliers);
  }

  Future<void> _refreshSales() async {
    final db = await _dbHelper.database;
    final openSessionId = await _getOpenCashSessionId();

    if (openSessionId == null || openSessionId.isEmpty) {
      _salesController.add(const []);
      return;
    }

    final maps = await db.query(
      'sales',
      where: 'tenant_id = ? AND cash_session_id = ? AND reg_borrado = 1',
      whereArgs: [_activeTenantId, openSessionId],
      orderBy: 'created_at DESC',
    );

    List<Sale> sales = [];
    for (var m in maps) {
      final sale = Sale.fromMap(m);
      final itemMaps = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [sale.id],
      );
      final items = itemMaps.map((im) => SaleItem.fromMap(im)).toList();
      sales.add(Sale(
        id: sale.id,
        tenantId: sale.tenantId,
        userId: sale.userId,
        cashSessionId: sale.cashSessionId,
        folio: sale.folio,
        total: sale.total,
        paymentType: sale.paymentType,
        createdAt: sale.createdAt,
        updatedAt: sale.updatedAt,
        items: items,
      ));
    }

    _salesController.add(sales);
  }

  Future<void> _refreshCashMovements() async {
    final movements = await _loadTodayCashMovements();
    _cashMovementsController.add(movements);
  }

  Future<String?> _getOpenCashSessionId() async {
    final db = await _dbHelper.database;
    final openSession = await db.query(
      'cash_sessions',
      columns: ['id'],
      where: 'tenant_id = ? AND closed_at IS NULL',
      whereArgs: [_activeTenantId],
      limit: 1,
    );

    return openSession.isNotEmpty ? openSession.first['id']?.toString() : null;
  }

  Future<double> _getAvailableCashForSession(String sessionId) async {
    final db = await _dbHelper.database;
    final sessionMaps = await db.query(
      'cash_sessions',
      columns: ['initial_amount', 'cash_total'],
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (sessionMaps.isEmpty) return 0.0;

    // ✅ Agregar AND reg_borrado = 1 en ambas sumas
    final expensesResult = await db.rawQuery(
      'SELECT SUM(amount) as total FROM expenses WHERE cash_session_id = ? AND reg_borrado = 1 AND payment_method = "CASH"',
      [sessionId],
    );
    final supplierPaymentsResult = await db.rawQuery(
      'SELECT SUM(amount) as total FROM supplier_transactions WHERE cash_session_id = ? AND type = "PAYMENT" AND payment_method = "CASH" AND reg_borrado = 1',
      [sessionId],
    );

    final session = sessionMaps.first;
    final initialAmount =
        (session['initial_amount'] as num?)?.toDouble() ?? 0.0;
    final cashTotal = (session['cash_total'] as num?)?.toDouble() ?? 0.0;
    final expenses = (expensesResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final supplierPayments =
        (supplierPaymentsResult.first['total'] as num?)?.toDouble() ?? 0.0;

    return initialAmount + cashTotal - expenses - supplierPayments;
  }

  @override
  Stream<List<Product>> watchInventory() async* {
    final db = await _dbHelper.database;
    // Emitir solo inventario del tenant activo.
    final maps = await db.rawQuery('''
      SELECT sp.*, uc.nombre as name 
      FROM store_products sp 
      LEFT JOIN upc_catalog uc ON sp.upc = uc.upc 
      WHERE sp.reg_borrado = 1 AND sp.tenant_id = ?
    ''', [_activeTenantId]);
    yield maps.map((m) => Product.fromMap(m)).toList();

    // Y luego escuchar cambios vía el controller
    yield* _inventoryController.stream;
  }

  @override
  Future<void> updateStock(String upc, double delta) async {
    final db = await _dbHelper.database;
    await db.rawUpdate(
        'UPDATE store_products SET stock = stock + ?, is_dirty = 1, updated_at = ? WHERE upc = ? AND tenant_id = ?',
        [
          delta,
          DateTime.now().toUtc().toIso8601String(),
          upc,
          _activeTenantId
        ]);
    _refreshInventory();
    SyncEventBus().notifyDataChanged();
  }

  @override
  Future<void> addProduct(Product product) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      // 1. Asegurar que el UPC exista en el catálogo maestro
      await txn.insert(
        'upc_catalog',
        {
          'upc': product.upc,
          'nombre': product.name,
          'measurementUnit': product.measurementUnit ?? 'PZA',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Verificar si ya existe un producto con ese UPC para este tenant
      final existing = await txn.query(
        'store_products',
        columns: ['id'],
        where: 'tenant_id = ? AND upc = ?',
        whereArgs: [_activeTenantId, product.upc],
      );

      String productId;
      if (existing.isNotEmpty) {
        productId = existing.first['id'] as String;
      } else {
        // 🆕 Siempre generar UUID válido
        productId = (product.id != null &&
                product.id!.isNotEmpty &&
                !product.id!.startsWith('new-'))
            ? product.id!
            : UuidGenerator.generate();
      }

      // 3. Insertar o reemplazar
      final storeProductMap = {
        'id': productId,
        'tenant_id': _activeTenantId,
        'upc': product.upc,
        'price': product.price,
        'stock': product.stock,
        'min_stock': product.minStock,
        'cost_price': product.costPrice,
        'supplier_id': product.supplierId,
        'name':
            product.name.isNotEmpty ? product.name : 'Producto ${product.upc}',
        'measurement_unit': product.measurementUnit ?? 'PZA',
        'product_type': product.productType ?? 'STANDARD',
        'is_active': 1,
        'reg_borrado': 1,
        'created_at': existing.isEmpty
            ? now
            : (product.createdAt?.isNotEmpty == true ? product.createdAt : now),
        'updated_at': now,
        'is_dirty': 1,
      };

      await txn.insert(
        'store_products',
        storeProductMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    _refreshInventory();
    SyncEventBus().notifyDataChanged();
  }

  Future<void> removeProduct(String upc) async {
    final db = await _dbHelper.database;
    await db.rawUpdate(
      'UPDATE store_products SET reg_borrado = 0, is_dirty = 1, updated_at = ? WHERE upc = ? AND tenant_id = ?',
      [DateTime.now().toUtc().toIso8601String(), upc, _activeTenantId],
    );
    _refreshInventory();
    SyncEventBus().notifyDataChanged();
  }

  @override
  Future<Product?> findProductByUpc(String upc) async {
    final db = await _dbHelper.database;

    // 🔥 NIVEL 1: Tu Inventario (store_products + upc_catalog)
    // Usamos LEFT JOIN para encontrar productos locales aunque no estén en el catálogo maestro
    final maps = await db.rawQuery('''
      SELECT sp.*, COALESCE(sp.name, uc.nombre) as name 
      FROM store_products sp 
      LEFT JOIN upc_catalog uc ON sp.upc = uc.upc 
      WHERE sp.upc = ? AND sp.tenant_id = ? AND sp.reg_borrado = 1
    ''', [upc, _activeTenantId]);

    if (maps.isNotEmpty) return Product.fromMap(maps.first);

    // 🌍 NIVEL 2: El Maestro Global (upc_catalog)
    // Si no está en el inventario del usuario, buscamos en el catálogo masivo
    final catalog = await _dbHelper.findUpc(upc);
    if (catalog != null) {
      return Product(
        id: UuidGenerator.generate(),
        tenantId: _activeTenantId,
        upc: catalog.upc,
        name: catalog.nombre,
        price: 0.0, // Indicará a la UI que debe pedir el precio (Nivel 2)
        stock: 0.0,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );
    }

    // 🖊️ NIVEL 3: Productos "Misceláneos" o Manuales
    // Se devuelve null para que la UI abra el formulario en blanco
    return null;
  }

  @override
  Future<List<Product>> searchProducts(String query) async {
    final db = await _dbHelper.database;
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return [];

    // Frente 1: inventario local del usuario
    final localResults = await db.rawQuery('''
      SELECT sp.*, COALESCE(sp.name, uc.nombre) as name 
      FROM store_products sp 
      LEFT JOIN upc_catalog uc ON sp.upc = uc.upc 
      WHERE (
        LOWER(COALESCE(sp.name, uc.nombre)) LIKE LOWER(?)
        OR sp.upc LIKE ?
      ) 
      AND sp.tenant_id = ? 
      AND sp.reg_borrado = 1
      ORDER BY COALESCE(sp.name, uc.nombre) ASC
    ''', ['%$normalizedQuery%', '%$normalizedQuery%', _activeTenantId]);

    final localProducts = localResults.map((m) => Product.fromMap(m)).toList();
    final localUpcs = localProducts.map((p) => p.upc).toSet();

    // Frente 2: catálogo global, excluyendo lo que ya existe localmente
    final globalResults = await db.query(
      'upc_catalog',
      where: 'LOWER(nombre) LIKE LOWER(?) OR upc LIKE ?',
      whereArgs: ['%$normalizedQuery%', '%$normalizedQuery%'],
      orderBy: 'nombre ASC',
      limit: 20,
    );

    final globalProducts = globalResults
        .where((m) => !localUpcs.contains(m['upc']?.toString() ?? ''))
        .map(
          (m) => Product(
            id: UuidGenerator.generate(),
            tenantId: _activeTenantId,
            upc: m['upc']?.toString() ?? '',
            name: m['nombre']?.toString() ?? '',
            price: 0.0,
            stock: 0.0,
            createdAt: DateTime.now().toUtc().toIso8601String(),
            updatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        )
        .toList();

    return [...localProducts, ...globalProducts];
  }

  @override
  Stream<List<Supplier>> watchSuppliers() async* {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'suppliers',
      where: 'reg_borrado = 1 AND tenant_id = ?',
      whereArgs: [_activeTenantId],
    );
    yield maps.map((m) => Supplier.fromMap(m)).toList();
    yield* _suppliersController.stream;
  }

  @override
  Future<void> addSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    await db.insert(
      'suppliers',
      {...supplier.toMap(), 'is_dirty': 1},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _refreshSuppliers();

    // 🆕 Notificar al SyncBloc que hay cambios pendientes
    SyncEventBus().notifyDataChanged();
  }

  @override
  Future<void> paySupplierDebt(String supplierId, double amount) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final openSessionId = await _getOpenCashSessionId();

    // 1. Validar que haya una caja abierta
    if (openSessionId == null || openSessionId.isEmpty) {
      throw Exception('Abre una caja para pagar proveedores');
    }

    // 2. Validar que haya efectivo disponible
    final availableCash = await _getAvailableCashForSession(openSessionId);
    if (availableCash < amount) {
      throw Exception(
          'No hay efectivo suficiente en caja para pagar al proveedor');
    }

    await db.transaction((txn) async {
      // 3. Obtener deuda actual del proveedor (solo activos y del tenant correcto)
      final suppResult = await txn.query(
        'suppliers',
        columns: ['total_debt'],
        where: 'id = ? AND tenant_id = ? AND reg_borrado = 1',
        whereArgs: [supplierId, _activeTenantId],
      );

      if (suppResult.isEmpty) {
        throw Exception('Proveedor no encontrado o inactivo');
      }

      final currentDebt = (suppResult.first['total_debt'] as num).toDouble();

      // 4. Calcular nueva deuda (evitando valores negativos)
      final newDebt = (currentDebt - amount).clamp(0.0, double.infinity);

      // 5. Actualizar deuda del proveedor
      await txn.update(
        'suppliers',
        {
          'total_debt': newDebt,
          'is_dirty': 1,
          'updated_at': now,
        },
        where: 'id = ? AND tenant_id = ?',
        whereArgs: [supplierId, _activeTenantId],
      );

      // 6. Registrar la transacción en supplier_transactions
      await txn.insert('supplier_transactions', {
        'id': UuidGenerator.generate(),
        'tenant_id': _activeTenantId,
        'supplier_id': supplierId,
        'cash_session_id': openSessionId,
        'amount': amount,
        'payment_method': 'CASH',
        'type': 'PAYMENT',
        'created_at': now,
        'updated_at': now,
        'reg_borrado': 1,
        'is_dirty': 1,
      });

      // 🆕 CASCADA: Marcar la sesión de caja como sucia ya que el balance cambió
      await txn.update(
        'cash_sessions',
        {'is_dirty': 1},
        where: 'id = ?',
        whereArgs: [openSessionId],
      );
    });

    // 7. Refrescar streams para actualizar la UI
    _refreshSuppliers();
    _refreshCashMovements();
    SyncEventBus().notifyDataChanged();
  }

  @override
  Future<void> addSupplierDebt(String supplierId, double amount) async {
    final db = await _dbHelper.database;
    await db.rawUpdate(
        'UPDATE suppliers SET total_debt = total_debt + ?, is_dirty = 1, updated_at = ? WHERE id = ? AND tenant_id = ?',
        [
          amount,
          DateTime.now().toUtc().toIso8601String(),
          supplierId,
          _activeTenantId
        ]);
    _refreshSuppliers();
    SyncEventBus().notifyDataChanged();
  }

  @override
  Stream<List<Sale>> watchSalesHistory() async* {
    final db = await _dbHelper.database;
    final openSessionId = await _getOpenCashSessionId();

    if (openSessionId == null || openSessionId.isEmpty) {
      yield const [];
      yield* _salesController.stream;
      return;
    }

    final maps = await db.query(
      'sales',
      where: 'tenant_id = ? AND cash_session_id = ? AND reg_borrado = 1',
      whereArgs: [_activeTenantId, openSessionId],
      orderBy: 'created_at DESC',
    );

    List<Sale> sales = [];
    for (var m in maps) {
      final sale = Sale.fromMap(m);
      final itemMaps = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [sale.id],
      );
      final items = itemMaps.map((im) => SaleItem.fromMap(im)).toList();
      sales.add(Sale(
        id: sale.id,
        tenantId: sale.tenantId,
        userId: sale.userId,
        cashSessionId: sale.cashSessionId,
        folio: sale.folio,
        total: sale.total,
        paymentType: sale.paymentType,
        createdAt: sale.createdAt,
        updatedAt: sale.updatedAt,
        items: items,
      ));
    }

    yield sales;
    yield* _salesController.stream;
  }

  @override
  Stream<List<CashMovement>> watchCashMovements() async* {
    yield await _loadTodayCashMovements();
    yield* _cashMovementsController.stream;
  }

  @override
  Future<void> recordSale(Sale sale) async {
    final db = await _dbHelper.database;
    final folio = await _folioService.siguiente(_activeTenantId, 'SAL');

    await db.transaction((txn) async {
      // 1. Obtener ID de sesión activa directamente de la DB
      final List<Map<String, dynamic>> sessionMaps = await txn.query(
        'cash_sessions',
        columns: ['id'],
        where: 'tenant_id = ? AND closed_at IS NULL',
        whereArgs: [_activeTenantId],
        limit: 1,
      );

      if (sessionMaps.isEmpty) {
        throw Exception(
            'No hay una sesión de caja abierta para registrar la venta');
      }

      final sessionId = sessionMaps.first['id'] as String;

      // 2. Insertar cabecera de venta
      final saleId = (sale.id.isNotEmpty) ? sale.id : UuidGenerator.generate();

      await txn.insert('sales', {
        'id': saleId,
        'tenant_id': _activeTenantId,
        'user_id': Constants.userId,
        'cash_session_id': sessionId,
        'folio': folio,
        'total': sale.total,
        'payment_type': sale.paymentType,
        'reg_borrado': 1,
        'created_at': sale.createdAt,
        'updated_at': sale.updatedAt,
        'is_dirty': 1,
      });

      // 3. Insertar items y actualizar stock
      if (sale.items != null) {
        for (var item in sale.items!) {
          // 🆕 SIEMPRE generar un UUID nuevo para cada item
          // NUNCA usar el ID que viene del modelo porque podría ser inválido
          final itemId = UuidGenerator.generate();

          await txn.insert('sale_items', {
            'id': itemId, // ✅ UUID válido garantizado
            'sale_id': saleId,
            'upc': item.upc,
            'product_name': item.productName,
            'measurement_unit': item.measurementUnit,
            'iva_amount': item.ivaAmount ?? 0.0,
            'ieps_amount': item.iepsAmount ?? 0.0,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'subtotal': item.subtotal,
            'is_dirty': 1,
          });

          await txn.rawUpdate(
            'UPDATE store_products SET stock = stock - ?, is_dirty = 1, updated_at = ? WHERE upc = ? AND tenant_id = ?',
            [
              item.quantity,
              DateTime.now().toUtc().toIso8601String(),
              item.upc,
              _activeTenantId
            ],
          );
        }
      }

      // 4. Actualizar totales de la sesión de caja
      String columnToUpdate = 'cash_total';
      if (sale.paymentType == 'CARD') {
        columnToUpdate = 'card_total';
      } else if (sale.paymentType == 'TRANSFER') {
        columnToUpdate = 'transfer_total';
      }

      await txn.rawUpdate(
        'UPDATE cash_sessions SET total_sales = total_sales + ?, $columnToUpdate = $columnToUpdate + ?, is_dirty = 1 WHERE id = ? AND tenant_id = ?',
        [sale.total, sale.total, sessionId, _activeTenantId],
      );
    });

    _refreshSales();
    _refreshInventory();
    _refreshCashMovements();

    SyncEventBus().notifyDataChanged();
  }

  @override
  Future<void> recordReception(Reception reception) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Insertar la recepción como una transacción de proveedor (type = RECEPTION)
      await txn.insert('supplier_transactions', {
        'id': reception.id,
        'tenant_id': _activeTenantId,
        'supplier_id': reception.supplierId,
        'amount': reception.total,
        'payment_method': 'CASH',
        'type': 'RECEPTION',
        'note': reception.note,
        'reg_borrado': 1,
        'created_at': reception.createdAt,
        'updated_at': reception.updatedAt,
        'is_dirty': 1,
      });

      // 2. Procesar cada ítem recibido
      if (reception.items != null) {
        for (var it in reception.items!) {
          // 2.1 Guardar el detalle del ítem en reception_items
          await txn.insert('reception_items', {
            'id': it.id,
            'transaction_id': reception.id,
            'upc': it.upc,
            'product_name': it.productName,
            'quantity': it.quantity,
            'cost_price': it.costPrice,
            'subtotal': it.subtotal,
            'is_dirty': 1,
          });

          // 2.2 Verificar si el producto ya existe en el inventario de la tienda
          final existing = await txn.query(
            'store_products',
            columns: ['id', 'stock', 'cost_price', 'created_at'],
            where: 'upc = ? AND tenant_id = ? AND reg_borrado = 1',
            whereArgs: [it.upc, _activeTenantId],
          );

          if (existing.isEmpty) {
            // 2.3a NO EXISTE: Crear nuevo producto en el inventario
            final suggestedPrice =
                it.costPrice * 1.3; // Precio sugerido: costo + 30%
            final now = DateTime.now().toUtc().toIso8601String();

            await txn.insert('store_products', {
              'id': UuidGenerator.generate(),
              'tenant_id': _activeTenantId,
              'upc': it.upc,
              'price': suggestedPrice,
              'stock': it.quantity,
              'min_stock': 3.0,
              'cost_price': it.costPrice,
              'is_active': 1,
              'reg_borrado': 1,
              'created_at': now,
              'updated_at': now,
              'is_dirty': 1,
            });

            // También asegurar que el UPC esté en el catálogo maestro
            await txn.insert(
              'upc_catalog',
              {
                'upc': it.upc,
                'nombre': it.productName,
                'measurementUnit': 'PZA',
              },
              conflictAlgorithm:
                  ConflictAlgorithm.ignore, // Si ya existe, no hace nada
            );
          } else {
            // 2.3b YA EXISTE: Actualizar stock y costo del producto existente
            final currentStock = (existing.first['stock'] as num).toDouble();
            final newStock = currentStock + it.quantity;

            await txn.update(
              'store_products',
              {
                'stock': newStock,
                'cost_price': it.costPrice,
                'is_dirty': 1,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              },
              where: 'id = ? AND tenant_id = ?',
              whereArgs: [existing.first['id'], _activeTenantId],
            );
          }
        }
      }

      // 3. Incrementar la deuda del proveedor
      final suppResult = await txn.query(
        'suppliers',
        columns: ['total_debt'],
        where: 'id = ? AND tenant_id = ? AND reg_borrado = 1',
        whereArgs: [reception.supplierId, _activeTenantId],
      );

      if (suppResult.isNotEmpty) {
        final currentDebt = (suppResult.first['total_debt'] as num).toDouble();
        final newDebt = currentDebt + reception.total;

        await txn.update(
          'suppliers',
          {
            'total_debt': newDebt,
            'is_dirty': 1,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          where: 'id = ? AND tenant_id = ?',
          whereArgs: [reception.supplierId, _activeTenantId],
        );
      }
    });

    // 4. Refrescar los streams para que la UI refleje los cambios
    _refreshInventory();
    _refreshSuppliers();

    SyncEventBus().notifyDataChanged();
  }

  @override
  Future<Map<String, dynamic>> getTodayMetrics() async {
    final db = await _dbHelper.database;
    final openSessionId = await _getOpenCashSessionId();

    if (openSessionId == null || openSessionId.isEmpty) {
      return {
        'totalSales': 0.0,
        'avgTicket': 0.0,
        'cashTotal': 0.0,
        'cardTotal': 0.0,
        'transfTotal': 0.0,
        'yesterdayDelta': 0.0,
      };
    }

    final sales = await db.query(
      'sales',
      where: 'tenant_id = ? AND cash_session_id = ? AND reg_borrado = 1',
      whereArgs: [_activeTenantId, openSessionId],
    );

    double total = 0;
    double cash = 0;
    double card = 0;
    double transf = 0;

    for (var s in sales) {
      final amount = (s['total'] as num).toDouble();
      total += amount;
      final type = s['payment_type'] as String;
      if (type == 'CASH') {
        cash += amount;
      } else if (type == 'CARD') {
        card += amount;
      } else if (type == 'TRANSFER') {
        transf += amount;
      }
    }

    return {
      'totalSales': total,
      'avgTicket': sales.isEmpty ? 0 : total / sales.length,
      'cashTotal': cash,
      'cardTotal': card,
      'transfTotal': transf,
      'yesterdayDelta': 0.0,
    };
  }

  Future<List<CashMovement>> _loadTodayCashMovements() async {
    final db = await _dbHelper.database;
    final openSessionId = await _getOpenCashSessionId();

    if (openSessionId == null || openSessionId.isEmpty) {
      return const [];
    }

    // Ventas del turno actual (filtrado por tenant y sesión)
    final sales = await db.query(
      'sales',
      where: 'tenant_id = ? AND cash_session_id = ? AND reg_borrado = 1',
      whereArgs: [_activeTenantId, openSessionId],
      orderBy: 'created_at DESC',
    );

    // Gastos del turno actual
    final expenses = await db.query(
      'expenses',
      where: 'tenant_id = ? AND cash_session_id = ? AND reg_borrado = 1',
      whereArgs: [_activeTenantId, openSessionId],
      orderBy: 'created_at DESC',
    );

    // Pagos a proveedores del turno actual
    final supplierPayments = await db.rawQuery(
      '''
    SELECT st.*, s.name as supplier_name
    FROM supplier_transactions st
    LEFT JOIN suppliers s ON s.id = st.supplier_id AND s.tenant_id = st.tenant_id
    WHERE st.tenant_id = ?
      AND st.cash_session_id = ?
      AND st.type = 'PAYMENT'
      AND st.payment_method = 'CASH'
      AND st.reg_borrado = 1
    ORDER BY st.created_at DESC
    ''',
      [_activeTenantId, openSessionId],
    );

    final List<CashMovement> saleMovements = [];
    for (var sale in sales) {
      final saleId = sale['id']?.toString() ?? '';
      final itemMaps = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      saleMovements.add(CashMovement(
        id: saleId,
        kind: 'sale',
        title: sale['folio']?.toString().isNotEmpty == true
            ? 'Venta ${sale['folio']}'
            : 'Venta',
        subtitle: 'Cobro ${sale['payment_type'] ?? 'CASH'}',
        amount: (sale['total'] as num?)?.toDouble() ?? 0.0,
        affectsCash: (sale['payment_type'] ?? 'CASH') == 'CASH',
        isInflow: true,
        createdAt: sale['created_at']?.toString() ?? '',
        reference: sale['folio']?.toString() ?? '',
        items: itemMaps,
      ));
    }

    final movements = <CashMovement>[
      ...saleMovements,
      ...expenses.map(
        (expense) => CashMovement(
          id: expense['id']?.toString() ?? '',
          kind: 'expense',
          title: expense['description']?.toString().isNotEmpty == true
              ? expense['description'].toString()
              : (expense['category']?.toString().isNotEmpty == true
                  ? expense['category'].toString()
                  : 'Gasto operativo'),
          subtitle: 'Gasto ${expense['payment_method'] ?? 'CASH'}',
          amount: (expense['amount'] as num?)?.toDouble() ?? 0.0,
          affectsCash: (expense['payment_method'] ?? 'CASH') == 'CASH',
          isInflow: false,
          createdAt: expense['created_at']?.toString() ?? '',
        ),
      ),
      ...supplierPayments.map(
        (payment) => CashMovement(
          id: payment['id']?.toString() ?? '',
          kind: 'supplier_payment',
          title: 'Pago a ${payment['supplier_name'] ?? 'proveedor'}',
          subtitle: 'Salida de efectivo',
          amount: (payment['amount'] as num?)?.toDouble() ?? 0.0,
          affectsCash: true,
          isInflow: false,
          createdAt: payment['created_at']?.toString() ?? '',
        ),
      ),
    ];

    movements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return movements;
  }

  @override
  void reset() {
    // No reseteamos la base de datos real, pero podríamos limpiar streams si fuera necesario
  }
}
