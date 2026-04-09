import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';
import '../../logic/blocs/cash_bloc.dart';
import '../../logic/blocs/suppliers_bloc.dart';
import '../../widgets/professional_background.dart';
import '../../widgets/institutional_footer.dart';
import '../../data/models/supplier.dart';
import '../../data/models/reception.dart';
import '../../data/models/product.dart';
import '../../data/repositories/business_repository.dart';
import '../widgets/scanner_error_widget.dart';
import '../../utils/constants.dart';
import '../../utils/uuid_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers de texto responsivo
// ─────────────────────────────────────────────────────────────────────────────

extension ResponsiveText on BuildContext {
  /// Escala un tamaño de fuente base al ancho lógico de la pantalla.
  /// Base de diseño: 390px (iPhone 14). Clamp evita extremos.
  double sp(double base) {
    final width = MediaQuery.of(this).size.width;
    final scale = width / 390.0;
    return (base * scale).clamp(base * 0.82, base * 1.22);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SuppliersScreen
// ─────────────────────────────────────────────────────────────────────────────

class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cuentas por Pagar',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: context.sp(20),
          ),
        ),
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
                    final suppliers = [...state.suppliers]..sort((a, b) {
                        if (a.hasDebt != b.hasDebt) return a.hasDebt ? -1 : 1;
                        return b.totalDebt.compareTo(a.totalDebt);
                      });
                    final totalDebt = suppliers.fold<double>(
                        0, (sum, s) => sum + s.totalDebt);

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        _TotalDebtHero(
                          amount: totalDebt,
                          suppliersWithDebt:
                              suppliers.where((s) => s.hasDebt).length,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'PROVEEDORES ACTIVOS',
                          style: TextStyle(
                            fontSize: context.sp(11),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6E6E73),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...suppliers.map((s) => _SupplierDebtCard(supplier: s)),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            // const InstitutionalFooter(),
            const SizedBox(height: 16),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSupplierModal(context),
        icon: const Icon(Icons.person_add_rounded),
        label: Text(
          'Nuevo Proveedor',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: context.sp(13),
          ),
        ),
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final cs = Theme.of(context).colorScheme;
          return Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Nuevo Proveedor',
                    style: TextStyle(
                      fontSize: context.sp(20),
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SheetField(
                    controller: nameCtrl,
                    label: 'Nombre del proveedor',
                    icon: Icons.business_rounded,
                    capitalize: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  _SheetField(
                    controller: phoneCtrl,
                    label: 'Teléfono',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _SheetField(
                    controller: categoryCtrl,
                    label: 'Categoría (ej. Refrescos, Lácteos)',
                    icon: Icons.category_rounded,
                    capitalize: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  _SheetField(
                    controller: debtCtrl,
                    label: 'Deuda inicial',
                    icon: Icons.account_balance_wallet_rounded,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    prefixText: '\$ ',
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _SheetDropdown(
                          value: visitDay,
                          label: 'Día de pedido',
                          items: days,
                          onChanged: (v) => setModalState(() => visitDay = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SheetDropdown(
                          value: frequency,
                          label: 'Frecuencia',
                          items: freqs,
                          onChanged: (v) => setModalState(() => frequency = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SheetDropdown(
                    value: deliveryDay,
                    label: 'Día de entrega',
                    items: [...days, 'Inmediata'],
                    onChanged: (v) => setModalState(() => deliveryDay = v!),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('El nombre es obligatorio'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      final tenantId = Constants.tenantId ?? 'offline-tenant';
                      final now = DateTime.now().toIso8601String();
                      final supplier = Supplier(
                        id: UuidGenerator.generate(),
                        tenantId: tenantId,
                        name: name,
                        phone: phoneCtrl.text.trim(),
                        category: categoryCtrl.text.trim(),
                        totalDebt: double.tryParse(debtCtrl.text) ?? 0.0,
                        visitDay: visitDay,
                        deliveryDay: deliveryDay,
                        frequency: frequency,
                        createdAt: now,
                        updatedAt: now,
                      );
                      context
                          .read<SuppliersBloc>()
                          .add(SuppliersAdded(supplier));
                      Navigator.pop(ctx);
                      Vibration.vibrate(duration: 50);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${supplier.name} agregado'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'REGISTRAR PROVEEDOR',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: context.sp(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets reutilizables del sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? prefixText;
  final TextCapitalization capitalize;
  final List<TextInputFormatter>? inputFormatters;

  const _SheetField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.prefixText,
    this.capitalize = TextCapitalization.none,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalize,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        prefixText: prefixText,
      ),
    );
  }
}

class _SheetDropdown extends StatelessWidget {
  final String value;
  final String label;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _SheetDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items:
          items.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
      onChanged: onChanged,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TotalDebtHero
// ─────────────────────────────────────────────────────────────────────────────

class _TotalDebtHero extends StatelessWidget {
  final double amount;
  final int suppliersWithDebt;

  const _TotalDebtHero({required this.amount, required this.suppliersWithDebt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7F1D1D), Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL POR PAGAR',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: context.sp(11),
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: context.sp(40),
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$suppliersWithDebt con deuda activa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.sp(12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SupplierDebtCard
// ─────────────────────────────────────────────────────────────────────────────

class _SupplierDebtCard extends StatelessWidget {
  final Supplier supplier;
  const _SupplierDebtCard({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cashState = context.watch<CashBloc>().state;
    final hasOpenCash = cashState is CashOpen;
    final availableCash = hasOpenCash ? cashState.expectedCash : 0.0;
    final canPay = supplier.hasDebt && hasOpenCash && availableCash > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: supplier.hasDebt
              ? Colors.red.withValues(alpha: 0.22)
              : cs.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.name,
                        style: TextStyle(
                          fontSize: context.sp(17),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        supplier.category?.isNotEmpty == true
                            ? supplier.category!
                            : 'Proveedor general',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.55),
                          fontSize: context.sp(13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: supplier.hasDebt
                        ? cs.error.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    supplier.hasDebt
                        ? '\$${supplier.totalDebt.toStringAsFixed(2)}'
                        : 'Al corriente',
                    style: TextStyle(
                      color: supplier.hasDebt ? cs.error : Colors.green,
                      fontWeight: FontWeight.w900,
                      fontSize: context.sp(15),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Info chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _InfoItem(
                    icon: Icons.calendar_today_rounded,
                    label: 'PEDIDO',
                    value: supplier.visitDay ?? '-',
                  ),
                  _VertDivider(),
                  _InfoItem(
                    icon: Icons.local_shipping_rounded,
                    label: 'ENTREGA',
                    value: supplier.deliveryDay ?? '-',
                  ),
                  _VertDivider(),
                  _InfoItem(
                    icon: Icons.repeat_rounded,
                    label: 'FREC.',
                    value: supplier.frequency ?? '-',
                  ),
                ],
              ),
            ),

            // Warning banners
            if (!supplier.hasDebt)
              _WarningBanner(
                message: 'Sin deuda pendiente con este proveedor.',
                color: Colors.green,
                icon: Icons.check_circle_outline_rounded,
              ),
            if (supplier.hasDebt && !hasOpenCash)
              _WarningBanner(
                message: 'Abre una caja para registrar pagos.',
                color: cs.error,
                icon: Icons.lock_outline_rounded,
              ),
            if (supplier.hasDebt && hasOpenCash && availableCash <= 0)
              _WarningBanner(
                message: 'Sin efectivo disponible en caja.',
                color: cs.error,
                icon: Icons.money_off_rounded,
              ),

            const SizedBox(height: 14),

            // Action buttons
            Row(
              children: [
                _ActionButton(
                  label: 'Llamar',
                  icon: Icons.call_rounded,
                  onPressed: () => context
                      .read<SuppliersBloc>()
                      .add(SuppliersCallRequested(supplier.phone)),
                  kind: _ActionButtonKind.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'Recibir',
                    icon: Icons.inventory_2_rounded,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _ReceiveOrderScreen(supplier: supplier),
                      ),
                    ),
                    kind: _ActionButtonKind.outline,
                  ),
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  label: 'Abonar',
                  icon: Icons.payments_rounded,
                  onPressed: canPay ? () => _showPaymentModal(context) : null,
                  kind: _ActionButtonKind.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentModal(BuildContext context) {
    final cashState = context.read<CashBloc>().state as CashOpen;
    final availableCash = cashState.expectedCash;
    final ctrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
            left: 24,
            right: 24,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Registrar pago',
                style: TextStyle(
                  fontSize: context.sp(20),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                supplier.name,
                style: TextStyle(
                  fontSize: context.sp(14),
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Deuda actual',
                      value: '\$${supplier.totalDebt.toStringAsFixed(2)}',
                      color: cs.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'En caja',
                      value: '\$${availableCash.toStringAsFixed(2)}',
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: TextStyle(
                  fontSize: context.sp(30),
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: 'Monto a pagar',
                  prefixText: '\$ ',
                  helperText:
                      'Máximo: \$${availableCash.toStringAsFixed(2)} disponibles en caja',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  final amount = double.tryParse(ctrl.text) ?? 0.0;
                  if (amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ingresa un monto válido'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  final capped =
                      amount > supplier.totalDebt ? supplier.totalDebt : amount;
                  if (capped > availableCash) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'No alcanza. Disponible: \$${availableCash.toStringAsFixed(2)}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  Vibration.vibrate(duration: 50);
                  context
                      .read<SuppliersBloc>()
                      .add(SuppliersDebtPaid(supplier.id, capped));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Pago de \$${capped.toStringAsFixed(2)} registrado'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'REGISTRAR PAGO',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color:
          Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;

  const _WarningBanner({
    required this.message,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: context.sp(12),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: context.sp(10),
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: context.sp(16),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActionButton
// ─────────────────────────────────────────────────────────────────────────────

enum _ActionButtonKind { primary, secondary, outline }

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final _ActionButtonKind kind;
  final bool
      expandOnMobile; // Opcional: si quieres que ocupe todo el ancho en celulares

  const _ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.kind,
    this.expandOnMobile =
        false, // Por defecto es false para no romper tus layouts actuales
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;

    // 1. Definir Breakpoints (Puntos de quiebre)
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    // 2. Ajustes dinámicos según la pantalla
    final double buttonHeight = isDesktop ? 56 : (isTablet ? 52 : 48);
    final double iconBaseSize = isDesktop ? 20 : (isTablet ? 18 : 17);
    final double fontBaseSize = isDesktop ? 15 : (isTablet ? 13 : 12);
    final double gap = isDesktop ? 12 : (isTablet ? 8 : 6);
    final double horizontalPadding = isDesktop ? 32 : (isTablet ? 24 : 16);

    // 3. Comportamiento del ancho
    final bool shouldExpand = isMobile && expandOnMobile;

    final child = Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        mainAxisSize: shouldExpand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mantenemos tu context.sp(), pero con valores base adaptativos
          Icon(icon, size: context.sp(iconBaseSize)),
          SizedBox(width: gap),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              // Mantenemos tu context.sp() adaptado
              fontSize: context.sp(fontBaseSize),
            ),
          ),
        ],
      ),
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
          isDesktop ? 16 : 14), // Bordes ligeramente más suaves en desktop
    );

    // 4. Función auxiliar para construir el contenedor del botón
    Widget buildButton(Widget buttonWidget) {
      return SizedBox(
        height: buttonHeight,
        width: shouldExpand ? double.infinity : null,
        child: buttonWidget,
      );
    }

    switch (kind) {
      case _ActionButtonKind.primary:
        return buildButton(
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero, // El padding se maneja en el Row
              shape: shape,
              disabledBackgroundColor: cs.surfaceContainerHighest,
            ),
            child: child,
          ),
        );
      case _ActionButtonKind.secondary:
        return buildButton(
          FilledButton.tonal(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: shape,
            ),
            child: child,
          ),
        );
      case _ActionButtonKind.outline:
        return buildButton(
          OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: shape,
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: child,
          ),
        );
    }
  }
}

// Nota: Si context.sp() marca error aquí, es porque seguramente lo tienes
// definido en otro archivo (como una extensión de flutter_screenutil).
// Asegúrate de importar ese archivo si es necesario.

// ─────────────────────────────────────────────────────────────────────────────
// _InfoItem
// ─────────────────────────────────────────────────────────────────────────────

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: context.sp(17), color: cs.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: context.sp(9),
            fontWeight: FontWeight.bold,
            color: cs.onSurface.withValues(alpha: 0.5),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: context.sp(11),
            fontWeight: FontWeight.w900,
            color: cs.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReceiveOrderScreen — escáner robusto + UX mejorado
// ─────────────────────────────────────────────────────────────────────────────

class _ReceiveOrderScreen extends StatefulWidget {
  final Supplier supplier;
  const _ReceiveOrderScreen({required this.supplier});

  @override
  State<_ReceiveOrderScreen> createState() => _ReceiveOrderScreenState();
}

class _ReceiveOrderScreenState extends State<_ReceiveOrderScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  // FIX: un solo controlador de escáner, gestionado con cuidado
  final MobileScannerController _scannerCtrl =
      MobileScannerController(autoStart: false);
  final AudioPlayer _audioPlayer = AudioPlayer();

  final List<ReceptionItem> _items = [];
  Timer? _debounce;

  bool _isScannerVisible = false;
  bool _scannerRunning = false;
  // FIX: flag unificado para evitar doble procesamiento
  bool _processingInput = false;
  bool _saving = false;

  double get _total => _items.fold<double>(0, (sum, i) => sum + i.subtotal);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    // FIX: detener scanner siempre en dispose, aunque _scannerRunning sea false
    _scannerCtrl.stop().catchError((_) {}).then((_) => _scannerCtrl.dispose());
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Scanner management ──────────────────────────────────────────────────

  Future<void> _startScanner() async {
    if (_scannerRunning) return;
    try {
      await _scannerCtrl.start();
      if (mounted) setState(() => _scannerRunning = true);
    } on PlatformException catch (e) {
      debugPrint('Scanner start error: $e');
      if (mounted) {
        setState(() => _scannerRunning = false);
        _showScannerError();
      }
    }
  }

  Future<void> _stopScanner() async {
    if (!_scannerRunning) return;
    try {
      await _scannerCtrl.stop();
    } on PlatformException catch (e) {
      debugPrint('Scanner stop error: $e');
    } finally {
      if (mounted) setState(() => _scannerRunning = false);
    }
  }

  Future<void> _openScanner() async {
    if (_isScannerVisible) return;
    setState(() => _isScannerVisible = true);
    await _startScanner();
  }

  Future<void> _closeScanner() async {
    if (!_isScannerVisible) return;
    setState(() => _isScannerVisible = false);
    await _stopScanner();
  }

  Future<void> _toggleScanner() async {
    _isScannerVisible ? await _closeScanner() : await _openScanner();
  }

  void _showScannerError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.camera_alt_outlined, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                  'No se pudo acceder a la cámara. Verifica los permisos.'),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Reintentar',
          onPressed: _startScanner,
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // FIX: pausar/reanudar scanner al ir a subpantallas
  Future<void> _pauseScanner() async {
    if (_scannerRunning) {
      try {
        await _scannerCtrl.stop();
        if (mounted) setState(() => _scannerRunning = false);
      } catch (_) {}
    }
  }

  Future<void> _resumeScannerIfVisible() async {
    if (_isScannerVisible && !_scannerRunning) {
      await _startScanner();
    }
  }

  // ── Input handling ──────────────────────────────────────────────────────

  Future<void> _handleDetectedBarcode(String code) async {
    if (_processingInput) return;
    setState(() => _processingInput = true);

    await _closeScanner();
    await _audioPlayer.play(AssetSource('audio/beep.mp3'));
    Vibration.vibrate(duration: 30);

    try {
      await _resolveAndAdd(code, isBarcode: true);
    } finally {
      if (mounted) setState(() => _processingInput = false);
    }
  }

  void _handleTypedSearch(String value) {
    final query = value.trim();
    if (query.length < 2 || _processingInput) {
      _debounce?.cancel();
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || _processingInput) return;
      _openLookup(query);
    });
  }

  Future<void> _handleSearchSubmitted(String value) async {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty || _processingInput) return;
    await _openLookup(query);
  }

  Future<void> _openLookup(String query) async {
    if (_processingInput) return;
    setState(() => _processingInput = true);

    await _pauseScanner();

    try {
      await _resolveAndAdd(query, isBarcode: false);
    } finally {
      if (mounted) {
        setState(() => _processingInput = false);
        _searchCtrl.clear();
        await _resumeScannerIfVisible();
      }
    }
  }

  /// Lógica unificada: busca el UPC/query, navega si hace falta, abre el editor.
  Future<void> _resolveAndAdd(String query, {required bool isBarcode}) async {
    final repo = context.read<BusinessRepository>();

    // 1. Búsqueda exacta por UPC (solo si parece código de barras)
    if (isBarcode || RegExp(r'^\d{6,14}$').hasMatch(query)) {
      final exact = await repo.findProductByUpc(query);
      if (exact != null && mounted) {
        await _addProduct(exact);
        return;
      }
    }

    // 2. Búsqueda general
    final results = await repo.searchProducts(query);
    if (!mounted) return;

    if (results.isEmpty) {
      // Permitir creación manual
      final newProduct = await _showManualProductDialog(query);
      if (newProduct != null && mounted) await _addProduct(newProduct);
      return;
    }

    if (results.length == 1 && isBarcode) {
      await _addProduct(results.first);
      return;
    }

    // 3. Ir a lookup
    final picked = await Navigator.push<Product>(
      context,
      MaterialPageRoute(
        builder: (_) => _SupplierProductLookupScreen(initialQuery: query),
      ),
    );
    if (picked != null && mounted) await _addProduct(picked);
  }

  Future<Product?> _showManualProductDialog(String upc) async {
    final nameCtrl = TextEditingController();
    return showDialog<Product>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Producto no encontrado',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.qr_code_rounded,
                      size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      upc,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: context.sp(13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'El código no está en tu inventario. ¿Quieres darlo de alta?',
              style: TextStyle(
                fontSize: context.sp(13),
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del producto',
                hintText: 'Ej: Refresco 600ml',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(
                ctx,
                Product(
                  id: UuidGenerator.generate(),
                  tenantId: Constants.tenantId ?? 'offline-tenant',
                  upc: upc,
                  name: name,
                  price: 0.0,
                  stock: 0.0,
                  createdAt: DateTime.now().toIso8601String(),
                  updatedAt: DateTime.now().toIso8601String(),
                ),
              );
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Dar de alta'),
          ),
        ],
      ),
    );
  }

  Future<void> _addProduct(Product product) async {
    final item = await showModalBottomSheet<ReceptionItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReceptionItemEditor(product: product),
    );

    if (item == null || !mounted) return;

    setState(() {
      final idx = _items.indexWhere((e) => e.upc == item.upc);
      if (idx >= 0) {
        final cur = _items[idx];
        final qty = cur.quantity + item.quantity;
        _items[idx] = ReceptionItem(
          id: cur.id,
          transactionId: cur.transactionId,
          upc: cur.upc,
          productName: cur.productName,
          quantity: qty,
          costPrice: item.costPrice,
          subtotal: qty * item.costPrice,
        );
      } else {
        _items.add(ReceptionItem(
          id: UuidGenerator.generate(),
          transactionId: '',
          upc: item.upc,
          productName: item.productName,
          quantity: item.quantity,
          costPrice: item.costPrice,
          subtotal: item.subtotal,
        ));
      }
    });
  }

  void _updateItemQty(int index, double qty) {
    setState(() {
      if (qty <= 0) {
        _items.removeAt(index);
      } else {
        final item = _items[index];
        _items[index] = ReceptionItem(
          id: item.id,
          transactionId: item.transactionId,
          upc: item.upc,
          productName: item.productName,
          quantity: qty,
          costPrice: item.costPrice,
          subtotal: qty * item.costPrice,
        );
      }
    });
  }

  Future<void> _saveReception() async {
    if (_items.isEmpty || _saving) return;
    setState(() => _saving = true);

    final tenantId = Constants.tenantId ?? 'offline-tenant';
    final now = DateTime.now().toIso8601String();
    final receptionId = UuidGenerator.generate();

    final reception = Reception(
      id: receptionId,
      tenantId: tenantId,
      supplierId: widget.supplier.id,
      createdAt: now,
      updatedAt: now,
      items: _items
          .map((i) => ReceptionItem(
                id: UuidGenerator.generate(),
                transactionId: receptionId,
                upc: i.upc,
                productName: i.productName,
                quantity: i.quantity,
                costPrice: i.costPrice,
                subtotal: i.subtotal,
              ))
          .toList(),
      total: _total,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    context.read<SuppliersBloc>().add(SuppliersReceptionRecorded(reception));
    await Vibration.vibrate(duration: 80);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Surtido de ${reception.items?.length ?? 0} producto(s) guardado'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(
          'Recibir surtido',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: context.sp(18),
          ),
        ),
      ),
      body: ProfessionalBackground(
        child: Column(
          children: [
            // ── Scanner panel ────────────────────────────────────────────
            _ScannerPanel(
              isVisible: _isScannerVisible,
              isRunning: _scannerRunning,
              controller: _scannerCtrl,
              onDetect: (code) => _handleDetectedBarcode(code),
              onClose: _closeScanner,
              onRetry: _startScanner,
            ),

            // ── Main content ────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _buildSupplierHeader(cs),
                  const SizedBox(height: 16),
                  _buildCaptureCard(cs),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nota de recepción (opcional)',
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildItemsSection(cs),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            // Total chip
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: context.sp(13),
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '\$${_total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: context.sp(18),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _items.isEmpty || _saving ? null : _saveReception,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _saving ? 'GUARDANDO...' : 'CONFIRMAR SURTIDO',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: context.sp(13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierHeader(ColorScheme cs) {
    // Variable para saber si tiene deuda (para pintar rojo o verde)
    final bool hasDebt = widget.supplier.hasDebt;
    final Color debtColor = hasDebt ? cs.error : Colors.green.shade600;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Añadimos un gradiente muy sutil para darle un aspecto premium
        gradient: LinearGradient(
          colors: [
            cs.surface,
            cs.primary.withValues(alpha: 0.03), // Un toque del color principal
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. NUEVO: Avatar o Icono del proveedor
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            ),
            child: Icon(
              Icons.storefront_rounded, // o business_rounded
              color: cs.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),

          // 2. Textos principales
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.supplier.name,
                  style: TextStyle(
                    fontSize: context.sp(18),
                    fontWeight:
                        FontWeight.w700, // w700 es más elegante que w900
                    letterSpacing: -0.3, // Le da un toque más moderno
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.label_outline_rounded,
                      size: context.sp(14),
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.supplier.category?.isNotEmpty == true
                            ? widget.supplier.category!
                            : 'Proveedor general',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.6),
                          fontSize: context.sp(13),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 3. Resumen (Chips)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ReceiveSummaryChip(
                label: 'Deuda',
                value: '\$${widget.supplier.totalDebt.toStringAsFixed(2)}',
                tint: debtColor,
              ),
              const SizedBox(height: 8),
              _ReceiveSummaryChip(
                label: 'Artículos',
                value: '${_items.length}',
                tint: cs.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.add_circle_outline_rounded,
                  color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Agregar producto',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: context.sp(15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            enabled: !_processingInput,
            decoration: InputDecoration(
              hintText: 'UPC, nombre o código...',
              prefixIcon: _processingInput
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search_rounded),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _debounce?.cancel();
                        _searchCtrl.clear();
                      },
                    )
                  : null,
            ),
            onChanged: _handleTypedSearch,
            onSubmitted: _handleSearchSubmitted,
          ),
          const SizedBox(height: 10),
          // Botón de cámara independiente (más amigable que el del AppBar)
          OutlinedButton.icon(
            onPressed: _processingInput ? null : _toggleScanner,
            icon: Icon(
              _isScannerVisible
                  ? Icons.camera_alt_rounded
                  : Icons.qr_code_scanner_rounded,
              size: 18,
            ),
            label: Text(
              _isScannerVisible ? 'Cerrar cámara' : 'Escanear código de barras',
              style: TextStyle(fontSize: context.sp(13)),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Surtido actual',
              style: TextStyle(
                fontSize: context.sp(15),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_items.length}',
                style: TextStyle(
                  fontSize: context.sp(12),
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
              ),
            ),
            const Spacer(),
            if (_items.isNotEmpty)
              Text(
                '\$${_total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: context.sp(16),
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_items.isEmpty) _buildEmptyState(cs),
        ..._items.asMap().entries.map(
              (e) => _buildItemCard(e.value, e.key, cs),
            ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.3),
            style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(
            Icons.qr_code_scanner_rounded,
            size: 44,
            color: cs.onSurface.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin artículos aún',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: context.sp(15),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Escanea un código de barras o\nbusca por nombre para comenzar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5),
              fontSize: context.sp(13),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ReceptionItem item, int index, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: context.sp(14),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.upc,
                  style: TextStyle(
                    fontSize: context.sp(11),
                    color: cs.onSurface.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Costo: \$${item.costPrice.toStringAsFixed(2)} x ${item.quantity.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: context.sp(12),
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '= \$${item.subtotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: context.sp(12),
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Qty controls
          Column(
            children: [
              _QtyBtn(
                icon: Icons.add_rounded,
                onTap: () => _updateItemQty(index, item.quantity + 1),
                colorScheme: cs,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${item.quantity.toInt()}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: context.sp(18),
                  ),
                ),
              ),
              _QtyBtn(
                icon: Icons.remove_rounded,
                onTap: () => _updateItemQty(index, item.quantity - 1),
                colorScheme: cs,
                isDanger: item.quantity <= 1,
              ),
            ],
          ),
          const SizedBox(width: 8),

          // Remove button
          IconButton(
            onPressed: () => _updateItemQty(index, 0),
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.07),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ScannerPanel — panel animado con reticle custom
// ─────────────────────────────────────────────────────────────────────────────

class _ScannerPanel extends StatelessWidget {
  final bool isVisible;
  final bool isRunning;
  final MobileScannerController controller;
  final void Function(String code) onDetect;
  final VoidCallback onClose;
  final VoidCallback onRetry;

  const _ScannerPanel({
    required this.isVisible,
    required this.isRunning,
    required this.controller,
    required this.onDetect,
    required this.onClose,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      height: isVisible ? 240 : 0,
      child: AnimatedOpacity(
        opacity: isVisible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: ClipRRect(
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(28)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Camera feed
              if (isVisible)
                MobileScanner(
                  controller: controller,
                  errorBuilder: (ctx, error) => _ScannerErrorFallback(
                    onRetry: onRetry,
                  ),
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty || barcodes.first.rawValue == null)
                      return;
                    onDetect(barcodes.first.rawValue!);
                  },
                ),

              // Vignette
              if (isVisible)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.4),
                      ],
                    ),
                  ),
                ),

              // Reticle
              if (isVisible)
                Center(
                  child: CustomPaint(
                    size: const Size(240, 120),
                    painter: _ReticlePainter(),
                  ),
                ),

              // Scan line animation
              if (isVisible && isRunning)
                const Center(
                  child: _ScanLine(),
                ),

              // Hint label
              if (isVisible)
                Positioned(
                  bottom: 18,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Apunta al código de barras',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: context.sp(12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

              // Close button
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerErrorFallback extends StatelessWidget {
  final VoidCallback onRetry;
  const _ScannerErrorFallback({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined,
                color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text(
              'No se pudo acceder a la cámara',
              style: TextStyle(
                color: Colors.white70,
                fontSize: context.sp(14),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Reintentar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Línea de escaneo animada con CSS-style via TweenAnimationBuilder
class _ScanLine extends StatefulWidget {
  const _ScanLine();

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 110,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Stack(
          children: [
            Positioned(
              top: 4 + _anim.value * 98,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.greenAccent.shade200,
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reticle con esquinas dibujadas a mano
class _ReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const corner = 18.0;
    const len = 30.0;
    final r = const Radius.circular(corner);

    void drawCorner(Offset tl, bool flipX, bool flipY) {
      final sx = flipX ? -1.0 : 1.0;
      final sy = flipY ? -1.0 : 1.0;
      final path = Path()
        ..moveTo(tl.dx, tl.dy + sy * len)
        ..lineTo(tl.dx, tl.dy + sy * corner)
        ..arcToPoint(
          Offset(tl.dx + sx * corner, tl.dy),
          radius: r,
          clockwise: !(flipX ^ flipY),
        )
        ..lineTo(tl.dx + sx * len, tl.dy);
      canvas.drawPath(path, paint);
    }

    drawCorner(Offset.zero, false, false);
    drawCorner(Offset(size.width, 0), true, false);
    drawCorner(Offset(0, size.height), false, true);
    drawCorner(Offset(size.width, size.height), true, true);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Botón pill del AppBar para toggle scanner
class _ScannerToggleButton extends StatelessWidget {
  final bool isActive;
  final bool isProcessing;
  final VoidCallback onTap;

  const _ScannerToggleButton({
    required this.isActive,
    required this.isProcessing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: isProcessing ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? cs.primary : cs.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.close_rounded : Icons.qr_code_scanner_rounded,
              size: 17,
              color: isActive ? cs.onPrimary : cs.primary,
            ),
            const SizedBox(width: 6),
            Text(
              isActive ? 'Cerrar' : 'Escanear',
              style: TextStyle(
                fontSize: context.sp(13),
                fontWeight: FontWeight.w700,
                color: isActive ? cs.onPrimary : cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReceiveSummaryChip
// ─────────────────────────────────────────────────────────────────────────────

class _ReceiveSummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color tint;

  const _ReceiveSummaryChip(
      {required this.label, required this.value, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: context.sp(10),
              fontWeight: FontWeight.w800,
              color: tint,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: context.sp(14),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QtyBtn
// ─────────────────────────────────────────────────────────────────────────────

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final bool isDanger;

  const _QtyBtn({
    required this.icon,
    required this.onTap,
    required this.colorScheme,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? Colors.red : colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SupplierProductLookupScreen
// ─────────────────────────────────────────────────────────────────────────────

class _SupplierProductLookupScreen extends StatefulWidget {
  final String initialQuery;
  const _SupplierProductLookupScreen({this.initialQuery = ''});

  @override
  State<_SupplierProductLookupScreen> createState() =>
      _SupplierProductLookupScreenState();
}

class _SupplierProductLookupScreenState
    extends State<_SupplierProductLookupScreen> {
  final TextEditingController _ctrl = TextEditingController();
  List<Product> _results = [];
  bool _loading = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
    if (widget.initialQuery.trim().isNotEmpty) {
      _ctrl.text = widget.initialQuery.trim();
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _search(widget.initialQuery.trim()));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    final q = _ctrl.text.trim();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _loading = false;
        _hasSearched = q.isNotEmpty;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _hasSearched = true;
    });
    final results =
        await context.read<BusinessRepository>().searchProducts(query);
    if (mounted)
      setState(() {
        _results = results;
        _loading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(
          'Buscar producto',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: context.sp(18),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nombre o UPC...',
                prefixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search_rounded),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: _ctrl.clear,
                      )
                    : null,
              ),
            ),
          ),

          // Info banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Primero tu inventario local, luego el catálogo global.',
                      style: TextStyle(
                        fontSize: context.sp(12),
                        color: cs.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _hasSearched
                                    ? Icons.search_off_rounded
                                    : Icons.manage_search_rounded,
                                size: 52,
                                color: cs.onSurface.withValues(alpha: 0.2),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _hasSearched
                                    ? 'Sin coincidencias'
                                    : 'Escribe para buscar',
                                style: TextStyle(
                                  fontSize: context.sp(16),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _hasSearched
                                    ? 'Prueba con otra parte del nombre o el UPC completo.'
                                    : 'Mínimo 2 caracteres para buscar en tu inventario y el catálogo global.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: context.sp(13),
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemBuilder: (context, index) {
                          final p = _results[index];
                          final isGlobal = p.price <= 0;
                          final tint = isGlobal ? Colors.orange : Colors.green;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    cs.outlineVariant.withValues(alpha: 0.35),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: tint.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isGlobal
                                      ? Icons.public_rounded
                                      : Icons.store_rounded,
                                  color: tint,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                p.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: context.sp(14),
                                ),
                              ),
                              subtitle: Text(
                                '${isGlobal ? 'Global' : 'Local'} · ${p.upc}',
                                style: TextStyle(
                                  fontSize: context.sp(11),
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: tint.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  isGlobal
                                      ? 'Sin costo'
                                      : '\$${p.price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: tint,
                                    fontWeight: FontWeight.w800,
                                    fontSize: context.sp(12),
                                  ),
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              onTap: () => Navigator.pop(context, p),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReceptionItemEditor
// ─────────────────────────────────────────────────────────────────────────────

class _ReceptionItemEditor extends StatefulWidget {
  final Product product;
  const _ReceptionItemEditor({required this.product});

  @override
  State<_ReceptionItemEditor> createState() => _ReceptionItemEditorState();
}

class _ReceptionItemEditorState extends State<_ReceptionItemEditor> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _costCtrl;

  double get _qty => double.tryParse(_qtyCtrl.text) ?? 0.0;
  double get _cost => double.tryParse(_costCtrl.text) ?? 0.0;
  double get _subtotal => _qty * _cost;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: '1');
    _costCtrl = TextEditingController(
      text: widget.product.costPrice > 0
          ? widget.product.costPrice.toStringAsFixed(2)
          : '',
    );
    _qtyCtrl.addListener(() => setState(() {}));
    _costCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Product info
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.inventory_2_rounded,
                    color: cs.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: context.sp(16),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      widget.product.upc,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: context.sp(12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Fields
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,1}')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    prefixIcon: Icon(Icons.format_list_numbered_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _costCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Costo unitario',
                    prefixText: '\$ ',
                    prefixIcon: Icon(Icons.sell_outlined),
                  ),
                ),
              ),
            ],
          ),

          // Live subtotal
          if (_qty > 0 && _cost > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_qty.toStringAsFixed(0)} × \$${_cost.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: context.sp(14),
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    '= \$${_subtotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: context.sp(18),
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          FilledButton(
            onPressed: () {
              if (_qty <= 0 || _cost <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ingresa cantidad y costo válidos'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.pop(
                context,
                ReceptionItem(
                  id: '',
                  transactionId: '',
                  upc: widget.product.upc,
                  productName: widget.product.name,
                  quantity: _qty,
                  costPrice: _cost,
                  subtotal: _subtotal,
                ),
              );
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              'AGREGAR AL SURTIDO',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: context.sp(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
