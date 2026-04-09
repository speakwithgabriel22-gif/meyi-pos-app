import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/sale.dart';
import '../../data/models/cash_movement.dart';
import '../../data/repositories/business_repository.dart';

// Events
abstract class SalesHistoryEvent extends Equatable {
  const SalesHistoryEvent();
  @override
  List<Object?> get props => [];
}

class SalesHistoryStarted extends SalesHistoryEvent {}
class SalesRecordRequested extends SalesHistoryEvent {
  final Sale sale;
  const SalesRecordRequested(this.sale);
}

// States
abstract class SalesHistoryState extends Equatable {
  const SalesHistoryState();
  @override
  List<Object?> get props => [];
}

class SalesHistoryInitial extends SalesHistoryState {}
class SalesHistoryLoading extends SalesHistoryState {}
class SalesHistoryLoaded extends SalesHistoryState {
  final List<CashMovement> movements;
  const SalesHistoryLoaded(this.movements);
  @override
  List<Object?> get props => [movements];
}

// BLoC
class SalesHistoryBloc extends Bloc<SalesHistoryEvent, SalesHistoryState> {
  final BusinessRepository _repository;

  SalesHistoryBloc(this._repository) : super(SalesHistoryInitial()) {
    on<SalesHistoryStarted>(_onStarted);
    on<SalesRecordRequested>(_onRecordRequested);
  }

  void _onStarted(SalesHistoryStarted event, Emitter<SalesHistoryState> emit) async {
    emit(SalesHistoryLoading());
    await emit.forEach<List<CashMovement>>(
      _repository.watchCashMovements(),
      onData: (data) => SalesHistoryLoaded(data),
    );
  }

  void _onRecordRequested(SalesRecordRequested event, Emitter<SalesHistoryState> emit) {
    _repository.recordSale(event.sale);
  }
}
