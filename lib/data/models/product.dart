import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String upc;
  final String name;
  final double price;
  final double costPrice;
  final String? supplierId;
  final int stock;

  const Product({
    required this.upc,
    required this.name,
    required this.price,
    this.costPrice = 0.0,
    this.supplierId,
    this.stock = 0,
  });

  Product copyWith({
    String? name,
    double? price,
    double? costPrice,
    String? supplierId,
    int? stock,
  }) {
    return Product(
      upc: upc,
      name: name ?? this.name,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      supplierId: supplierId ?? this.supplierId,
      stock: stock ?? this.stock,
    );
  }

  @override
  List<Object?> get props => [upc, name, price, costPrice, supplierId, stock];
}
