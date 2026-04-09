import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/cash_service.dart';
import '../../models/error_response.dart';

// ═══════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════

abstract class CashEvent extends Equatable {
  const CashEvent();
  @override
  List<Object> get props => [];
}

/// Evento inicial: carga el estado del dashboard desde el backend.
class CashDashboardLoaded extends CashEvent {}

/// Resetea el estado de la caja (Llamado al cerrar sesión).
class CashReset extends CashEvent {}

/// Pide abrir la caja con un fondo inicial.
class CashOpenRequested extends CashEvent {
  final double amount;
  const CashOpenRequested(this.amount);
  @override
  List<Object> get props => [amount];
}

/// Pide cerrar la caja con el efectivo contado.
class CashCloseRequested extends CashEvent {
  final double actualCash;
  const CashCloseRequested(this.actualCash);
  @override
  List<Object> get props => [actualCash];
}

/// Registra un gasto contra la caja abierta.
class CashExpenseAdded extends CashEvent {
  final String category;
  final String description;
  final double amount;
  final String paymentMethod;
  const CashExpenseAdded({
    required this.category,
    required this.description,
    required this.amount,
    this.paymentMethod = 'CASH',
  });
  @override
  List<Object> get props => [category, description, amount, paymentMethod];
}

/// Registra una venta (para actualizar totales localmente).
class CashSaleRecorded extends CashEvent {
  final double amount;
  final String type; // 'CASH', 'CARD', 'TRANSFER'
  const CashSaleRecorded(this.amount, this.type);
  @override
  List<Object> get props => [amount, type];
}

// ═══════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════

abstract class CashState extends Equatable {
  const CashState();
  @override
  List<Object> get props => [];
}

/// Estado de carga inicial.
class CashLoading extends CashState {}

/// Caja cerrada — el usuario debe abrirla para operar.
class CashClosed extends CashState {
  /// Última sesión cerrada (puede ser null si nunca ha abierto una).
  final Map<String, dynamic>? lastClosedSession;

  /// Mensajes del backend (ej: "No hay sesión abierta...").
  final List<String> messages;

  const CashClosed({this.lastClosedSession, this.messages = const []});
  @override
  List<Object> get props => [messages];
}

/// Caja abierta — operación activa.
class CashOpen extends CashState {
  const CashOpen({
    required this.sessionId,
    required this.initialAmount,
    this.totalSales = 0.0,
    this.cashTotal = 0.0,
    this.cardTotal = 0.0,
    this.transferTotal = 0.0,
    this.totalExpenses = 0.0,
    this.supplierPayments = 0.0,
    this.openedAt = '',
  });

  final String sessionId;
  final double initialAmount;
  final double totalSales;
  final double cashTotal;
  final double cardTotal;
  final double transferTotal;
  final double totalExpenses;
  final double supplierPayments;
  final String openedAt;

  double get expectedCash =>
      initialAmount + cashTotal - totalExpenses - supplierPayments;

  CashOpen copyWith({
    double? totalSales,
    double? cashTotal,
    double? cardTotal,
    double? transferTotal,
    double? totalExpenses,
    double? supplierPayments,
  }) {
    return CashOpen(
      sessionId: sessionId,
      initialAmount: initialAmount,
      totalSales: totalSales ?? this.totalSales,
      cashTotal: cashTotal ?? this.cashTotal,
      cardTotal: cardTotal ?? this.cardTotal,
      transferTotal: transferTotal ?? this.transferTotal,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      supplierPayments: supplierPayments ?? this.supplierPayments,
      openedAt: openedAt,
    );
  }

  @override
  List<Object> get props => [
        sessionId,
        initialAmount,
        totalSales,
        cashTotal,
        cardTotal,
        transferTotal,
        totalExpenses,
        supplierPayments
      ];
}

/// Corte exitoso — muestra el resumen al usuario.
class CashCloseSuccess extends CashState {
  final double expectedCash;
  final double actualCash;
  final double difference;

  const CashCloseSuccess({
    required this.expectedCash,
    required this.actualCash,
    required this.difference,
  });

  @override
  List<Object> get props => [expectedCash, actualCash, difference];
}

/// Estado de error genérico.
class CashError extends CashState {
  final String message;
  const CashError(this.message);
  @override
  List<Object> get props => [message];
}

/// Estado de procesamiento (Apertura, Cierre, Gasto).
class CashProcessing extends CashState {
  final String message;
  const CashProcessing(this.message);
  @override
  List<Object> get props => [message];
}

// ═══════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════

class CashBloc extends Bloc<CashEvent, CashState> {
  final CashService _cashService;

  CashBloc(this._cashService) : super(CashLoading()) {
    on<CashDashboardLoaded>(_onDashboardLoaded);
    on<CashOpenRequested>(_onOpenRequested);
    on<CashCloseRequested>(_onCloseRequested);
    on<CashExpenseAdded>(_onExpenseAdded);
    on<CashSaleRecorded>(_onSaleRecorded);
    on<CashReset>(_onReset);
  }

  void _onReset(CashReset event, Emitter<CashState> emit) {
    _cashService.reset();
    emit(CashLoading());
  }

  // ─── Dashboard Init ──────────────────────────
  Future<void> _onDashboardLoaded(
    CashDashboardLoaded event,
    Emitter<CashState> emit,
  ) async {
    emit(CashLoading());

    final data = await _cashService.loadDashboard();
    final bool hasOpen = data['hasOpenCashSession'] ?? false;

    if (hasOpen && data['cashSession'] != null) {
      final session = data['cashSession'] as Map<String, dynamic>;
      emit(CashOpen(
        sessionId: session['id']?.toString() ?? '',
        initialAmount: (session['initialAmount'] ?? 0).toDouble(),
        totalSales: (session['totalSales'] ?? 0).toDouble(),
        cashTotal: (session['cashTotal'] ?? 0).toDouble(),
        cardTotal: (session['cardTotal'] ?? 0).toDouble(),
        transferTotal: (session['transferTotal'] ?? 0).toDouble(),
        totalExpenses: (session['totalExpenses'] ?? 0).toDouble(),
        supplierPayments: (session['supplierPayments'] ?? 0).toDouble(),
        openedAt: session['openedAt']?.toString() ?? '',
      ));
    } else {
      final messages = (data['messages'] as List<dynamic>?)
              ?.map((m) => m.toString())
              .toList() ??
          [];
      emit(CashClosed(
        lastClosedSession: data['lastClosedSession'] as Map<String, dynamic>?,
        messages: messages,
      ));
    }
  }

  // ─── Abrir Caja ──────────────────────────────
  Future<void> _onOpenRequested(
    CashOpenRequested event,
    Emitter<CashState> emit,
  ) async {
    final previousState = state;
    emit(const CashProcessing('Abriendo caja...'));
    try {
      final result = await _cashService.openCash(event.amount);

      if (result != null) {
        emit(CashOpen(
          sessionId: result['id']?.toString() ?? '',
          initialAmount: (result['initialAmount'] ?? 0).toDouble(),
          totalSales: (result['totalSales'] ?? 0).toDouble(),
          cashTotal: (result['cashTotal'] ?? 0).toDouble(),
          cardTotal: (result['cardTotal'] ?? 0).toDouble(),
          transferTotal: (result['transferTotal'] ?? 0).toDouble(),
          totalExpenses: (result['totalExpenses'] ?? 0).toDouble(),
          supplierPayments: (result['supplierPayments'] ?? 0).toDouble(),
          openedAt: result['openedAt']?.toString() ?? '',
        ));
      } else {
        emit(const CashError('No se pudo abrir la caja. Intenta de nuevo.'));
      }
    } catch (e) {
      if (e is ErrorResponse) {
        emit(CashError(e.message));
      } else {
        emit(const CashError(
            'Error al abrir caja localmente. Recarga el dashboard.'));
      }
      // Volver al estado anterior después del error para que el usuario pueda reintentar
      if (previousState is CashClosed) {
        emit(previousState);
      }
    }
  }

  // ─── Cerrar Caja (Corte) ─────────────────────
  Future<void> _onCloseRequested(
    CashCloseRequested event,
    Emitter<CashState> emit,
  ) async {
    final previousState = state;
    emit(const CashProcessing('Cerrando caja y calculando diferencias...'));
    try {
      final result = await _cashService.closeCash(event.actualCash);

      if (result != null) {
        // Primero mostramos el resumen del corte
        emit(CashCloseSuccess(
          expectedCash: (result['expectedCash'] ?? 0).toDouble(),
          actualCash: (result['actualCash'] ?? 0).toDouble(),
          difference: (result['difference'] ?? 0).toDouble(),
        ));
      } else {
        emit(const CashError('No se pudo cerrar la caja. Intenta de nuevo.'));
      }
    } catch (e) {
      if (e is ErrorResponse) {
        emit(CashError(e.message));
      } else {
        emit(const CashError('Error al cerrar caja localmente'));
      }
      if (previousState is CashOpen) {
        emit(previousState);
      }
    }
  }

  // ─── Registrar Gasto ─────────────────────────
  Future<void> _onExpenseAdded(
    CashExpenseAdded event,
    Emitter<CashState> emit,
  ) async {
    final previousState = state;
    final sessionId = await _cashService.currentSessionId;
    if (sessionId == null) {
      emit(const CashError('No se encontró una sesión de caja activa'));
      return;
    }

    emit(const CashProcessing('Registrando gasto...'));
    try {
      final success = await _cashService.addExpense(
        cashSessionId: sessionId,
        category: event.category,
        description: event.description,
        amount: event.amount,
        paymentMethod: event.paymentMethod,
      );

      if (success) {
        // Recargar el dashboard para obtener totales actualizados
        add(CashDashboardLoaded());
      }
    } catch (e) {
      if (e is ErrorResponse) {
        emit(CashError(e.message));
      }
      if (previousState is CashOpen) {
        emit(previousState);
      }
    }
  }

  // ─── Registrar Venta (Local + Futuro Backend) ─
  void _onSaleRecorded(
    CashSaleRecorded event,
    Emitter<CashState> emit,
  ) {
    if (state is CashOpen) {
      final s = state as CashOpen;
      if (event.type == 'CASH') {
        emit(s.copyWith(
          cashTotal: s.cashTotal + event.amount,
          totalSales: s.totalSales + event.amount,
        ));
      } else if (event.type == 'CARD') {
        emit(s.copyWith(
          cardTotal: s.cardTotal + event.amount,
          totalSales: s.totalSales + event.amount,
        ));
      } else if (event.type == 'TRANSFER') {
        emit(s.copyWith(
          transferTotal: s.transferTotal + event.amount,
          totalSales: s.totalSales + event.amount,
        ));
      }
    }
  }
}
