import 'product.dart';

class Sale {
  final String id;
  final String folio; // Correlativo profesional: V-20260405-001
  final DateTime timestamp;
  final List<SaleItem> items;
  final double total;
  final String paymentType; // 'Efectivo', 'Tarjeta', 'Transferencia'

  Sale({
    required this.id,
    this.folio = '',
    required this.timestamp,
    required this.items,
    required this.total,
    required this.paymentType,
  });

  String get timeFormatted => "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}";
  
  String get summary {
    if (items.isEmpty) return 'Venta Vacía';
    final first = items.first.productName;
    if (items.length == 1) return first;
    return '$first, ${items[1].productName}${items.length > 2 ? '...' : ''}';
  }
}

class SaleItem {
  final String productId;
  final String productName;
  final double priceAtSale;
  final int quantity;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.priceAtSale,
    required this.quantity,
  });

  double get subtotal => priceAtSale * quantity;
}
