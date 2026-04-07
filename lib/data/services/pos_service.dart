import '../models/product.dart';
import '../models/login_response.dart';

class PosService {
  // Lista simulada de productos para el buscador "Live"
  final List<Product> _mockDatabase = [
    const Product(upc: '7501055300075', name: 'Sabritas Sal 45g', price: 18.5),
    const Product(upc: '7501031311309', name: 'Coca Cola 600ml', price: 17.0),
    const Product(upc: '7501000619054', name: 'Pepsi 500ml', price: 15.5),
    const Product(upc: '7501031311682', name: 'Fanta Naranja 600ml', price: 16.0),
    const Product(upc: '7501000111206', name: 'Gansito Marinela 50g', price: 21.0),
    const Product(upc: '7501021415124', name: 'Pan Bimbo Blanco', price: 45.0),
  ];

  Future<Product?> getProductByUpc(String upc) async {
    await Future.delayed(const Duration(milliseconds: 200));

    if (upc == '999') return null; // Escenario NO encontrado

    if (upc == '000') {
      return const Product(upc: '000', name: 'Producto Sin Precio', price: 0.0);
    }

    // Buscamos en nuestra base simulada
    try {
      return _mockDatabase.firstWhere((p) => p.upc == upc);
    } catch (_) {
      // Si no existe pero no es 999/000, regresamos un Sabritas genérico para fluidez
      return Product(upc: upc, name: 'Producto Genérico $upc', price: 10.0);
    }
  }

  Future<List<Product>> searchProducts(String query) async {
    await Future.delayed(const Duration(milliseconds: 100)); // Delay corto para "Live Search"
    if (query.isEmpty) return [];
    
    return _mockDatabase
        .where((p) => p.name.toLowerCase().contains(query.toLowerCase()) || p.upc.contains(query))
        .toList();
  }

  /// Login que retorna LoginResponse con flag isNew para onboarding.
  /// Para demo: PIN '1234' = usuario existente, PIN '0000' = usuario nuevo.
  Future<LoginResponse> login(String phone, String pin) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (pin == '1234') {
      return const LoginResponse(
        success: true,
        userName: 'Carlos',
        role: 'owner',
        isNew: false,
      );
    } else if (pin == '0000') {
      return const LoginResponse(
        success: true,
        userName: '',
        role: 'owner',
        isNew: true,
      );
    }
    
    return const LoginResponse(
      success: false,
      userName: '',
      role: '',
      isNew: false,
    );
  }
}

