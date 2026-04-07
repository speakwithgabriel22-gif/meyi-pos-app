import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/product.dart';
import '../../data/models/cart_item.dart';
import '../../data/services/pos_service.dart';

// --- Events ---
abstract class CartEvent extends Equatable {
  const CartEvent();
  @override List<Object?> get props => [];
}

class CartScanRequested extends CartEvent {
  final String upc;
  const CartScanRequested(this.upc);
  @override List<Object> get props => [upc];
}

class CartSearchRequested extends CartEvent {
  final String query;
  const CartSearchRequested(this.query);
  @override List<Object> get props => [query];
}

class CartSearchCleared extends CartEvent {}

class CartProductAdded extends CartEvent {
  final Product product;
  const CartProductAdded(this.product);
  @override List<Object> get props => [product];
}

class CartItemRemoved extends CartEvent {
  final String upc;
  const CartItemRemoved(this.upc);
  @override List<Object> get props => [upc];
}

class CartCleared extends CartEvent {}

// --- States ---
abstract class CartState extends Equatable {
  final List<CartItem> items;
  const CartState(this.items);

  double get total => items.fold(0, (sum, item) => sum + (item.product.price * item.quantity));

  @override List<Object> get props => [items];
}

class CartInitial extends CartState {
  const CartInitial() : super(const []);
}

class CartLoading extends CartState {
  const CartLoading(super.items);
}

class CartFound extends CartState {
  const CartFound(super.items);
}

class CartSearching extends CartState {
  final List<Product> results;
  const CartSearching(super.items, this.results);
  @override List<Object> get props => [items, results];
}

class CartMissingPrice extends CartState {
  final String upc;
  final String name;
  const CartMissingPrice(super.items, this.upc, this.name);
  @override List<Object> get props => [items, upc, name];
}

class CartNotFound extends CartState {
  final String upc;
  const CartNotFound(super.items, this.upc);
  @override List<Object> get props => [items, upc];
}

// --- BLoC ---
class CartBloc extends Bloc<CartEvent, CartState> {
  final PosService _posService;

  CartBloc(this._posService) : super(const CartInitial()) {
    on<CartSearchRequested>((event, emit) async {
       if (event.query.isEmpty) {
         emit(CartFound(state.items)); // Regresar al estado normal si se borra el texto
         return;
       }
       // Sr. UX: NO emitir Loading para que la interfaz no parpadee durante el tipeo
       final results = await _posService.searchProducts(event.query);
       emit(CartSearching(state.items, results));
    });

    on<CartSearchCleared>((event, emit) {
       emit(CartFound(state.items));
    });

    on<CartScanRequested>((event, emit) async {
      emit(CartLoading(state.items));
      final product = await _posService.getProductByUpc(event.upc);

      if (product == null) {
        emit(CartNotFound(state.items, event.upc));
      } else if (product.price == 0) {
        emit(CartMissingPrice(state.items, product.upc, product.name));
      } else {
        add(CartProductAdded(product));
      }
    });

    on<CartProductAdded>((event, emit) {
      final existingIndex = state.items.indexWhere((i) => i.product.upc == event.product.upc);
      List<CartItem> newItems;

      if (existingIndex >= 0) {
        newItems = List.from(state.items);
        final existingItem = newItems[existingIndex];
        newItems[existingIndex] = existingItem.copyWith(quantity: existingItem.quantity + 1);
      } else {
        newItems = [...state.items, CartItem(product: event.product)];
      }

      emit(CartFound(newItems));
    });

    on<CartItemRemoved>((event, emit) {
      final existingIndex = state.items.indexWhere((i) => i.product.upc == event.upc);
      if (existingIndex < 0) return;

      final List<CartItem> newItems = List.from(state.items);
      final existingItem = newItems[existingIndex];

      if (existingItem.quantity > 1) {
        newItems[existingIndex] = existingItem.copyWith(quantity: existingItem.quantity - 1);
      } else {
        newItems.removeAt(existingIndex);
      }

      emit(CartFound(newItems));
    });

    on<CartCleared>((event, emit) {
      emit(const CartInitial());
    });
  }
}
