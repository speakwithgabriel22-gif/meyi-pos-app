import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/blocs/cash_bloc.dart';
import '../../logic/blocs/sales_history_bloc.dart';
import '../../widgets/professional_background.dart';
import '../../widgets/institutional_footer.dart';
import '../../data/models/cash_movement.dart';

class SalesHistoryScreen extends StatelessWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos del Turno',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ProfessionalBackground(
        child: Column(
          children: [
            Expanded(
              child: BlocBuilder<CashBloc, CashState>(
                builder: (context, cashState) {
                  if (cashState is! CashOpen) {
                    return const Center(
                      child:
                          Text('Abre una caja para ver movimientos del turno'),
                    );
                  }

                  return BlocBuilder<SalesHistoryBloc, SalesHistoryState>(
                    builder: (context, state) {
                      if (state is SalesHistoryLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is SalesHistoryLoaded) {
                        final movements = state.movements;
                        if (movements.isEmpty) {
                          return const Center(
                            child: Text('No hay movimientos en la caja activa'),
                          );
                        }

                        return ListView.builder(
                          itemCount: movements.length,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) =>
                              _MovementCard(movement: movements[index]),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),
            ),
            // const InstitutionalFooter(),
            const SizedBox(height: 26),
          ],
        ),
      ),
    );
  }
}

class _MovementCard extends StatelessWidget {
  final CashMovement movement;

  const _MovementCard({required this.movement});

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showMovementDetail(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      movement.timeFormatted,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(_icon, color: accent, size: 32),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movement.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        movement.affectsCash
                            ? '${movement.subtitle} · impacta caja'
                            : movement.subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${movement.isInflow ? '+' : '-'}\$${movement.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData get _icon {
    switch (movement.kind) {
      case 'expense':
        return Icons.outbox_rounded;
      case 'supplier_payment':
        return Icons.local_shipping_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  Color get _accentColor {
    if (movement.isInflow) {
      return movement.affectsCash
          ? const Color(0xFF1B5E20)
          : const Color(0xFF1565C0);
    }
    return const Color(0xFFC62828);
  }

  void _showMovementDetail(BuildContext context) {
    final accent = _accentColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text(
                'DETALLE DE MOVIMIENTO',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              movement.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
            Text(
              movement.timeFormatted,
              style: const TextStyle(color: Colors.grey),
            ),
            const Divider(height: 48),
            _detailRow('Tipo', _kindLabel(movement.kind)),
            _detailRow('Detalle', movement.subtitle),
            _detailRow(
              'Impacto en caja',
              movement.affectsCash ? 'Si' : 'No',
            ),
            if (movement.reference.isNotEmpty)
              _detailRow('Referencia', movement.reference),

            // 🆕 SECCIÓN DE PRODUCTOS (Solo si existen)
            if (movement.items != null && movement.items!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'PRODUCTOS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 12),
              Column(
                children: movement.items!.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(item['quantity'] as num).toStringAsFixed(0)}x',
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item['product_name'] ?? 'Producto s/n',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '\$${(item['subtotal'] as num).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${movement.isInflow ? '+' : '-'}\$${movement.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.check_rounded),
              label: const Text('ENTENDIDO'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(72),
                backgroundColor: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'expense':
        return 'Gasto';
      case 'supplier_payment':
        return 'Pago a proveedor';
      default:
        return 'Venta';
    }
  }
}
