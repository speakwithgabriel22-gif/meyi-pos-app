import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────
//  MODELOS DEMO
// ─────────────────────────────────────────────
class Product {
  final String id;
  final String name;
  final String barcode;
  final double price;
  final String category;
  final int stock;

  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.category,
    required this.stock,
  });
}

class CartItem {
  final Product product;
  int qty;
  CartItem({required this.product, this.qty = 1});
  double get subtotal => product.price * qty;
}

// ─────────────────────────────────────────────
//  DATOS DEMO
// ─────────────────────────────────────────────
final _demoProducts = <Product>[
  Product(
      id: '1',
      name: 'Coca-Cola 600ml',
      barcode: '7501055300586',
      price: 18.00,
      category: 'Bebidas',
      stock: 48),
  Product(
      id: '2',
      name: 'Sabritas Original',
      barcode: '7501030470492',
      price: 22.50,
      category: 'Botanas',
      stock: 30),
  Product(
      id: '3',
      name: 'Pan Bimbo Blanco',
      barcode: '7441029502103',
      price: 45.00,
      category: 'Panadería',
      stock: 12),
  Product(
      id: '4',
      name: 'Leche Lala 1L',
      barcode: '7501012600014',
      price: 28.00,
      category: 'Lácteos',
      stock: 20),
  Product(
      id: '5',
      name: 'Huevo Bachoco 12pz',
      barcode: '7503000011013',
      price: 55.00,
      category: 'Lácteos',
      stock: 8),
  Product(
      id: '6',
      name: 'Agua Bonafont 1.5L',
      barcode: '7501055363000',
      price: 14.00,
      category: 'Bebidas',
      stock: 60),
  Product(
      id: '7',
      name: 'Jabón Dove 90g',
      barcode: '7506306290017',
      price: 32.00,
      category: 'Higiene',
      stock: 25),
  Product(
      id: '8',
      name: 'Detergente Ariel 1kg',
      barcode: '7500435066648',
      price: 78.00,
      category: 'Limpieza',
      stock: 15),
];

// ─────────────────────────────────────────────
//  PANTALLA PRINCIPAL
// ─────────────────────────────────────────────
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with TickerProviderStateMixin {
  // --- Scanner HID state ---
  final _scanBuffer = StringBuffer();
  Timer? _scanTimer;
  DateTime? _lastKeyTime;
  bool _scannerDetected = false;
  String _lastScanned = '';

  // --- Search ---
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  List<Product> _filtered = _demoProducts;

  // --- Cart ---
  final List<CartItem> _cart = [];

  // --- Payment ---
  String _paymentMethod = 'Efectivo';
  double _cashReceived = 0;

  // --- Animation ---
  late AnimationController _pulseCtrl;
  late AnimationController _scannerBadgeCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _scannerBadgeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _scanTimer?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _pulseCtrl.dispose();
    _scannerBadgeCtrl.dispose();
    super.dispose();
  }

  // ── Scanner HID detection ──────────────────
  // Los scanners envían todos los caracteres muy rápido (<30ms entre teclas)
  // y terminan con Enter. Detectamos ese patrón.
  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (_searchFocus.hasFocus)
      return false; // No interceptar si el user escribe

    final now = DateTime.now();
    final char = event.character;

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final code = _scanBuffer.toString().trim();
      _scanBuffer.clear();
      if (code.length >= 6) {
        _onBarcodeScanned(code);
      }
      return true;
    }

    if (char != null && char.isNotEmpty) {
      // Detectar velocidad: scanner < 30ms, humano > 80ms
      if (_lastKeyTime != null) {
        final delta = now.difference(_lastKeyTime!).inMilliseconds;
        if (delta < 50) {
          _scanBuffer.write(char);
          setState(() => _scannerDetected = true);
        } else if (delta > 200) {
          _scanBuffer.clear();
          _scanBuffer.write(char);
        } else {
          _scanBuffer.write(char);
        }
      } else {
        _scanBuffer.write(char);
      }
      _lastKeyTime = now;

      _scanTimer?.cancel();
      _scanTimer = Timer(const Duration(milliseconds: 300), () {
        _scanBuffer.clear();
      });
    }

    return false;
  }

  void _onBarcodeScanned(String barcode) {
    setState(() => _lastScanned = barcode);
    _scannerBadgeCtrl.forward(from: 0);

    final product = _demoProducts.firstWhere(
      (p) => p.barcode == barcode,
      orElse: () => Product(
        id: '?',
        name: 'Producto no encontrado',
        barcode: barcode,
        price: 0,
        category: '',
        stock: 0,
      ),
    );

    if (product.id == '?') {
      _showNotFound(barcode);
    } else {
      _addToCart(product);
      HapticFeedback.lightImpact();
    }
  }

  // ── Cart logic ─────────────────────────────
  void _addToCart(Product p) {
    setState(() {
      final idx = _cart.indexWhere((c) => c.product.id == p.id);
      if (idx >= 0) {
        _cart[idx].qty++;
      } else {
        _cart.add(CartItem(product: p));
      }
    });
  }

  void _removeFromCart(int idx) => setState(() => _cart.removeAt(idx));

  void _updateQty(int idx, int delta) {
    setState(() {
      _cart[idx].qty += delta;
      if (_cart[idx].qty <= 0) _cart.removeAt(idx);
    });
  }

  double get _total => _cart.fold(0, (s, c) => s + c.subtotal);
  double get _change => (_cashReceived - _total).clamp(0, double.infinity);

  // ── Search ─────────────────────────────────
  void _onSearch(String q) {
    final lq = q.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _demoProducts
          : _demoProducts
              .where((p) =>
                  p.name.toLowerCase().contains(lq) ||
                  p.barcode.contains(lq) ||
                  p.category.toLowerCase().contains(lq))
              .toList();
    });
  }

  void _showNotFound(String barcode) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Código $barcode no encontrado en catálogo'),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F3F8),
      appBar: _buildAppBar(cs, isDark),
      body: Row(
        children: [
          // ── Columna izquierda: Catálogo ──
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _SearchBar(
                    ctrl: _searchCtrl,
                    focus: _searchFocus,
                    onChanged: _onSearch),
                Expanded(
                    child: _ProductGrid(
                  products: _filtered,
                  onTap: _addToCart,
                )),
              ],
            ),
          ),

          // ── Divider ──
          Container(width: 1, color: cs.outlineVariant.withOpacity(0.3)),

          // ── Columna derecha: Ticket / Cobro ──
          SizedBox(
            width: 380,
            child: _CartPanel(
              cart: _cart,
              total: _total,
              change: _change,
              paymentMethod: _paymentMethod,
              cashReceived: _cashReceived,
              onRemove: _removeFromCart,
              onQtyChange: _updateQty,
              onPaymentMethodChanged: (m) => setState(() => _paymentMethod = m),
              onCashChanged: (v) => setState(() => _cashReceived = v),
              onCharge: _cart.isEmpty ? null : () => _showChargeDialog(),
            ),
          ),
        ],
      ),

      // ── Badge escáner ──
      bottomNavigationBar: _ScannerStatusBar(
        detected: _scannerDetected,
        lastScanned: _lastScanned,
        pulseCtrl: _pulseCtrl,
        badgeCtrl: _scannerBadgeCtrl,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme cs, bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF16161E) : Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 24,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(Icons.point_of_sale_rounded, color: cs.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Punto de Venta',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface)),
              Text('Turno abierto · Cajero: Admin',
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurface.withOpacity(0.4))),
            ],
          ),
        ],
      ),
      actions: [
        _AppBarChip(
            icon: Icons.inventory_2_outlined,
            label: '${_demoProducts.length} productos'),
        const SizedBox(width: 8),
        _AppBarChip(
          icon: Icons.shopping_cart_checkout_rounded,
          label: '${_cart.length} en ticket',
          active: _cart.isNotEmpty,
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  void _showChargeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _ChargeDialog(
        total: _total,
        paymentMethod: _paymentMethod,
        cashReceived: _cashReceived,
        change: _change,
        onConfirm: () {
          setState(() => _cart.clear());
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text('¡Venta registrada exitosamente!'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  APP BAR CHIP
// ─────────────────────────────────────────────
class _AppBarChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const _AppBarChip(
      {required this.icon, required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? cs.primary.withOpacity(0.1)
            : cs.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 15,
              color: active ? cs.primary : cs.onSurface.withOpacity(0.5)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: active ? cs.primary : cs.onSurface.withOpacity(0.5),
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SEARCH BAR
// ─────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  const _SearchBar(
      {required this.ctrl, required this.focus, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: TextField(
        controller: ctrl,
        focusNode: focus,
        onChanged: onChanged,
        style: TextStyle(fontSize: 15, color: cs.onSurface),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, código de barras o categoría…',
          hintStyle:
              TextStyle(color: cs.onSurface.withOpacity(0.35), fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: cs.primary),
          suffixIcon: ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    ctrl.clear();
                    onChanged('');
                  },
                )
              : Icon(Icons.qr_code_scanner_rounded,
                  color: cs.onSurface.withOpacity(0.3), size: 20),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: cs.primary, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PRODUCT GRID
// ─────────────────────────────────────────────
class _ProductGrid extends StatelessWidget {
  final List<Product> products;
  final ValueChanged<Product> onTap;
  const _ProductGrid({required this.products, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 64,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.15)),
            const SizedBox(height: 12),
            Text('Sin resultados',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.3),
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 148,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (ctx, i) => _ProductCard(product: products[i], onTap: onTap),
    );
  }
}

// ─────────────────────────────────────────────
//  PRODUCT CARD
// ─────────────────────────────────────────────
class _ProductCard extends StatefulWidget {
  final Product product;
  final ValueChanged<Product> onTap;
  const _ProductCard({required this.product, required this.onTap});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.94)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() async {
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap(widget.product);
  }

  Color _categoryColor(String cat) {
    final map = {
      'Bebidas': Colors.blue,
      'Botanas': Colors.orange,
      'Panadería': Colors.brown,
      'Lácteos': Colors.teal,
      'Higiene': Colors.pink,
      'Limpieza': Colors.purple,
    };
    return map[cat] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catColor = _categoryColor(widget.product.category);
    final lowStock = widget.product.stock <= 10;

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A24) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.15)),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(widget.product.category,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: catColor,
                              )),
                        ),
                        const Spacer(),
                        if (lowStock)
                          Icon(Icons.warning_amber_rounded,
                              size: 14, color: Colors.orange.shade400),
                      ],
                    ),
                    const Spacer(),
                    Text(widget.product.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('\$${widget.product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: cs.primary,
                            )),
                        Text('${widget.product.stock} pzas',
                            style: TextStyle(
                              fontSize: 11,
                              color: lowStock
                                  ? Colors.orange
                                  : cs.onSurface.withOpacity(0.4),
                              fontWeight: lowStock
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            )),
                      ],
                    ),
                  ],
                ),
              ),

              // Tap ripple overlay
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _onTap,
                    splashColor: cs.primary.withOpacity(0.08),
                    highlightColor: cs.primary.withOpacity(0.04),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CART PANEL
// ─────────────────────────────────────────────
class _CartPanel extends StatelessWidget {
  final List<CartItem> cart;
  final double total;
  final double change;
  final String paymentMethod;
  final double cashReceived;
  final void Function(int) onRemove;
  final void Function(int, int) onQtyChange;
  final ValueChanged<String> onPaymentMethodChanged;
  final ValueChanged<double> onCashChanged;
  final VoidCallback? onCharge;

  const _CartPanel({
    required this.cart,
    required this.total,
    required this.change,
    required this.paymentMethod,
    required this.cashReceived,
    required this.onRemove,
    required this.onQtyChange,
    required this.onPaymentMethodChanged,
    required this.onCashChanged,
    required this.onCharge,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF13131A) : const Color(0xFFFAF9FF),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('TICKET',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                      letterSpacing: 1.5,
                    )),
                const Spacer(),
                if (cart.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => onRemove(-1), // señal de limpiar todo
                    icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                    label: const Text('Limpiar'),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.error,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
              ],
            ),
          ),

          // Items
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 56, color: cs.onSurface.withOpacity(0.1)),
                        const SizedBox(height: 12),
                        Text('Ticket vacío',
                            style: TextStyle(
                                color: cs.onSurface.withOpacity(0.3))),
                        const SizedBox(height: 4),
                        Text('Escanea o toca un producto',
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withOpacity(0.2))),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: cart.length,
                    itemBuilder: (ctx, i) => _CartItemTile(
                      item: cart[i],
                      onRemove: () => onRemove(i),
                      onQtyChange: (d) => onQtyChange(i, d),
                    ),
                  ),
          ),

          // Pago y total
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A24) : Colors.white,
              border: Border(
                  top: BorderSide(color: cs.outlineVariant.withOpacity(0.2))),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Método de pago
                Row(
                  children: [
                    _PayMethodChip(
                      label: 'Efectivo',
                      icon: Icons.payments_rounded,
                      selected: paymentMethod == 'CASH',
                      onTap: () => onPaymentMethodChanged('CASH'),
                    ),
                    const SizedBox(width: 8),
                    _PayMethodChip(
                      label: 'Tarjeta',
                      icon: Icons.credit_card_rounded,
                      selected: paymentMethod == 'CARD',
                      onTap: () => onPaymentMethodChanged('CARD'),
                    ),
                    const SizedBox(width: 8),
                    _PayMethodChip(
                      label: 'Transf.',
                      icon: Icons.swap_horiz_rounded,
                      selected: paymentMethod == 'TRANSFER',
                      onTap: () => onPaymentMethodChanged('TRANSFER'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Efectivo recibido (solo si es efectivo)
                if (paymentMethod == 'Efectivo') ...[
                  _CashInput(
                    total: total,
                    value: cashReceived,
                    onChanged: onCashChanged,
                  ),
                  const SizedBox(height: 12),
                  if (cashReceived > 0)
                    _SummaryRow(
                      label: 'Cambio',
                      value: '\$${change.toStringAsFixed(2)}',
                      color: change >= 0 ? Colors.green : cs.error,
                      bold: true,
                    ),
                  const SizedBox(height: 8),
                ],

                const Divider(height: 20),

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface.withOpacity(0.5),
                          letterSpacing: 1.2,
                        )),
                    Text('\$${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: cs.primary,
                        )),
                  ],
                ),
                const SizedBox(height: 16),

                // Botón cobrar
                ElevatedButton.icon(
                  onPressed: onCharge,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('COBRAR',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(60),
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    disabledBackgroundColor: cs.onSurface.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CART ITEM TILE
// ─────────────────────────────────────────────
class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQtyChange;
  const _CartItemTile(
      {required this.item, required this.onRemove, required this.onQtyChange});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // Qty controls
          _QtyButton(icon: Icons.remove_rounded, onTap: () => onQtyChange(-1)),
          Container(
            width: 32,
            alignment: Alignment.center,
            child: Text('${item.qty}',
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: cs.onSurface)),
          ),
          _QtyButton(icon: Icons.add_rounded, onTap: () => onQtyChange(1)),

          const SizedBox(width: 10),

          // Nombre
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('\$${item.product.price.toStringAsFixed(2)} c/u',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurface.withOpacity(0.45))),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Subtotal + delete
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${item.subtotal.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                      fontSize: 15)),
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close_rounded,
                    size: 14, color: cs.onSurface.withOpacity(0.3)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: cs.primary),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PAGO METHOD CHIP
// ─────────────────────────────────────────────
class _PayMethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _PayMethodChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? cs.primary : cs.onSurface.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 18,
                  color:
                      selected ? cs.onPrimary : cs.onSurface.withOpacity(0.5)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color:
                        selected ? cs.onPrimary : cs.onSurface.withOpacity(0.5),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CASH INPUT
// ─────────────────────────────────────────────
class _CashInput extends StatefulWidget {
  final double total;
  final double value;
  final ValueChanged<double> onChanged;
  const _CashInput(
      {required this.total, required this.value, required this.onChanged});

  @override
  State<_CashInput> createState() => _CashInputState();
}

class _CashInputState extends State<_CashInput> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.value > 0 ? widget.value.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final quickAmounts = [widget.total, 50.0, 100.0, 200.0, 500.0]
        .where((a) => a >= widget.total)
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface),
          decoration: InputDecoration(
            labelText: 'Efectivo recibido',
            prefixText: '\$ ',
            labelStyle: TextStyle(color: cs.onSurface.withOpacity(0.4)),
            filled: true,
            fillColor: cs.onSurface.withOpacity(0.04),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.primary, width: 2),
            ),
          ),
          onChanged: (v) => widget.onChanged(double.tryParse(v) ?? 0),
        ),
        const SizedBox(height: 8),
        Row(
          children: quickAmounts
              .map((a) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text('\$${a.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: cs.primary)),
                      onPressed: () {
                        _ctrl.text = a.toStringAsFixed(0);
                        widget.onChanged(a);
                      },
                      backgroundColor: cs.primary.withOpacity(0.08),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      side: BorderSide.none,
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  SUMMARY ROW
// ─────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _SummaryRow(
      {required this.label,
      required this.value,
      required this.color,
      this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
        Text(value,
            style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: color)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  SCANNER STATUS BAR
// ─────────────────────────────────────────────
class _ScannerStatusBar extends StatelessWidget {
  final bool detected;
  final String lastScanned;
  final AnimationController pulseCtrl;
  final AnimationController badgeCtrl;
  const _ScannerStatusBar({
    required this.detected,
    required this.lastScanned,
    required this.pulseCtrl,
    required this.badgeCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 44,
      color: isDark ? const Color(0xFF16161E) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Indicador escáner
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) => Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: detected
                    ? Color.lerp(
                        Colors.green, Colors.green.shade200, pulseCtrl.value)!
                    : cs.onSurface.withOpacity(0.2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            detected ? 'Escáner detectado' : 'Sin escáner (modo manual)',
            style: TextStyle(
              fontSize: 11,
              color: detected ? Colors.green : cs.onSurface.withOpacity(0.4),
              fontWeight: detected ? FontWeight.bold : FontWeight.normal,
            ),
          ),

          if (lastScanned.isNotEmpty) ...[
            const SizedBox(width: 16),
            FadeTransition(
              opacity:
                  CurvedAnimation(parent: badgeCtrl, curve: Curves.easeOut),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Último escaneo: $lastScanned',
                    style: TextStyle(
                        fontSize: 10,
                        color: cs.primary,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],

          const Spacer(),

          Icon(Icons.keyboard_outlined,
              size: 14, color: cs.onSurface.withOpacity(0.2)),
          const SizedBox(width: 4),
          Text('Escanea con el lector o usa el buscador',
              style: TextStyle(
                  fontSize: 11, color: cs.onSurface.withOpacity(0.25))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CHARGE DIALOG
// ─────────────────────────────────────────────
class _ChargeDialog extends StatelessWidget {
  final double total;
  final String paymentMethod;
  final double cashReceived;
  final double change;
  final VoidCallback onConfirm;
  const _ChargeDialog({
    required this.total,
    required this.paymentMethod,
    required this.cashReceived,
    required this.change,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.green, size: 40),
            ),
            const SizedBox(height: 20),
            Text('Confirmar Cobro',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface)),
            const SizedBox(height: 24),
            _DialogRow(
                label: 'Total',
                value: '\$${total.toStringAsFixed(2)}',
                large: true),
            _DialogRow(label: 'Método', value: paymentMethod),
            if (paymentMethod == 'Efectivo') ...[
              _DialogRow(
                  label: 'Recibido',
                  value: '\$${cashReceived.toStringAsFixed(2)}'),
              _DialogRow(
                  label: 'Cambio',
                  value: '\$${change.toStringAsFixed(2)}',
                  green: true),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('CANCELAR'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('CONFIRMAR',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogRow extends StatelessWidget {
  final String label;
  final String value;
  final bool large;
  final bool green;
  const _DialogRow(
      {required this.label,
      required this.value,
      this.large = false,
      this.green = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
          Text(value,
              style: TextStyle(
                fontWeight: large ? FontWeight.w900 : FontWeight.bold,
                fontSize: large ? 24 : 15,
                color:
                    green ? Colors.green : (large ? cs.primary : cs.onSurface),
              )),
        ],
      ),
    );
  }
}
