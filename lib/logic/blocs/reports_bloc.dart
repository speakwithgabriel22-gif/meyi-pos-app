import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/business_repository.dart';

// Events
abstract class ReportsEvent extends Equatable {
  const ReportsEvent();
  @override
  List<Object?> get props => [];
}

class ReportsStarted extends ReportsEvent {}
class ReportsUpdateRequested extends ReportsEvent {}

// States
abstract class ReportsState extends Equatable {
  const ReportsState();
  @override
  List<Object?> get props => [];
}

class ReportsInitial extends ReportsState {}
class ReportsLoading extends ReportsState {}
class ReportsLoaded extends ReportsState {
  final Map<String, dynamic> metrics;
  const ReportsLoaded(this.metrics);
  @override
  List<Object?> get props => [metrics];
}

// BLoC
class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final BusinessRepository _repository;

  ReportsBloc(this._repository) : super(ReportsInitial()) {
    on<ReportsStarted>(_onStarted);
    on<ReportsUpdateRequested>(_onUpdateRequested);
  }

  void _onStarted(ReportsStarted event, Emitter<ReportsState> emit) async {
    final metrics = await _repository.getTodayMetrics();
    emit(ReportsLoaded(metrics));
  }

  void _onUpdateRequested(ReportsUpdateRequested event, Emitter<ReportsState> emit) async {
    emit(ReportsLoading());
    final metrics = await _repository.getTodayMetrics();
    emit(ReportsLoaded(metrics));
  }
}
