import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String? id;
  final String tenantId;
  final String upc;
  final String name;
  final double price;
  final double costPrice;
  final String? supplierId;
  final double stock;
  final double minStock;
  final String measurementUnit;
  final String productType; // STANDARD, WEIGHED, PREPARED, INTERNAL, SERVICE
  final bool isActive;
  final int isDirty;
  final String? syncedAt;
  final String? createdAt;
  final String? updatedAt;

  const Product({
    this.id,
    required this.tenantId,
    required this.upc,
    required this.name,
    required this.price,
    this.costPrice = 0.0,
    this.supplierId,
    this.stock = 0.0,
    this.minStock = 3.0,
    this.measurementUnit = 'PZA',
    this.productType = 'STANDARD',
    this.isActive = true,
    this.isDirty = 0,
    this.syncedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      tenantId: map['tenant_id'] ?? '',
      upc: map['upc'] ?? '',
      name: map['name'] ?? '', // Nota: El nombre suele venir del UpcCatalog en el Join
      price: (map['price'] ?? 0.0).toDouble(),
      costPrice: (map['cost_price'] ?? 0.0).toDouble(),
      supplierId: map['supplier_id'],
      stock: (map['stock'] ?? 0.0).toDouble(),
      minStock: (map['min_stock'] ?? 3.0).toDouble(),
      measurementUnit: map['measurement_unit'] ?? 'PZA',
      productType: map['product_type'] ?? 'STANDARD',
      isActive: map['is_active'] == 1,
      isDirty: map['is_dirty'] ?? 0,
      syncedAt: map['synced_at'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'upc': upc,
      'price': price,
      'cost_price': costPrice,
      'supplier_id': supplierId,
      'stock': stock,
      'min_stock': minStock,
      'measurement_unit': measurementUnit,
      'product_type': productType,
      'is_active': isActive ? 1 : 0,
      'is_dirty': isDirty,
      'synced_at': syncedAt,
      'created_at': createdAt ?? DateTime.now().toUtc().toIso8601String(),
      'updated_at': updatedAt ?? DateTime.now().toUtc().toIso8601String(),
    };
  }

  // ==== MÉTODOS PARA SINCRONIZACIÓN CON BACKEND ====
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      tenantId: json['tenant']?['id'] ?? '',
      upc: json['upcCatalog']?['upc'] ?? '',
      name: json['upcCatalog']?['nombre'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      costPrice: (json['costPrice'] ?? 0.0).toDouble(),
      supplierId: json['supplier']?['id'],
      stock: (json['stock'] ?? 0.0).toDouble(),
      minStock: (json['minStock'] ?? 3.0).toDouble(),
      measurementUnit: json['upcCatalog']?['measurementUnit'] ?? 'PZA',
      productType: json['productType'] ?? 'STANDARD',
      isActive: json['isActive'] ?? true,
      syncedAt: DateTime.now().toUtc().toIso8601String(),
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      isDirty: 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      // tenantId suele ir en el DTO/backend directamente o por contexto
      'tenantId': tenantId,
      'upcCatalog': {
        'upc': upc,
      },
      'price': price,
      'costPrice': costPrice,
      'supplierId': supplierId,
      'stock': stock,
      'minStock': minStock,
      'productType': productType,
      'isActive': isActive,
      'regBorrado': 1, // 1 es activo en tu base de datos
    };
  }
  // ===============================================

  Product copyWith({
    String? name,
    double? price,
    double? costPrice,
    String? supplierId,
    double? stock,
    double? minStock,
    String? productType,
    bool? isActive,
    int? isDirty,
  }) {
    return Product(
      id: id,
      tenantId: tenantId,
      upc: upc,
      name: name ?? this.name,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      supplierId: supplierId ?? this.supplierId,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      measurementUnit: measurementUnit,
      productType: productType ?? this.productType,
      isActive: isActive ?? this.isActive,
      isDirty: isDirty ?? this.isDirty,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  @override
  List<Object?> get props => [
        id, 
        tenantId, 
        upc, 
        name, 
        price, 
        costPrice, 
        supplierId, 
        stock, 
        minStock, 
        measurementUnit,
        productType,
        isActive, 
        isDirty,
        syncedAt
      ];
}
