import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibration/vibration.dart';
import '../../logic/blocs/suppliers_bloc.dart';
import '../../widgets/professional_background.dart';
import '../../widgets/institutional_footer.dart';
import '../../data/models/supplier.dart';
import '../../data/models/product.dart';
import '../../data/models/reception.dart';
import '../../data/repositories/business_repository.dart';

class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas por Pagar',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ProfessionalBackground(
        child: Column(
          children: [
            Expanded(
              child: BlocBuilder<SuppliersBloc, SuppliersState>(
                builder: (context, state) {
                  if (state is SuppliersLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is SuppliersLoaded) {
                    final suppliers = state.suppliers;
                    final totalDebt = suppliers.fold<double>(
                        0, (sum, s) => sum + s.totalDebt);

                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        _TotalDebtHero(amount: totalDebt),
                        const SizedBox(height: 32),
                        const Text('TUS PROVEEDORES',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6E6E73), // textSecondary type
                                letterSpacing: 1.2)),
                        const SizedBox(height: 16),
                        ...suppliers.map((s) => _SupplierDebtCard(supplier: s)),
                      ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSupplierModal(context),
        icon: const Icon(Icons.person_add_rounded),
        label:
            const Text('NUEVO', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showAddSupplierModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final debtCtrl = TextEditingController();
    String visitDay = 'Lunes';
    String deliveryDay = 'Lunes';
    String frequency = 'Semanal';

    final days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Lunes y Jueves',
      'Martes y Viernes'
    ];
    final freqs = ['Semanal', '2 veces por semana', 'Quincenal', 'Mensual'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 32,
              right: 32,
              top: 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Nuevo Proveedor',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 24),
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nombre del Proveedor',
                        prefixIcon: Icon(Icons.business_rounded))),
                const SizedBox(height: 16),
                TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        prefixIcon: Icon(Icons.phone_rounded))),
                const SizedBox(height: 16),
                TextField(
                    controller: categoryCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Categoría (ej. Lácteos)',
                        prefixIcon: Icon(Icons.category_rounded))),
                const SizedBox(height: 16),
                TextField(
                    controller: debtCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Deuda Inicial (opcional)',
                        prefixText: '\$ ',
                        prefixIcon:
                            Icon(Icons.account_balance_wallet_rounded))),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: visitDay,
                        decoration:
                            const InputDecoration(labelText: 'Día de Pedido'),
                        items: days
                            .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text(d,
                                    style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => visitDay = v!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: frequency,
                        decoration:
                            const InputDecoration(labelText: 'Frecuencia'),
                        items: freqs
                            .map((f) => DropdownMenuItem(
                                value: f,
                                child: Text(f,
                                    style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => frequency = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: deliveryDay,
                  decoration:
                      const InputDecoration(labelText: 'Día de Entrega'),
                  items: [
                    ...days
                        .map((d) => DropdownMenuItem(value: d, child: Text(d))),
                    const DropdownMenuItem(
                        value: 'Inmediata', child: Text('Inmediata'))
                  ].toList(),
                  onChanged: (v) => setState(() => deliveryDay = v!),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final newSupplier = Supplier(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      category: categoryCtrl.text.trim(),
                      totalDebt: double.tryParse(debtCtrl.text) ?? 0.0,
                      visitDay: visitDay,
                      deliveryDay: deliveryDay,
                      frequency: frequency,
                    );
                    context
                        .read<SuppliersBloc>()
                        .add(SuppliersAdded(newSupplier));
                    Navigator.pop(ctx);
                    Vibration.vibrate(duration: 50);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('✅ ${newSupplier.name} agregado'),
                          behavior: SnackBarBehavior.floating),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(60)),
                  child: const Text('REGISTRAR PROVEEDOR',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalDebtHero extends StatelessWidget {
  final double amount;
  const _TotalDebtHero({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)]),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFB71C1C).withOpacity(0.3), blurRadius: 20)
        ],
      ),
      child: Column(
        children: [
          const Text('TOTAL POR PAGAR',
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
          const SizedBox(height: 12),
          Text('\$${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          const Text('Mantén tus créditos al día para no detener tu surtido',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}

class _SupplierDebtCard extends StatelessWidget {
  final Supplier supplier;
  const _SupplierDebtCard({required this.supplier});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color:
                supplier.hasDebt ? Colors.red.shade100 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(supplier.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(supplier.category,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 13)),
                    ],
                  ),
                ),
                if (supplier.hasDebt)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('\$${supplier.totalDebt.toStringAsFixed(0)}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w900,
                            fontSize: 18)),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Logística del Preventista
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _InfoItem(
                      icon: Icons.calendar_today_rounded,
                      label: 'PEDIDO',
                      value: supplier.visitDay),
                  const Spacer(),
                  _InfoItem(
                      icon: Icons.local_shipping_rounded,
                      label: 'ENTREGA',
                      value: supplier.deliveryDay),
                  const Spacer(),
                  _InfoItem(
                      icon: Icons.repeat_rounded,
                      label: 'FREC.',
                      value: supplier.frequency),
                ],
              ),
            ),

            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => context
                        .read<SuppliersBloc>()
                        .add(SuppliersCallRequested(supplier.phone)),
                    icon: const Icon(Icons.call_rounded, size: 20),
                    label: const Text('LLAMAR'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showReceiveOrderModal(context),
                    icon: const Icon(Icons.inventory_2_rounded, size: 18),
                    label: const Text('RECIBIR',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showPaymentModal(context),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: supplier.hasDebt
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.surfaceVariant,
                      foregroundColor: supplier.hasDebt
                          ? Theme.of(context).colorScheme.surface
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                    ),
                    child: const Text('ABONAR',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiveOrderModal(BuildContext context) {
    final searchCtrl = TextEditingController();
    List<ReceptionItem> receptionItems = [];
    double total = 0;

    void updateTotals(StateSetter setState) {
      total = receptionItems.fold(0.0, (sum, item) => sum + item.subtotal);
      setState(() {});
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Surtido de ${supplier.name}',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
                        Text('Escanea o busca productos para agregar al stock',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 24),
              
              // Buscador de productos
              TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Nombre o UPC del producto...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    onPressed: () {
                      // Simulación de escaneo
                      searchCtrl.text = '7501000612662'; // Bimbo Pan Blanco
                    },
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                onSubmitted: (val) async {
                  if (val.trim().isEmpty) return;
                  final repo = context.read<BusinessRepository>();
                  final product = await repo.findProductByUpc(val.trim());
                  if (product != null) {
                    final item = ReceptionItem(
                      upc: product.upc,
                      productName: product.name,
                      quantity: 1,
                      costPrice: product.costPrice > 0 ? product.costPrice : 15.0,
                      subtotal: product.costPrice > 0 ? product.costPrice : 15.0,
                    );
                    setState(() {
                      receptionItems.add(item);
                      searchCtrl.clear();
                      updateTotals(setState);
                    });
                  }
                },
              ),
              
              const SizedBox(height: 24),
              const Text('LISTA DE RECEPCIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              
              Expanded(
                child: receptionItems.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_shopping_cart_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text('Agrega productos para comenzar', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: receptionItems.length,
                      itemBuilder: (ctx, index) {
                        final item = receptionItems[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('UPC: ${item.upc}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  _QtyBtn(
                                    icon: Icons.remove, 
                                    onTap: () {
                                      if (item.quantity > 1) {
                                        setState(() {
                                          receptionItems[index] = ReceptionItem(
                                            upc: item.upc,
                                            productName: item.productName,
                                            quantity: item.quantity - 1,
                                            costPrice: item.costPrice,
                                            subtotal: (item.quantity - 1) * item.costPrice,
                                          );
                                          updateTotals(setState);
                                        });
                                      } else {
                                        setState(() {
                                          receptionItems.removeAt(index);
                                          updateTotals(setState);
                                        });
                                      }
                                    }
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                  ),
                                  _QtyBtn(
                                    icon: Icons.add, 
                                    onTap: () {
                                      setState(() {
                                        receptionItems[index] = ReceptionItem(
                                          upc: item.upc,
                                          productName: item.productName,
                                          quantity: item.quantity + 1,
                                          costPrice: item.costPrice,
                                          subtotal: (item.quantity + 1) * item.costPrice,
                                        );
                                        updateTotals(setState);
                                      });
                                    }
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Container(
                                width: 70,
                                alignment: Alignment.centerRight,
                                child: Text('\$${item.subtotal.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
              
              const Divider(height: 32),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL A PAGAR AL PROVEEDOR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.orange)),
                ],
              ),
              
              const SizedBox(height: 24),
              
              ElevatedButton(
                onPressed: receptionItems.isEmpty ? null : () {
                  final reception = Reception(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    supplierId: supplier.id,
                    timestamp: DateTime.now(),
                    items: receptionItems,
                    total: total,
                  );
                  context.read<SuppliersBloc>().add(SuppliersReceptionRecorded(reception));
                  Navigator.pop(ctx);
                  Vibration.vibrate(duration: 50);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Surtido de ${receptionItems.length} productos registrado'),
                      backgroundColor: Colors.green.shade800,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  backgroundColor: Theme.of(context).colorScheme.onSurface,
                  foregroundColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('CONFIRMAR RECEPCIÓN Y SUBIR STOCK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentModal(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
            left: 32,
            right: 32,
            top: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Abonar a ${supplier.name}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Deuda actual: \$${supplier.totalDebt.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                  labelText: 'Monto a Pagar', prefixText: '\$ '),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(ctrl.text) ?? 0.0;
                if (amount > 0) {
                  Vibration.vibrate(duration: 50);
                  context
                      .read<SuppliersBloc>()
                      .add(SuppliersDebtPaid(supplier.id, amount));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '✅ Pago de \$${amount.toStringAsFixed(2)} registrado'),
                        behavior: SnackBarBehavior.floating),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(60)),
              child: const Text('REGISTRAR PAGO'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1B6CA8)),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface)),
      ],
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16),
        ),
      ),
    );
  }
}
