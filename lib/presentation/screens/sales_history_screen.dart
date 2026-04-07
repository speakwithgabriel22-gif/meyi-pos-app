import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/blocs/sales_history_bloc.dart';
import '../../widgets/professional_background.dart';
import '../../widgets/institutional_footer.dart';
import '../../data/models/sale.dart';

class SalesHistoryScreen extends StatelessWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas de Venta',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ProfessionalBackground(
        child: Column(
          children: [
            Expanded(
              child: BlocBuilder<SalesHistoryBloc, SalesHistoryState>(
                builder: (context, state) {
                  if (state is SalesHistoryLoading)
                    return const Center(child: CircularProgressIndicator());
                  if (state is SalesHistoryLoaded) {
                    final sales = state.sales;
                    if (sales.isEmpty)
                      return const Center(
                          child: Text('No hay ventas registradas hoy'));

                    return ListView.builder(
                      itemCount: sales.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) =>
                          _SalesNoteCard(sale: sales[index]),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            const InstitutionalFooter(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SalesNoteCard extends StatelessWidget {
  final Sale sale;
  const _SalesNoteCard({required this.sale});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSaleDetail(context, sale),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Hora y Estilo Nota (Sr. UX: Familiar para el tendero)
                Column(
                  children: [
                    Text(sale.timeFormatted,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            fontSize: 13)),
                    const SizedBox(height: 4),
                    const Icon(Icons.receipt_long_rounded,
                        color: Color(0xFF1B6CA8), size: 32),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sale.summary,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Pago: ${sale.paymentType}',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                Text('\$${sale.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B5E20))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSaleDetail(BuildContext context, Sale sale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
                child: Text('TICKET DIGITAL',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: Colors.grey))),
            const SizedBox(height: 24),
            Text('VENTA #${sale.id}',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B6CA8))),
            Text(sale.timeFormatted,
                style: const TextStyle(color: Colors.grey)),
            const Divider(height: 48),
            ...sale.items.map((it) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${it.quantity}x ${it.productName}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('\$${it.subtotal.toStringAsFixed(2)}'),
                    ],
                  ),
                )),
            const Divider(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('\$${sale.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B5E20))),
              ],
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.print_rounded),
              label: const Text('RE-IMPRIMIR TICKET'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(72),
                backgroundColor: const Color(0xFF1B6CA8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
