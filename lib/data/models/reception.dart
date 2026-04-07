import 'package:equatable/equatable.dart';

class Reception extends Equatable {
  final String id;
  final String supplierId;
  final DateTime timestamp;
  final List<ReceptionItem> items;
  final double total;
  final String? note;

  const Reception({
    required this.id,
    required this.supplierId,
    required this.timestamp,
    required this.items,
    required this.total,
    this.note,
  });

  @override
  List<Object?> get props => [id, supplierId, timestamp, items, total, note];
}

class ReceptionItem extends Equatable {
  final String upc;
  final String productName;
  final int quantity;
  final double costPrice;
  final double subtotal;

  const ReceptionItem({
    required this.upc,
    required this.productName,
    required this.quantity,
    required this.costPrice,
    required this.subtotal,
  });

  @override
  List<Object?> get props => [upc, productName, quantity, costPrice, subtotal];
}
