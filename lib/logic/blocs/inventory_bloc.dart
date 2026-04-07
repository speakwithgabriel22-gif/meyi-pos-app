import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/product.dart';
import '../../data/repositories/business_repository.dart';

// Events
abstract class InventoryEvent extends Equatable {
  const InventoryEvent();
  @override
  List<Object?> get props => [];
}

class InventoryStarted extends InventoryEvent {}
class InventoryStockUpdated extends InventoryEvent {
  final String productId;
  final int delta;
  const InventoryStockUpdated(this.productId, this.delta);
}
class InventorySearchRequested extends InventoryEvent {
  final String query;
  const InventorySearchRequested(this.query);
}

class InventoryProductAdded extends InventoryEvent {
  final Product product;
  const InventoryProductAdded(this.product);
}

class InventoryScanRequested extends InventoryEvent {
  final String upc;
  const InventoryScanRequested(this.upc);
}

// States
abstract class InventoryState extends Equatable {
  const InventoryState();
  @override
  List<Object?> get props => [];
}

class InventoryInitial extends InventoryState {}
class InventoryLoading extends InventoryState {}
class InventoryLoaded extends InventoryState {
  final List<Product> products;
  final String searchQuery;
  final Product? lastScanned; // Para abrir el diálogo de alta si es nuevo
  const InventoryLoaded(this.products, {this.searchQuery = '', this.lastScanned});

  List<Product> get filteredProducts {
    if (searchQuery.isEmpty) return products;
    return products.where((p) => p.name.toLowerCase().contains(searchQuery.toLowerCase()) || p.upc.contains(searchQuery)).toList();
  }

  @override
  List<Object?> get props => [products, searchQuery, lastScanned];
}

// BLoC
class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final BusinessRepository _repository;

  InventoryBloc(this._repository) : super(InventoryInitial()) {
    on<InventoryStarted>(_onStarted);
    on<InventoryStockUpdated>(_onStockUpdated);
    on<InventorySearchRequested>(_onSearchRequested);
    on<InventoryProductAdded>(_onProductAdded);
    on<InventoryScanRequested>(_onScanRequested);
  }

  void _onStarted(InventoryStarted event, Emitter<InventoryState> emit) async {
    emit(InventoryLoading());
    await emit.forEach<List<Product>>(
      _repository.watchInventory(),
      onData: (products) => InventoryLoaded(products),
    );
  }

  void _onStockUpdated(InventoryStockUpdated event, Emitter<InventoryState> emit) {
    _repository.updateStock(event.productId, event.delta);
  }

  void _onSearchRequested(InventorySearchRequested event, Emitter<InventoryState> emit) {
    if (state is InventoryLoaded) {
      final s = state as InventoryLoaded;
      emit(InventoryLoaded(s.products, searchQuery: event.query));
    }
  }

  void _onProductAdded(InventoryProductAdded event, Emitter<InventoryState> emit) {
    _repository.addProduct(event.product);
  }

  void _onScanRequested(InventoryScanRequested event, Emitter<InventoryState> emit) async {
    final product = await _repository.findProductByUpc(event.upc);
    if (state is InventoryLoaded) {
      final s = state as InventoryLoaded;
      // Si el producto existe en el inventario local, filtramos
      if (s.products.any((p) => p.upc == event.upc)) {
        emit(InventoryLoaded(s.products, searchQuery: event.upc));
      } else {
        // Si no existe pero se encontró en la BD externa, enviamos para ALTA
        emit(InventoryLoaded(s.products, lastScanned: product));
      }
    }
  }
}
