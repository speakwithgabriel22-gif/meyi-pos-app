class Supplier {
  final String id;
  final String tenantId;
  final String name;
  final String? contactName;
  final String phone;
  final String? category;
  final double totalDebt;
  final String? visitDay;
  final String? deliveryDay;
  final String? frequency;
  final bool isActive;
  final int regBorrado;
  final String createdAt;
  final String updatedAt;
  final int isDirty;
  final String? syncedAt;

  Supplier({
    required this.id,
    required this.tenantId,
    required this.name,
    this.contactName,
    required this.phone,
    this.category,
    this.totalDebt = 0.0,
    this.visitDay,
    this.deliveryDay,
    this.frequency,
    this.isActive = true,
    this.regBorrado = 1,
    required this.createdAt,
    required this.updatedAt,
    this.isDirty = 0,
    this.syncedAt,
  });

  bool get hasDebt => totalDebt > 0;

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] ?? '',
      tenantId: map['tenant_id'] ?? '',
      name: map['name'] ?? '',
      contactName: map['contact_name'],
      phone: map['phone'] ?? '',
      category: map['category'],
      totalDebt: (map['total_debt'] ?? 0.0).toDouble(),
      visitDay: map['visit_day'],
      deliveryDay: map['delivery_day'],
      frequency: map['frequency'],
      isActive: map['is_active'] == 1,
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
      'name': name,
      'contact_name': contactName,
      'phone': phone,
      'category': category,
      'total_debt': totalDebt,
      'visit_day': visitDay,
      'delivery_day': deliveryDay,
      'frequency': frequency,
      'is_active': isActive ? 1 : 0,
      'reg_borrado': regBorrado,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_dirty': isDirty,
      'synced_at': syncedAt,
    };
  }

  // ==== MÉTODOS PARA SINCRONIZACIÓN CON BACKEND ====
  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'],
      tenantId: json['tenant']?['id'] ?? '',
      name: json['name'] ?? '',
      contactName: json['contactName'],
      phone: json['phone'] ?? '',
      category: json['category'],
      totalDebt: (json['totalDebt'] ?? 0.0).toDouble(),
      visitDay: json['visitDay'],
      deliveryDay: json['deliveryDay'],
      frequency: json['frequency'],
      isActive: json['isActive'] ?? true,
      regBorrado: json['regBorrado'] ?? 1,
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      syncedAt: DateTime.now().toUtc().toIso8601String(),
      isDirty: 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant': {'id': tenantId},
      'name': name,
      'contactName': contactName,
      'phone': phone,
      'category': category,
      'visitDay': visitDay,
      'deliveryDay': deliveryDay,
      'frequency': frequency,
      'totalDebt': totalDebt,
      'isActive': isActive,
      'regBorrado': regBorrado,
    };
  }
  // ===============================================

  Supplier copyWith({
    String? name,
    String? phone,
    String? category,
    double? totalDebt,
    int? isDirty,
  }) {
    return Supplier(
      id: id,
      tenantId: tenantId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      category: category ?? this.category,
      totalDebt: totalDebt ?? this.totalDebt,
      visitDay: visitDay,
      deliveryDay: deliveryDay,
      frequency: frequency,
      isActive: isActive,
      regBorrado: regBorrado,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      isDirty: isDirty ?? this.isDirty,
    );
  }
}

class SupplierTransaction {
  final String id;
  final String tenantId;
  final String supplierId;
  final String type; // 'RECEPCION', 'PAGO'
  final String? cashSessionId;
  final double amount;
  final String? note;
  final int regBorrado;
  final String createdAt;
  final String updatedAt;
  final int isDirty;
  final String? syncedAt;

  SupplierTransaction({
    required this.id,
    required this.tenantId,
    required this.supplierId,
    required this.type,
    this.cashSessionId,
    required this.amount,
    this.note,
    this.regBorrado = 1,
    required this.createdAt,
    required this.updatedAt,
    this.isDirty = 0,
    this.syncedAt,
  });

  factory SupplierTransaction.fromMap(Map<String, dynamic> map) {
    return SupplierTransaction(
      id: map['id'] ?? '',
      tenantId: map['tenant_id'] ?? '',
      supplierId: map['supplier_id'] ?? '',
      type: map['type'] ?? 'PAGO',
      cashSessionId: map['cash_session_id'],
      amount: (map['amount'] ?? 0.0).toDouble(),
      note: map['note'],
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
      'supplier_id': supplierId,
      'type': type,
      'cash_session_id': cashSessionId,
      'amount': amount,
      'note': note,
      'reg_borrado': regBorrado,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_dirty': isDirty,
      'synced_at': syncedAt,
    };
  }

  // ==== MÉTODOS PARA SINCRONIZACIÓN ====
  factory SupplierTransaction.fromJson(Map<String, dynamic> json) {
    return SupplierTransaction(
      id: json['id'],
      tenantId: json['tenant']?['id'] ?? '',
      supplierId: json['supplier']?['id'] ?? '',
      type: json['type'] ?? 'PAYMENT',
      cashSessionId: json['cashSession']?['id'],
      amount: (json['amount'] ?? 0.0).toDouble(),
      note: json['note'],
      regBorrado: json['regBorrado'] ?? 1,
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      syncedAt: DateTime.now().toUtc().toIso8601String(),
      isDirty: 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant': {'id': tenantId},
      'supplier': {'id': supplierId},
      'cashSession': cashSessionId != null ? {'id': cashSessionId} : null,
      'type': type,
      'amount': amount,
      'note': note,
      'regBorrado': regBorrado,
    };
  }
  // ===============================================
}
