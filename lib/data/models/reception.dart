import 'package:equatable/equatable.dart';

class Reception extends Equatable {
  final String id;
  final String tenantId;
  final String supplierId;
  final String createdAt;
  final String updatedAt;
  final List<ReceptionItem>? items;
  final double total;
  final String? note;
  final int regBorrado;
  final int isDirty;
  final String? syncedAt;

  const Reception({
    required this.id,
    required this.tenantId,
    required this.supplierId,
    required this.createdAt,
    required this.updatedAt,
    this.items,
    required this.total,
    this.note,
    this.regBorrado = 1,
    this.isDirty = 0,
    this.syncedAt,
  });

  factory Reception.fromMap(Map<String, dynamic> map) {
    return Reception(
      id: map['id'] ?? '',
      tenantId: map['tenant_id'] ?? '',
      supplierId: map['supplier_id'] ?? '',
      createdAt: map['created_at'] ?? '',
      updatedAt: map['updated_at'] ?? '',
      total: (map['amount'] ?? 0.0).toDouble(), // ← Corregido
      note: map['note'],
      regBorrado: map['reg_borrado'] ?? 1,
      isDirty: map['is_dirty'] ?? 0,
      syncedAt: map['synced_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'supplier_id': supplierId,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'amount': total, // ← Corregido
      'type': 'RECEPTION', // ← Agregado para supplier_transactions
      'note': note,
      'reg_borrado': regBorrado,
      'is_dirty': isDirty,
      'synced_at': syncedAt,
    };
  }

  factory Reception.fromJson(Map<String, dynamic> json) {
    return Reception(
      id: json['id'] ?? '',
      tenantId: json['tenantId'] ?? json['tenant']?['id'] ?? '',
      supplierId: json['supplierId'] ?? json['supplier']?['id'] ?? '',
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      total: (json['amount'] ?? 0.0).toDouble(),
      note: json['note'],
      regBorrado: json['regBorrado'] ?? 1,
      syncedAt: json['syncedAt'], // ← No forzar fecha actual
      isDirty: 0,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((i) => ReceptionItem.fromJson(i))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'supplierId': supplierId,
      'type': 'RECEPTION',
      'amount': total,
      'note': note,
      'regBorrado': regBorrado,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'items': items?.map((i) => i.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        supplierId,
        createdAt,
        updatedAt,
        items,
        total,
        note,
        regBorrado,
        isDirty
      ];
}

class ReceptionItem extends Equatable {
  final String id;
  final String transactionId;
  final String upc;
  final String productName;
  final double quantity;
  final double costPrice;
  final double subtotal;
  final int isDirty;
  final String? syncedAt;

  const ReceptionItem({
    required this.id,
    required this.transactionId,
    required this.upc,
    required this.productName,
    required this.quantity,
    required this.costPrice,
    required this.subtotal,
    this.isDirty = 0,
    this.syncedAt,
  });

  factory ReceptionItem.fromMap(Map<String, dynamic> map) {
    return ReceptionItem(
      id: map['id'] ?? '',
      transactionId: map['transaction_id'] ?? '',
      upc: map['upc'] ?? '',
      productName: map['product_name'] ?? '',
      quantity: (map['quantity'] ?? 0.0).toDouble(),
      costPrice: (map['cost_price'] ?? 0.0).toDouble(), // ← Sin espacio
      subtotal: (map['subtotal'] ?? 0.0).toDouble(),
      isDirty: map['is_dirty'] ?? 0,
      syncedAt: map['synced_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'upc': upc,
      'product_name': productName,
      'quantity': quantity,
      'cost_price': costPrice, // ← Sin espacio
      'subtotal': subtotal,
      'is_dirty': isDirty,
      'synced_at': syncedAt,
    };
  }

  factory ReceptionItem.fromJson(Map<String, dynamic> json) {
    return ReceptionItem(
      id: json['id'] ?? '',
      transactionId: json['transactionId'] ?? json['transaction']?['id'] ?? '',
      upc: json['upc'] ?? json['upcCatalog']?['upc'] ?? '',
      productName: json['productName'] ?? json['upcCatalog']?['nombre'] ?? '',
      quantity: (json['quantity'] ?? 0.0).toDouble(),
      costPrice: (json['costPrice'] ?? 0.0).toDouble(),
      subtotal: (json['subtotal'] ?? 0.0).toDouble(),
      syncedAt: json['syncedAt'],
      isDirty: 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'upc': upc,
      'quantity': quantity,
      'costPrice': costPrice,
      'subtotal': subtotal,
      // Si el backend espera el objeto upcCatalog:
      // 'upcCatalog': {'upc': upc},
    };
  }

  @override
  List<Object?> get props => [
        id,
        transactionId,
        upc,
        productName,
        quantity,
        costPrice,
        subtotal,
        isDirty,
        syncedAt
      ];
}
