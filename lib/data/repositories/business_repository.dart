import 'dart:async';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/sale.dart';
import '../models/reception.dart';
import '../models/cash_movement.dart';
import '../../utils/constants.dart';

abstract class BusinessRepository {
  // Inventory
  Stream<List<Product>> watchInventory();
  Future<void> updateStock(String productId, double delta);
  Future<void> addProduct(Product product);
  Future<Product?> findProductByUpc(String upc); // Búsqueda de alta escala
  Future<List<Product>> searchProducts(String query); // Búsqueda por nombre/UPC

  // Suppliers
  Stream<List<Supplier>> watchSuppliers();
  Future<void> addSupplier(Supplier supplier);
  Future<void> paySupplierDebt(String supplierId, double amount);
  Future<void> addSupplierDebt(String supplierId, double amount);

  // Sales
  Stream<List<Sale>> watchSalesHistory();
  Stream<List<CashMovement>> watchCashMovements();
  Future<void> recordSale(Sale sale);
  Future<void> recordReception(Reception reception);

  // Reports
  Future<Map<String, dynamic>> getTodayMetrics();
  // Reset (Para cierres de sesión)
  void reset();
}
