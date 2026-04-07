import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../logic/blocs/inventory_bloc.dart';
import '../../widgets/professional_background.dart';
import '../../widgets/institutional_footer.dart';
import '../../data/models/product.dart';
import '../widgets/scanner_error_widget.dart'; // Sr. UX: Reutilización profesional

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(autoStart: false);
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      context.read<InventoryBloc>().add(InventorySearchRequested(_searchController.text));
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scannerController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InventoryBloc, InventoryState>(
      listenWhen: (prev, curr) => curr is InventoryLoaded && curr.lastScanned != null && (prev is! InventoryLoaded || prev.lastScanned != curr.lastScanned),
      listener: (context, state) {
        if (state is InventoryLoaded && state.lastScanned != null) {
          _showAddProductDialog(context, prefilled: state.lastScanned);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventario', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: ProfessionalBackground(
          child: Column(
            children: [
              // Buscador con Scanner (Sr. UX: Cero fricción)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Busca o escanea...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty) 
                          IconButton(icon: const Icon(Icons.close), onPressed: () => _searchController.clear()),
                        IconButton(
                          icon: Icon(Icons.qr_code_scanner_rounded, color: Theme.of(context).colorScheme.primary),
                          onPressed: () => _showScanner(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Expanded(
                child: BlocBuilder<InventoryBloc, InventoryState>(
                  builder: (context, state) {
                    if (state is InventoryLoading) return const Center(child: CircularProgressIndicator());
                    if (state is InventoryLoaded) {
                      final products = state.filteredProducts;
                      if (products.isEmpty) return const Center(child: Text('No se encontraron productos'));

                      return ListView.builder(
                        itemCount: products.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) => _InventoryItemCard(product: products[index]),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              const InstitutionalFooter(),
              const SizedBox(height: 16),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddProductDialog(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('NUEVO ARTÍCULO'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  void _showScanner(BuildContext context) {
    _scannerController.start();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('ESCANEAR PRODUCTO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
            Expanded(
              child: MobileScanner(
                controller: _scannerController,
                errorBuilder: (context, error) => ScannerErrorWidget(error: error, onRetry: () => _scannerController.start()),
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                    final String code = barcodes.first.rawValue!;
                    _audioPlayer.play(AssetSource('audio/beep.mp3'));
                    context.read<InventoryBloc>().add(InventoryScanRequested(code));
                    _scannerController.stop();
                    Navigator.pop(ctx);
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ).then((_) => _scannerController.stop());
  }

  void _showAddProductDialog(BuildContext context, {Product? prefilled}) {
    final nameCtrl = TextEditingController(text: prefilled?.name ?? '');
    final upcCtrl = TextEditingController(text: prefilled?.upc ?? '');
    final priceCtrl = TextEditingController(text: (prefilled != null && prefilled.price > 0) ? prefilled.price.toString() : '');
    final stockCtrl = TextEditingController(text: (prefilled != null && prefilled.stock > 0) ? prefilled.stock.toString() : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 32, left: 32, right: 32, top: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Nuevo Producto', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre del Producto')),
            const SizedBox(height: 16),
            TextField(controller: upcCtrl, decoration: const InputDecoration(labelText: 'Código UPC / Barras')),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio', prefixText: '\$ '))),
                const SizedBox(width: 16),
                Expanded(child: TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock Inicial'))),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                final product = Product(
                  upc: upcCtrl.text,
                  name: nameCtrl.text,
                  price: double.tryParse(priceCtrl.text) ?? 0,
                  stock: int.tryParse(stockCtrl.text) ?? 0,
                );
                context.read<InventoryBloc>().add(InventoryProductAdded(product));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto agregado con éxito')));
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(64)),
              child: const Text('GUARDAR PRODUCTO'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  final Product product;
  const _InventoryItemCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final bool lowStock = product.stock < 10;
    final bool criticalStock = product.stock < 3;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Info Producto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('UPC: ${product.upc}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 13)),
                  if (lowStock)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: criticalStock ? Theme.of(context).colorScheme.error.withOpacity(0.12) : Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        criticalStock ? '⚠️ STOCK CRÍTICO' : '📦 STOCK BAJO',
                        style: TextStyle(
                          color: criticalStock ? Theme.of(context).colorScheme.error : Colors.amber.shade800,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Stepper Directo (Sr. UX: Cero navegación para editar)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.primary),
                    onPressed: () => context.read<InventoryBloc>().add(InventoryStockUpdated(product.upc, -1)),
                  ),
                  Text('${product.stock}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                    onPressed: () => context.read<InventoryBloc>().add(InventoryStockUpdated(product.upc, 1)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
