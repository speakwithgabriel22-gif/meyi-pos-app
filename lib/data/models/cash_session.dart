class CashSession {
  final String id;
  final String tenantId;
  final String userId;
  final double initialAmount;
  final double totalSales;
  final double cashTotal;
  final double cardTotal;
  final double transferTotal;
  final String openedAt;
  final String? closedAt;
  final int isDirty;
  final String? syncedAt;

  CashSession({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.initialAmount,
    this.totalSales = 0.0,
    this.cashTotal = 0.0,
    this.cardTotal = 0.0,
    this.transferTotal = 0.0,
    required this.openedAt,
    this.closedAt,
    this.isDirty = 0,
    this.syncedAt,
  });

  factory CashSession.fromMap(Map<String, dynamic> map) {
    return CashSession(
      id: map['id'] ?? '',
      tenantId: map['tenant_id'] ?? '',
      userId: map['user_id'] ?? '',
      initialAmount: (map['initial_amount'] ?? 0.0).toDouble(),
      totalSales: (map['total_sales'] ?? 0.0).toDouble(),
      cashTotal: (map['cash_total'] ?? 0.0).toDouble(),
      cardTotal: (map['card_total'] ?? 0.0).toDouble(),
      transferTotal: (map['transfer_total'] ?? 0.0).toDouble(),
      openedAt: map['opened_at'] ?? '',
      closedAt: map['closed_at'],
      isDirty: map['is_dirty'] ?? 0,
      syncedAt: map['synced_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'user_id': userId,
      'initial_amount': initialAmount,
      'total_sales': totalSales,
      'cash_total': cashTotal,
      'card_total': cardTotal,
      'transfer_total': transferTotal,
      'opened_at': openedAt,
      'closed_at': closedAt,
      'is_dirty': isDirty,
      'synced_at': syncedAt,
    };
  }

  // ==== MÉTODOS PARA SINCRONIZACIÓN CON BACKEND ====
  factory CashSession.fromJson(Map<String, dynamic> json) {
    return CashSession(
      id: json['id'],
      tenantId: json['tenant']?['id'] ?? '',
      userId: json['user']?['id'] ?? '',
      initialAmount: (json['initialAmount'] ?? 0.0).toDouble(),
      totalSales: (json['totalSales'] ?? 0.0).toDouble(),
      cashTotal: (json['cashTotal'] ?? 0.0).toDouble(),
      cardTotal: (json['cardTotal'] ?? 0.0).toDouble(),
      transferTotal: (json['transferTotal'] ?? 0.0).toDouble(),
      openedAt: json['openedAt'] ?? '',
      closedAt: json['closedAt'],
      syncedAt: DateTime.now().toUtc().toIso8601String(),
      isDirty: 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant': {'id': tenantId},
      'user': {'id': userId},
      'initialAmount': initialAmount,
      'totalSales': totalSales,
      'cashTotal': cashTotal,
      'cardTotal': cardTotal,
      'transferTotal': transferTotal,
      'openedAt': openedAt,
      'closedAt': closedAt,
    };
  }
  // ===============================================

  CashSession copyWith({
    double? totalSales,
    double? cashTotal,
    double? cardTotal,
    double? transferTotal,
    String? closedAt,
    int? isDirty,
  }) {
    return CashSession(
      id: id,
      tenantId: tenantId,
      userId: userId,
      initialAmount: initialAmount,
      totalSales: totalSales ?? this.totalSales,
      cashTotal: cashTotal ?? this.cashTotal,
      cardTotal: cardTotal ?? this.cardTotal,
      transferTotal: transferTotal ?? this.transferTotal,
      openedAt: openedAt,
      closedAt: closedAt ?? this.closedAt,
      isDirty: isDirty ?? this.isDirty,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
