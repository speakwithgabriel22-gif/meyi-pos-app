import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:vibration/vibration.dart';
import '../../logic/blocs/reports_bloc.dart';
import '../../logic/blocs/cash_bloc.dart';
import '../../logic/blocs/auth_bloc.dart';
import '../../logic/blocs/suppliers_bloc.dart';
import '../../data/models/supplier.dart';
import '../../widgets/professional_background.dart';
import '../../widgets/institutional_footer.dart';
import '../../data/models/expense.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) context.go('/login');
      },
      child: BlocListener<CashBloc, CashState>(
        listenWhen: (prev, curr) => prev is CashOpen && curr is CashClosed,
        listener: (context, state) {
          _showChampionDialog(context);
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Mi Negocio Hoy',
                style: TextStyle(fontWeight: FontWeight.w900)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final initial = (state is AuthAuthenticated &&
                              state.userName.isNotEmpty)
                          ? state.userName[0].toUpperCase()
                          : 'U';
                      return CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          body: ProfessionalBackground(
            child: Column(
              children: [
                Expanded(
                  child: BlocBuilder<ReportsBloc, ReportsState>(
                    builder: (context, state) {
                      if (state is ReportsLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is ReportsLoaded) {
                        final metrics = state.metrics;
                        return BlocBuilder<CashBloc, CashState>(
                          builder: (context, cashState) {
                            final bool isClosed = cashState is CashClosed;

                            return SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 16),
                              child: Column(
                                children: [
                                  _TodayVisitsReminder(),
                                  const SizedBox(height: 16),

                                  _CashHeroActionCard(),
                                  const SizedBox(height: 24),

                                  if (isClosed)
                                    _CajaCerradaPlaceholder()
                                  else ...[
                                    const _NewSaleHero(),
                                    const SizedBox(height: 24),

                                    _MainMetricCard(
                                      label: 'VENTA TOTAL HOY',
                                      value:
                                          '\$${(metrics['totalSales'] as double).toStringAsFixed(0)}',
                                      delta:
                                          metrics['yesterdayDelta'] as double,
                                    ),
                                    const SizedBox(height: 32),

                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('RESUMEN DE CUENTAS',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                              letterSpacing: 1.2)),
                                    ),
                                    const SizedBox(height: 16),

                                    _PaymentRow(
                                        label: 'Efectivo',
                                        value: metrics['cashTotal'],
                                        color: Colors.green),
                                    _PaymentRow(
                                        label: 'Tarjeta',
                                        value: metrics['cardTotal'],
                                        color: Colors.blue),
                                    _PaymentRow(
                                        label: 'Transferencia',
                                        value: metrics['transfTotal'],
                                        color: Colors.orange),
                                  ],
                                ],
                              ),
                            );
                          },
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
        ),
      ),
    );
  }

  void _showChampionDialog(BuildContext context) {
    Vibration.vibrate(pattern: [0, 100, 50, 200]);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/animations/successfully-done.json',
                  height: 180, repeat: false),
              const SizedBox(height: 16),
              Text('¡ERES UN CAMPEÓN!',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Text(
                  'Has cerrado tu caja con éxito. Tu reporte diario ha sido generado y guardado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), 
                    fontSize: 14
                  )
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: const Text('¡GENIAL, GRACIAS!',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CashHeroActionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CashBloc, CashState>(
      builder: (context, state) {
        final isClosed = state is CashClosed;
        final colorScheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isClosed 
                ? (isDark ? colorScheme.surfaceVariant.withOpacity(0.3) : Colors.grey.shade50) 
                : colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
                color: isClosed
                    ? (isDark ? Colors.white10 : Colors.grey.shade300)
                    : colorScheme.primary.withOpacity(0.3),
                width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isClosed
                        ? Colors.grey.shade700
                        : colorScheme.primary,
                    child: Icon(
                        isClosed ? Icons.lock_rounded : Icons.sensors_rounded,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isClosed ? 'CAJA CERRADA' : 'SISTEMA ACTIVO',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isClosed
                                  ? (isDark ? Colors.white38 : Colors.grey)
                                  : colorScheme.primary,
                              letterSpacing: 1.2)),
                      Text(
                          isClosed ? 'Listo para iniciar' : 'Recibiendo ventas',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSurface)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                isClosed
                    ? 'Abre la caja para comenzar a registrar ventas y ver tus ganancias de hoy.'
                    : 'Tu caja está abierta. Al terminar tu jornada, realiza el corte para generar el reporte.',
                style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6), 
                    fontSize: 13, 
                    height: 1.4
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => isClosed
                          ? _showOpenCash(context)
                          : _showCloseCash(context, state as CashOpen),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(60),
                        backgroundColor: isClosed
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        foregroundColor: isClosed
                            ? colorScheme.onPrimary
                            : colorScheme.surface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isClosed ? 'ABRIR CAJA' : 'REALIZAR CORTE',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!isClosed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddExpense(context),
                        icon: const Icon(Icons.outbox_rounded, size: 20),
                        label: const Text('GASTO', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(60),
                          foregroundColor: colorScheme.onSurface,
                          side: BorderSide(color: colorScheme.onSurface.withOpacity(0.1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOpenCash(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
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
            Text('Apertura de Caja',
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface
                )),
            const SizedBox(height: 24),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: TextStyle(
                fontSize: 42, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface
              ),
              decoration: InputDecoration(
                  labelText: 'Fondo Inicial', 
                  prefixText: '\$ ',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final a = double.tryParse(ctrl.text) ?? 0.0;
                context.read<CashBloc>().add(CashOpenRequested(a));
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('CONFIRMAR APERTURA'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExpense(BuildContext context) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
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
            const Text('Anotar Gasto Rápido',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(labelText: 'Monto', prefixText: '\$ '),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Concepto (Gas, Surtido, etc.)',
                prefixIcon: Icon(Icons.description_rounded),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                final desc = descCtrl.text.trim();
                if (amount > 0 && desc.isNotEmpty) {
                  final expense = Expense(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    description: desc,
                    amount: amount,
                    timestamp: DateTime.now(),
                  );
                  context.read<CashBloc>().add(CashExpenseAdded(expense));
                  Navigator.pop(ctx);
                  Vibration.vibrate(duration: 50);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Gasto por \$${amount.toStringAsFixed(0)} registrado'), behavior: SnackBarBehavior.floating),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('REGISTRAR GASTO'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCloseCash(BuildContext context, CashOpen state) {
    final manualCtrl = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final double manualAmount = double.tryParse(manualCtrl.text) ?? 0.0;
          final double diff = manualAmount - state.expectedCash;
          final bool hasShortage = diff < -2;

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
                left: 32,
                right: 32,
                top: 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Corte de Caja',
                      style: TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface
                      )),
                  const SizedBox(height: 24),
                  _row(context, 'Fondo de Apertura', state.initialAmount),
                  _row(context, 'Ventas en Efectivo (+)', state.cashSales),
                  _row(context, 'Ventas con Tarjeta', state.cardSales),
                  _row(context, 'Ventas con Transferencia', state.transferSales),
                  _row(context, 'Gastos de Turno (-)', state.totalExpenses, isRed: true),
                  const Divider(height: 32),
                  _row(context, 'EFECTIVO ESPERADO EN CAJA', state.expectedCash, strong: true),
                  
                  const SizedBox(height: 32),
                  TextField(
                    controller: manualCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cs.onSurface),
                    decoration: InputDecoration(
                        labelText: 'Ingresa efectivo físico en caja', 
                        prefixText: '\$ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        labelStyle: TextStyle(color: cs.onSurface.withOpacity(0.5))
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  
                  if (manualCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: hasShortage ? cs.error.withOpacity(0.12) : Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(hasShortage ? '⚠️ FALTANTE EN CAJA' : '✅ CAJA CUADRADA',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: hasShortage ? cs.error : Colors.green,
                                    fontSize: 12
                                  )),
                              Text('\$${diff.abs().toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: hasShortage ? cs.error : Colors.green,
                                    fontSize: 16
                                  )),
                            ],
                          ),
                          if (hasShortage)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text('El monto físico es menor al esperado.', 
                                  style: TextStyle(fontSize: 11, color: Colors.red)),
                            ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      context.read<CashBloc>().add(CashCloseRequested());
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasShortage ? cs.error : cs.onSurface,
                      foregroundColor: cs.surface,
                      minimumSize: const Size.fromHeight(60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(hasShortage ? 'CERRAR CON FALTANTE' : 'REALIZAR CORTE'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, String label, double val, {bool strong = false, bool isRed = false}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 16,
                  color: cs.onSurface.withOpacity(strong ? 1 : 0.7),
                  fontWeight: strong ? FontWeight.bold : FontWeight.normal)),
          Text('${isRed ? "- " : ""}\$${val.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 16,
                  color: isRed ? cs.error : cs.onSurface,
                  fontWeight: strong ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _NewSaleHero extends StatelessWidget {
  const _NewSaleHero();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CashBloc, CashState>(
      builder: (context, state) {
        final bool isClosed = state is CashClosed;
        final colorScheme = Theme.of(context).colorScheme;

        return Hero(
          tag: 'btnVenta',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isClosed ? null : () => context.push('/venta'),
              borderRadius: BorderRadius.circular(32),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: isClosed
                      ? LinearGradient(
                          colors: [Colors.grey.shade600, Colors.grey.shade800])
                      : LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary]),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    if (!isClosed)
                      BoxShadow(
                          color: colorScheme.primary.withOpacity(0.3),
                          blurRadius: 20)
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_shopping_cart_rounded,
                        size: 42, color: Colors.white),
                    const SizedBox(width: 16),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('NUEVA VENTA',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5)),
                        Text(isClosed ? 'CAJA CERRADA' : 'CÁMARA AUTO-ACTIVADA',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _PaymentRow(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.02),
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 16),
          Text(label,
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface
              )),
          const Spacer(),
          Text('\$${value.toStringAsFixed(2)}',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }
}

class _CajaCerradaPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: isDark ? cs.surface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.visibility_off_rounded,
              size: 64, color: cs.onSurface.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text('DATOS OCULTOS',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface.withOpacity(0.3),
                  letterSpacing: 2)),
          const SizedBox(height: 8),
          Text('Abre caja para ver las ventas de hoy',
              style: TextStyle(color: cs.onSurface.withOpacity(0.4)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _MainMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final double delta;
  const _MainMetricCard(
      {required this.label, required this.value, required this.delta});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)
        ],
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_upward_rounded,
                    color: Colors.green, size: 18),
                const SizedBox(width: 4),
                Text('\$${delta.toStringAsFixed(0)} más que ayer',
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayVisitsReminder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SuppliersBloc, SuppliersState>(
      builder: (context, state) {
        if (state is SuppliersLoaded) {
          final today = _getTodayName();
          final visitToday = state.suppliers.where((s) => s.visitDay.contains(today)).toList();
          
          if (visitToday.isEmpty) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.event_available_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Hoy te visita: ${visitToday.map((s) => s.name.split(' ')[0]).join(', ')}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 13
                    ),
                  ),
                ),
                Text('⚠️ Prepara efectivo', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  String _getTodayName() {
    final days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return days[DateTime.now().weekday - 1];
  }
}
