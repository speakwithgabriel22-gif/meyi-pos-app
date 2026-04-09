class Expense {
  final String id;
  final String tenantId;
  final String cashSessionId;
  final String? category;
  final double amount;
  final String paymentMethod;
  final String? description;
  final String? note;
  final int regBorrado;
  final String createdAt;
  final String updatedAt;
  final int isDirty;
  final String? syncedAt;

  Expense({
    required this.id,
    required this.tenantId,
    required this.cashSessionId,
    this.category,
    required this.amount,
    this.paymentMethod = 'CASH',
    this.description,
    this.note,
    this.regBorrado = 1,
    required this.createdAt,
    required this.updatedAt,
    this.isDirty = 0,
    this.syncedAt,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] ?? '',
      tenantId: map['tenant_id'] ?? '',
      cashSessionId: map['cash_session_id'] ?? '',
      category: map['category'],
      amount: (map['amount'] ?? 0.0).toDouble(),
      paymentMethod: map['payment_method'] ?? 'CASH',
      description: map['description'],
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
      'cash_session_id': cashSessionId,
      'category': category,
      'amount': amount,
      'payment_method': paymentMethod,
      'description': description,
      'note': note,
      'reg_borrado': regBorrado,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_dirty': isDirty,
      'synced_at': syncedAt,
    };
  }

  // ==== MÉTODOS PARA SINCRONIZACIÓN CON BACKEND ====
  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      tenantId: json['tenant']?['id'] ?? '',
      cashSessionId: json['cashSession']?['id'] ?? '',
      category: json['category'],
      amount: (json['amount'] ?? 0.0).toDouble(),
      paymentMethod: json['paymentMethod'] ?? 'CASH',
      description: json['description'],
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
      'cashSession': {'id': cashSessionId},
      'category': category,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'description': description,
      'note': note,
      'regBorrado': regBorrado,
    };
  }
  // ===============================================

  String get timeFormatted {
    final dt = DateTime.parse(createdAt);
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
