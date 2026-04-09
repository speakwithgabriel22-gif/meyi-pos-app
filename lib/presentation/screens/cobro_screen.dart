import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';
import '../../logic/blocs/cart_bloc.dart';
import '../../logic/blocs/sales_history_bloc.dart';
import '../../data/models/sale.dart';
import '../../logic/blocs/cash_bloc.dart';
import '../../widgets/professional_background.dart';
import '../../utils/constants.dart';
import '../../utils/uuid_generator.dart';

class CobroScreen extends StatefulWidget {
  const CobroScreen({super.key});

  @override
  State<CobroScreen> createState() => _CobroScreenState();
}

class _CobroScreenState extends State<CobroScreen> {
  final TextEditingController _recibidoCtrl = TextEditingController();
  double _cambio = -1;
  String _selectedPayment = 'CASH';

  @override
  Widget build(BuildContext context) {
    final cartState = context.watch<CartBloc>().state;
    final total = cartState.total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierre de Venta',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ProfessionalBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                  child: Text('TOTAL A COBRAR',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 2))),
              const SizedBox(height: 8),
              Center(
                child: Text('\$${total.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.primary)),
              ),
              const SizedBox(height: 32),

              // Selector de Pago (Sr. UX: Cards de apariencia Premium)
              const Text('MÉTODO DE PAGO',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _PaymentCard(
                    label: 'CASH',
                    icon: Icons.payments_rounded,
                    isSelected: _selectedPayment == 'CASH',
                    onTap: () => setState(() => _selectedPayment = 'CASH'),
                  ),
                  _PaymentCard(
                    label: 'Tarjeta',
                    icon: Icons.credit_card_rounded,
                    isSelected: _selectedPayment == 'CARD',
                    onTap: () => setState(() => _selectedPayment = 'CARD'),
                  ),
                  _PaymentCard(
                    label: 'Transf.',
                    icon: Icons.account_balance_rounded,
                    isSelected: _selectedPayment == 'TRANSFER',
                    onTap: () => setState(() => _selectedPayment = 'TRANSFER'),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              if (_selectedPayment == 'CASH') ...[
                TextField(
                  controller: _recibidoCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                      fontSize: 48, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                      labelText: 'Dinero Recibido', prefixText: '\$ '),
                  onChanged: (val) {
                    final r = double.tryParse(val) ?? 0;
                    setState(() => _cambio = r - total);
                  },
                  onSubmitted: (val) {
                    // Sr. UX: Cero fricción - Registrar al dar "Done" en el teclado
                    if (_cambio >= 0) _finish(context, cartState);
                  },
                ),
                const SizedBox(height: 32),
                if (_cambio >= 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: Colors.green.withOpacity(0.3), width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('CAMBIO:',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                        Text('\$${_cambio.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: Colors.green)),
                      ],
                    ),
                  ),
              ] else ...[
                // Resumen para pagos exactos (Tarjeta/Transferencia)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 12),
                      Text('Se registrará el pago exacto vía $_selectedPayment',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 48),

              // Botón Finalizar
              ElevatedButton.icon(
                onPressed: (_selectedPayment != 'CASH' || _cambio >= 0)
                    ? () => _finish(context, cartState)
                    : null,
                icon: const Icon(Icons.check_circle_rounded, size: 28),
                label: const Text('REGISTRAR Y FINALIZAR'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(80),
                  backgroundColor: const Color(
                      0xFF1B5E20), // Stay green for success or use colorScheme
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
              const SizedBox(height: 16),
              if (_selectedPayment == 'CASH')
                TextButton(
                  onPressed: () {
                    _recibidoCtrl.text = total.toStringAsFixed(2);
                    setState(() => _cambio = 0);
                  },
                  child: const Text('PAGO EXACTO (SIN CAMBIO)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _finish(BuildContext context, CartState cartState) {
    if (_selectedPayment == 'CASH' && _cambio < 0) return;

    Vibration.vibrate(duration: 100);
    SystemSound.play(SystemSoundType.click);

    final tenantId = Constants.tenantId ?? 'offline-tenant';
    final userId = Constants.userId;
    final now = DateTime.now().toIso8601String();

    final saleId = UuidGenerator.generate();

    final sale = Sale(
      id: saleId,
      tenantId: tenantId,
      userId: userId,
      cashSessionId: '', // 🆕 El repositorio asignará la sesión activa desde la DB
      folio:
          'TEMP-${UuidGenerator.generate().substring(0, 8)}', // El repositorio asignará el folio final
      total: cartState.total,
      paymentType: _selectedPayment,
      createdAt: now,
      updatedAt: now,
      items: cartState.items.map((it) {
        final itemId = '${saleId}-${it.product.upc}';
        return SaleItem(
          id: itemId,
          saleId: saleId,
          upc: it.product.upc,
          productName: it.product.name,
          unitPrice: it.product.price,
          quantity: it.quantity.toDouble(),
          subtotal: (it.product.price * it.quantity).toDouble(),
        );
      }).toList(),
    );

    context.read<SalesHistoryBloc>().add(SalesRecordRequested(sale));
    context.read<CartBloc>().add(CartCleared());
    // Sr. UX: Sincronizar saldo de caja
    context
        .read<CashBloc>()
        .add(CashSaleRecorded(sale.total, sale.paymentType));

    context.go('/home');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('✅ Venta registrada correctamente'),
          behavior: SnackBarBehavior.floating),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                width: 2),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                  size: 28),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
