import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/expense.dart';

// --- Events ---
abstract class CashEvent extends Equatable {
  const CashEvent();
  @override List<Object> get props => [];
}

class CashOpenRequested extends CashEvent {
  final double amount;
  const CashOpenRequested(this.amount);
  @override List<Object> get props => [amount];
}

class CashExpenseAdded extends CashEvent {
  final Expense expense;
  const CashExpenseAdded(this.expense);
  @override List<Object> get props => [expense];
}

class CashSaleRecorded extends CashEvent {
  final double amount;
  final String type; // 'Efectivo', 'Tarjeta', 'Transferencia'
  const CashSaleRecorded(this.amount, this.type);
  @override List<Object> get props => [amount, type];
}

class CashCloseRequested extends CashEvent {}

// --- States ---
abstract class CashState extends Equatable {
  const CashState();
  @override List<Object> get props => [];
}

class CashClosed extends CashState {}

class CashOpen extends CashState {
  final double initialAmount;
  final double cashSales;
  final double cardSales;
  final double transferSales;
  final List<Expense> expenses;

  const CashOpen(
    this.initialAmount, {
    this.cashSales = 0.0,
    this.cardSales = 0.0,
    this.transferSales = 0.0,
    this.expenses = const [],
  });

  double get currentSales => cashSales + cardSales + transferSales;
  double get totalExpenses => expenses.fold(0, (sum, e) => sum + e.amount);
  double get expectedCash => initialAmount + cashSales - totalExpenses;

  @override List<Object> get props => [initialAmount, cashSales, cardSales, transferSales, expenses];

  CashOpen copyWith({
    double? initialAmount,
    double? cashSales,
    double? cardSales,
    double? transferSales,
    List<Expense>? expenses,
  }) {
    return CashOpen(
      initialAmount ?? this.initialAmount,
      cashSales: cashSales ?? this.cashSales,
      cardSales: cardSales ?? this.cardSales,
      transferSales: transferSales ?? this.transferSales,
      expenses: expenses ?? this.expenses,
    );
  }
}

// --- BLoC ---
class CashBloc extends Bloc<CashEvent, CashState> {
  CashBloc() : super(CashClosed()) {
    on<CashOpenRequested>((event, emit) {
      emit(CashOpen(event.amount));
    });

    on<CashExpenseAdded>((event, emit) {
      if (state is CashOpen) {
        final s = state as CashOpen;
        emit(s.copyWith(expenses: [...s.expenses, event.expense]));
      }
    });

    on<CashSaleRecorded>((event, emit) {
      if (state is CashOpen) {
        final s = state as CashOpen;
        if (event.type == 'Efectivo') {
          emit(s.copyWith(cashSales: s.cashSales + event.amount));
        } else if (event.type == 'Tarjeta') {
          emit(s.copyWith(cardSales: s.cardSales + event.amount));
        } else if (event.type == 'Transferencia') {
          emit(s.copyWith(transferSales: s.transferSales + event.amount));
        }
      }
    });

    on<CashCloseRequested>((event, emit) {
      emit(CashClosed());
    });
  }
}
