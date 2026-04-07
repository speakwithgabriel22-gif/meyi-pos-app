class Supplier {
  final String id;
  final String name;
  final String phone;
  final String category;
  final List<String> productIds;
  final double totalDebt;
  final String visitDay;
  final String deliveryDay;
  final String frequency;

  Supplier({
    required this.id,
    required this.name,
    required this.phone,
    required this.category,
    this.productIds = const [],
    this.totalDebt = 0.0,
    this.visitDay = '',
    this.deliveryDay = '',
    this.frequency = '',
  });

  bool get hasDebt => totalDebt > 0;

  Supplier copyWith({
    String? name,
    String? phone,
    String? category,
    List<String>? productIds,
    double? totalDebt,
    String? visitDay,
    String? deliveryDay,
    String? frequency,
  }) {
    return Supplier(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      category: category ?? this.category,
      productIds: productIds ?? this.productIds,
      totalDebt: totalDebt ?? this.totalDebt,
      visitDay: visitDay ?? this.visitDay,
      deliveryDay: deliveryDay ?? this.deliveryDay,
      frequency: frequency ?? this.frequency,
    );
  }
}
