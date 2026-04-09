import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/supplier.dart';
import '../../data/models/reception.dart';
import '../../data/repositories/business_repository.dart';

// Events
abstract class SuppliersEvent extends Equatable {
  const SuppliersEvent();
  @override
  List<Object?> get props => [];
}

class SuppliersStarted extends SuppliersEvent {}
class SuppliersCallRequested extends SuppliersEvent {
  final String phone;
  const SuppliersCallRequested(this.phone);
  @override
  List<Object?> get props => [phone];
}
class SuppliersDebtPaid extends SuppliersEvent {
  final String supplierId;
  final double amount;
  const SuppliersDebtPaid(this.supplierId, this.amount);
  @override
  List<Object?> get props => [supplierId, amount];
}

class SuppliersAdded extends SuppliersEvent {
  final Supplier supplier;
  const SuppliersAdded(this.supplier);
  @override
  List<Object?> get props => [supplier];
}

class SuppliersDebtAdded extends SuppliersEvent {
  final String supplierId;
  final double amount;
  const SuppliersDebtAdded(this.supplierId, this.amount);
  @override
  List<Object?> get props => [supplierId, amount];
}

class SuppliersReceptionRecorded extends SuppliersEvent {
  final Reception reception;
  const SuppliersReceptionRecorded(this.reception);
  @override
  List<Object?> get props => [reception];
}

// States
abstract class SuppliersState extends Equatable {
  const SuppliersState();
  @override
  List<Object?> get props => [];
}

class SuppliersInitial extends SuppliersState {}
class SuppliersLoading extends SuppliersState {}
class SuppliersLoaded extends SuppliersState {
  final List<Supplier> suppliers;
  const SuppliersLoaded(this.suppliers);
  @override
  List<Object?> get props => [suppliers];
}

// BLoC
class SuppliersBloc extends Bloc<SuppliersEvent, SuppliersState> {
  final BusinessRepository _repository;

  SuppliersBloc(this._repository) : super(SuppliersInitial()) {
    on<SuppliersStarted>(_onStarted);
    on<SuppliersCallRequested>(_onCallRequested);
    on<SuppliersDebtPaid>(_onDebtPaid);
    on<SuppliersAdded>(_onAdded);
    on<SuppliersDebtAdded>(_onDebtAdded);
    on<SuppliersReceptionRecorded>(_onReceptionRecorded);
  }

  void _onStarted(SuppliersStarted event, Emitter<SuppliersState> emit) async {
    emit(SuppliersLoading());
    await emit.forEach<List<Supplier>>(
      _repository.watchSuppliers(),
      onData: (data) => SuppliersLoaded(data),
    );
  }

  void _onCallRequested(SuppliersCallRequested event, Emitter<SuppliersState> emit) async {
    final Uri url = Uri.parse('tel:${event.phone}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _onDebtPaid(
      SuppliersDebtPaid event, Emitter<SuppliersState> emit) async {
    try {
      await _repository.paySupplierDebt(event.supplierId, event.amount);
    } catch (error) {
      debugPrint('SuppliersBloc.paySupplierDebt error: $error');
    }
  }

  void _onAdded(SuppliersAdded event, Emitter<SuppliersState> emit) {
    _repository.addSupplier(event.supplier);
  }

  void _onDebtAdded(SuppliersDebtAdded event, Emitter<SuppliersState> emit) {
    _repository.addSupplierDebt(event.supplierId, event.amount);
  }

  void _onReceptionRecorded(SuppliersReceptionRecorded event, Emitter<SuppliersState> emit) {
    _repository.recordReception(event.reception);
  }
}
