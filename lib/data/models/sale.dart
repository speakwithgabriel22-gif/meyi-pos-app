class Sale {
  final String id;
  final String tenantId;
  final String userId;
  final String cashSessionId;
  final String folio;
  final double total;
  final String paymentType;
  final int regBorrado;
  final String createdAt;
  final String updatedAt;
  final int isDirty;
  final String? syncedAt;
  final List<SaleItem>? items;

  Sale({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.cashSessionId,
    required this.folio,
    required this.total,
    required this.paymentType,
    this.regBorrado = 1,
    required this.createdAt,
    required this.updatedAt,
    this.isDirty = 0,
    this.syncedAt,
    this.items,
  });

  String get timeFormatted {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "--:--";
    }
  }

  String get summary {
    if (items == null || items!.isEmpty) return "Venta sin artículos";
    final firstItem = items!.first.productName;
    if (items!.length == 1) return firstItem;
    return "$firstItem + ${items!.length - 1} más";
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] ?? '',
      tenantId: map['tenant_id'] ?? '',
      userId: map['user_id'] ?? '',
      cashSessionId: map['cash_session_id'] ?? '',
      folio: map['folio'] ?? '',
      total: (map['total'] ?? 0.0).toDouble(),
      paymentType: map['payment_type'] ?? 'Efectivo',
      regBorrado: map['reg_borrado'] ?? 1,
      createdAt: map['created_at'] ?? '',
      updatedAt: map['updated_at'] ?? '',
      isDirty: map['is_dirty'] ?? 0,
      syncedAt: map['synced_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'user_id': userId,
      'cash_session_id': cashSessionId,
      'folio': folio,
      'total': total,
      'payment_type': paymentType, // ya debe ser 'CASH', 'CARD' o 'TRANSFER'
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  // ==== MÉTODOS PARA SINCRONIZACIÓN CON BACKEND ====
  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'],
      tenantId: json['tenant']?['id'] ?? '',
      userId: json['user']?['id'] ?? '',
      cashSessionId: json['cashSession']?['id'] ?? '',
      folio: json['folio'] ?? '',
      total: (json['total'] ?? 0.0).toDouble(),
      paymentType: json['paymentType'] ??
          'CASH', // Backend devuelve CASH, CARD, TRANSFER
      regBorrado: json['regBorrado'] ?? 1,
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      syncedAt: DateTime.now().toUtc().toIso8601String(),
      isDirty: 0,
      items: json['items'] != null
          ? (json['items'] as List).map((i) => SaleItem.fromJson(i)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    // Convertir de "Efectivo" -> "CASH" para el backend si es necesario (legacy db support)
    String getBackendPaymentType() {
      switch (paymentType.toUpperCase()) {
        case 'TARJETA':
        case 'CARD':
          return 'CARD';
        case 'TRANSFERENCIA':
        case 'TRANSFER':
          return 'TRANSFER';
        default:
          return 'CASH';
      }
    }

    return {
      'id': id,
      'tenant': {'id': tenantId},
      'user': {'id': userId},
      'cashSession': {'id': cashSessionId},
      'folio': folio,
      'total': total,
      'paymentType': getBackendPaymentType(),
      'regBorrado': regBorrado,
      'items': items?.map((i) => i.toJson()).toList() ?? [],
    };
  }
  // ===============================================
}

class SaleItem {
  final String? id;
  final String saleId;
  final String upc;
  final String productName;
  final String measurementUnit;
  final double ivaAmount;
  final double iepsAmount;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final int isDirty;
  final String? syncedAt;

  SaleItem({
    this.id,
    required this.saleId,
    required this.upc,
    required this.productName,
    this.measurementUnit = 'PZA',
    this.ivaAmount = 0.0,
    this.iepsAmount = 0.0,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.isDirty = 0,
    this.syncedAt,
  });

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'],
      saleId: map['sale_id'] ?? '',
      upc: map['upc'] ?? '',
      productName: map['product_name'] ?? '',
      measurementUnit: map['measurement_unit'] ?? 'PZA',
      ivaAmount: (map['iva_amount'] ?? 0.0).toDouble(),
      iepsAmount: (map['ieps_amount'] ?? 0.0).toDouble(),
      quantity: (map['quantity'] ?? 0.0).toDouble(),
      unitPrice: (map['unit_price'] ?? 0.0).toDouble(),
      subtotal: (map['subtotal'] ?? 0.0).toDouble(),
      isDirty: map['is_dirty'] ?? 0,
      syncedAt: map['synced_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'upc': upc,
      'product_name': productName,
      'measurement_unit': measurementUnit,
      'iva_amount': ivaAmount,
      'ieps_amount': iepsAmount,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
      'is_dirty': isDirty,
      'synced_at': syncedAt,
    };
  }

  // ==== MÉTODOS PARA SINCRONIZACIÓN ====
  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id'],
      saleId: json['sale']?['id'] ?? '',
      upc: json['upcCatalog']?['upc'] ?? '',
      productName: json['productName'] ?? '',
      measurementUnit: json['measurementUnit'] ?? 'PZA',
      ivaAmount: (json['ivaAmount'] ?? 0.0).toDouble(),
      iepsAmount: (json['iepsAmount'] ?? 0.0).toDouble(),
      quantity: (json['quantity'] ?? 0.0).toDouble(),
      unitPrice: (json['unitPrice'] ?? 0.0).toDouble(),
      subtotal: (json['subtotal'] ?? 0.0).toDouble(),
      syncedAt: DateTime.now().toUtc().toIso8601String(),
      isDirty: 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      // saleId se asume que lo mapea el backend o se asocia
      'upcCatalog': {'upc': upc},
      'productName': productName,
      'measurementUnit': measurementUnit,
      'ivaAmount': ivaAmount,
      'iepsAmount': iepsAmount,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'subtotal': subtotal,
    };
  }
}
