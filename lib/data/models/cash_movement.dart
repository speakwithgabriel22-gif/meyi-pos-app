class CashMovement {
  final String id;
  final String kind;
  final String title;
  final String subtitle;
  final double amount;
  final bool affectsCash;
  final bool isInflow;
  final String createdAt;
  final String reference;
  final List<Map<String, dynamic>>? items;

  const CashMovement({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.affectsCash,
    required this.isInflow,
    required this.createdAt,
    this.reference = '',
    this.items,
  });

  DateTime? get createdAtDate {
    try {
      return DateTime.parse(createdAt).toLocal();
    } catch (_) {
      return null;
    }
  }

  String get timeFormatted {
    final dt = createdAtDate;
    if (dt == null) return '--:--';
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
