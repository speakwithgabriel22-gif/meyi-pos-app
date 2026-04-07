import 'dart:async';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/sale.dart';
import '../models/reception.dart';

abstract class BusinessRepository {
  // Inventory
  Stream<List<Product>> watchInventory();
  Future<void> updateStock(String productId, int delta);
  Future<void> addProduct(Product product);
  Future<Product?> findProductByUpc(String upc); // Búsqueda de alta escala
  
  // Suppliers
  Stream<List<Supplier>> watchSuppliers();
  Future<void> addSupplier(Supplier supplier);
  Future<void> associateProduct(String supplierId, String productId);
  Future<void> paySupplierDebt(String supplierId, double amount);
  Future<void> addSupplierDebt(String supplierId, double amount);
  
  // Sales
  Stream<List<Sale>> watchSalesHistory();
  Future<void> recordSale(Sale sale);
  Future<void> recordReception(Reception reception);
  
  // Reports
  Future<Map<String, dynamic>> getTodayMetrics();
}

class MockBusinessRepository implements BusinessRepository {
  final _inventoryController = StreamController<List<Product>>.broadcast();
  final _suppliersController = StreamController<List<Supplier>>.broadcast();
  final _salesController = StreamController<List<Sale>>.broadcast();

  final List<Product> _products = [
    Product(upc: '7501055304721', name: 'Coca Cola 600ml', price: 18.50, stock: 2),
    Product(upc: '7501011115132', name: 'Sabritas Sal 45g', price: 16.00, stock: 15),
  ];

  // Simulación de Base de Datos de 1 Millón de UPCs (Sr. UX: Datos reales de México)
  final Map<String, String> _millionUpcDb = {
    '7501000612662': 'Bimbo Pan Blanco Grande 680g',
    '7501030405060': 'Leche Lala Entera 1L',
    '7501000111202': 'Marínela Gansito 50g',
    '7501000112469': 'Galletas Marías Gamesa 170g',
    '7501030456185': 'Yogurt Lala Fresa 220g',
    '7501055310884': 'Jarritos Tamarindo 600ml',
    '7501000623255': 'Barritas Fresa Bimbo 67g',
  };

  // Listado de proveedores con su logística de preventa (Pedido vs Entrega)
  final List<Supplier> _suppliers = [
    Supplier(
      id: '1', 
      name: 'Pepsico (Sabritas/Gamesa)', 
      phone: '8112345678', 
      category: 'Botanas y Galletas', 
      totalDebt: 3200.00,
      visitDay: 'Martes',
      deliveryDay: 'Miércoles',
      frequency: 'Semanal',
    ),
    Supplier(
      id: '2', 
      name: 'Bimbo S.A. de C.V.', 
      phone: '5551234567', 
      category: 'Panadería y Pastelería', 
      totalDebt: 1850.50,
      visitDay: 'Lunes y Jueves',
      deliveryDay: 'Inmediata',
      frequency: '2 veces por semana',
    ),
    Supplier(
      id: '3', 
      name: 'Sigma (Fud/Lala)', 
      phone: '8186754321', 
      category: 'Salchichonería y Lácteos', 
      totalDebt: 920.00,
      visitDay: 'Miércoles',
      deliveryDay: 'Miércoles',
      frequency: 'Semanal',
    ),
  ];
  
  final List<Sale> _sales = [];
  int _dailyFolioCount = 1;

  MockBusinessRepository() {
    _inventoryController.add(_products);
    _suppliersController.add(_suppliers);
    _salesController.add(_sales);
  }

  @override
  Stream<List<Product>> watchInventory() async* {
    yield List.from(_products);
    yield* _inventoryController.stream;
  }

  @override
  Future<Product?> findProductByUpc(String upc) async {
    // 1. Buscar en inventario local
    final local = _products.where((p) => p.upc == upc).toList();
    if (local.isNotEmpty) return local.first;

    // 2. Simular búsqueda en BD de 1 Millón (Sr. UX: Descubrimiento de productos)
    if (_millionUpcDb.containsKey(upc)) {
      return Product(
        upc: upc,
        name: _millionUpcDb[upc]!,
        price: 0, // Se pedirá al usuario en el formulario
        stock: 0,
      );
    }
    return null;
  }

  @override
  Future<void> updateStock(String productId, int delta) async {
    final idx = _products.indexWhere((p) => p.upc == productId);
    if (idx != -1) {
      final p = _products[idx];
      _products[idx] = p.copyWith(stock: (p.stock + delta).clamp(0, 999));
      _inventoryController.add(List.from(_products));
    }
  }

  @override
  Future<void> addProduct(Product product) async {
    // Evitar duplicados por UPC
    _products.removeWhere((p) => p.upc == product.upc);
    _products.add(product);
    _inventoryController.add(List.from(_products));
  }

  @override
  Stream<List<Supplier>> watchSuppliers() async* {
    yield List.from(_suppliers);
    yield* _suppliersController.stream;
  }

  @override
  Future<void> associateProduct(String supplierId, String productId) async {
    final idx = _suppliers.indexWhere((s) => s.id == supplierId);
    if (idx != -1) {
      final s = _suppliers[idx];
      if (!s.productIds.contains(productId)) {
        _suppliers[idx] = s.copyWith(productIds: [...s.productIds, productId]);
        _suppliersController.add(List.from(_suppliers));
      }
    }
  }

  @override
  Future<void> addSupplier(Supplier supplier) async {
    _suppliers.add(supplier);
    _suppliersController.add(List.from(_suppliers));
  }

  @override
  Future<void> paySupplierDebt(String supplierId, double amount) async {
    final idx = _suppliers.indexWhere((s) => s.id == supplierId);
    if (idx != -1) {
      final s = _suppliers[idx];
      _suppliers[idx] = s.copyWith(totalDebt: (s.totalDebt - amount).clamp(0, double.infinity));
      _suppliersController.add(List.from(_suppliers));
    }
  }

  @override
  Future<void> addSupplierDebt(String supplierId, double amount) async {
    final idx = _suppliers.indexWhere((s) => s.id == supplierId);
    if (idx != -1) {
      final s = _suppliers[idx];
      _suppliers[idx] = s.copyWith(totalDebt: s.totalDebt + amount);
      _suppliersController.add(List.from(_suppliers));
    }
  }

  @override
  Stream<List<Sale>> watchSalesHistory() async* {
    yield List.from(_sales);
    yield* _salesController.stream;
  }

  @override
  Future<void> recordSale(Sale sale) async {
    final folio = _generateFolio();
    final saleWithFolio = Sale(
      id: sale.id,
      folio: folio,
      timestamp: sale.timestamp,
      items: sale.items,
      total: sale.total,
      paymentType: sale.paymentType,
    );
    _sales.insert(0, saleWithFolio);
    _salesController.add(List.from(_sales));
    for (var it in sale.items) {
      await updateStock(it.productId, -it.quantity);
    }
  }

  @override
  Future<void> recordReception(Reception reception) async {
    // 1. Aumentar deuda del proveedor
    await addSupplierDebt(reception.supplierId, reception.total);

    // 2. Actualizar stock y precio de costo de cada producto
    for (var item in reception.items) {
      final idx = _products.indexWhere((p) => p.upc == item.upc);
      if (idx != -1) {
        final p = _products[idx];
        _products[idx] = p.copyWith(
          stock: p.stock + item.quantity,
          costPrice: item.costPrice,
        );
      } else {
        // Si el producto no estaba en inventario local, lo agregamos
        _products.add(Product(
          upc: item.upc,
          name: item.productName,
          price: item.costPrice * 1.3, // Sugerencia de precio +30%
          costPrice: item.costPrice,
          stock: item.quantity,
          supplierId: reception.supplierId,
        ));
      }
    }
    _inventoryController.add(List.from(_products));
  }

  String _generateFolio() {
    final now = DateTime.now();
    final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final folio = "V-$dateStr-${_dailyFolioCount.toString().padLeft(3, '0')}";
    _dailyFolioCount++;
    return folio;
  }

  @override
  Future<Map<String, dynamic>> getTodayMetrics() async {
    final today = DateTime.now();
    final todaySales = _sales.where((s) => 
      s.timestamp.year == today.year && s.timestamp.month == today.month && s.timestamp.day == today.day
    ).toList();
    final total = todaySales.fold(0.0, (sum, s) => sum + s.total);
    final cashTotal = todaySales.where((s) => s.paymentType == 'Efectivo').fold(0.0, (sum, s) => sum + s.total);
    final cardTotal = todaySales.where((s) => s.paymentType == 'Tarjeta').fold(0.0, (sum, s) => sum + s.total);
    final transfTotal = todaySales.where((s) => s.paymentType == 'Transferencia').fold(0.0, (sum, s) => sum + s.total);
    return {
      'totalSales': total,
      'avgTicket': todaySales.isEmpty ? 0 : total / todaySales.length,
      'cashTotal': cashTotal,
      'cardTotal': cardTotal,
      'transfTotal': transfTotal,
      'yesterdayDelta': 540.0,
    };
  }
}
