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
  final double delta;
  const InventoryStockUpdated(this.productId, this.delta);
}
class InventorySearchRequested extends InventoryEvent {
  final String query;
  final bool? showNegativeStock;
  final String? typeFilter;
  const InventorySearchRequested(this.query, {this.showNegativeStock, this.typeFilter});
}

class InventoryProductAdded extends InventoryEvent {
  final Product product;
  const InventoryProductAdded(this.product);
}

class InventoryProductRemoved extends InventoryEvent {
  final String upc;
  const InventoryProductRemoved(this.upc);
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
  final bool showNegativeStock;
  final String? typeFilter;
  final Product? lastScanned; // Para abrir el diálogo de alta si es nuevo

  const InventoryLoaded(
    this.products, {
    this.searchQuery = '',
    this.showNegativeStock = false,
    this.typeFilter,
    this.lastScanned,
  });

  List<Product> get filteredProducts {
    var raw = products;
    if (showNegativeStock) {
      raw = raw.where((p) => p.stock < 0 && p.productType != 'SERVICE').toList();
    }
    if (typeFilter != null && typeFilter!.isNotEmpty && typeFilter != 'ALL') {
      raw = raw.where((p) => p.productType == typeFilter).toList();
    }
    if (searchQuery.isNotEmpty) {
      raw = raw
          .where((p) =>
              p.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
              p.upc.contains(searchQuery))
          .toList();
    }
    return raw;
  }

  int get negativeStockCount => products.where((p) => p.stock < 0 && p.productType != 'SERVICE').length;

  @override
  List<Object?> get props => [products, searchQuery, showNegativeStock, typeFilter, lastScanned];
}

// BLoC
class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final BusinessRepository _repository;

  InventoryBloc(this._repository) : super(InventoryInitial()) {
    on<InventoryStarted>(_onStarted);
    on<InventoryStockUpdated>(_onStockUpdated);
    on<InventorySearchRequested>(_onSearchRequested);
    on<InventoryProductAdded>(_onProductAdded);
    on<InventoryProductRemoved>(_onProductRemoved);
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
      emit(InventoryLoaded(
        s.products,
        searchQuery: event.query,
        showNegativeStock: event.showNegativeStock ?? s.showNegativeStock,
        typeFilter: event.typeFilter ?? s.typeFilter, // Update or keep current
      ));
    }
  }

  void _onProductAdded(InventoryProductAdded event, Emitter<InventoryState> emit) {
    _repository.addProduct(event.product);
  }

  void _onProductRemoved(InventoryProductRemoved event, Emitter<InventoryState> emit) {
    (_repository as dynamic).removeProduct(event.upc);
  }

  void _onScanRequested(InventoryScanRequested event, Emitter<InventoryState> emit) async {
    final product = await _repository.findProductByUpc(event.upc);
    if (state is InventoryLoaded) {
      final s = state as InventoryLoaded;
      
      // 🟢 NIVEL 1: Ya existe en tu inventario local
      final matches = s.products.where((p) => p.upc == event.upc).toList();
      if (matches.isNotEmpty) {
        emit(InventoryLoaded(
          s.products,
          searchQuery: event.upc,
          lastScanned: matches.first,
        ));
      } else if (product != null) {
        // 🟡 NIVEL 2: Encontrado en el Catálogo Maestro
        emit(InventoryLoaded(s.products, lastScanned: product));
      } else {
        // 🔴 NIVEL 3: Producto totalmente nuevo (Misceláneos)
        // Enviamos un skeleton para que la UI abra el formulario con el UPC ya listo
        emit(InventoryLoaded(s.products, lastScanned: Product(
          id: 'new-manual',
          tenantId: 'comedor-1', // Fallback, pero se usa Constants en el repository
          upc: event.upc,
          name: '',
          price: 0,
        )));
      }
    }
  }
}
