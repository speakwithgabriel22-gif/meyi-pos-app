import '../models/product.dart';
import '../repositories/business_repository.dart';

class PosService {
  final BusinessRepository _repository;

  PosService(this._repository);

  /// Obtiene un producto por su código UPC de forma jerárquica
  Future<Product?> getProductByUpc(String upc) {
    return _repository.findProductByUpc(upc);
  }

  /// Agrega un nuevo producto a la base de datos local
  Future<void> addProduct(Product product) {
    return _repository.addProduct(product);
  }

  /// Busca productos por coincidencia parcial (Live Search)
  Future<List<Product>> searchProducts(String query) {
    return _repository.searchProducts(query);
  }
}
