import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../logic/blocs/cart_bloc.dart';
import '../../data/models/product.dart';
import '../../widgets/professional_background.dart';
import '../widgets/scanner_error_widget.dart';

class VentaScreen extends StatefulWidget {
  const VentaScreen({super.key});

  @override
  State<VentaScreen> createState() => _VentaScreenState();
}

class _VentaScreenState extends State<VentaScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Para evitar ráfagas (debouncing)
  DateTime? _lastScan;
  bool _isHandlingDialog = false;

  @override
  void initState() {
    super.initState();
    _manualController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _manualController.removeListener(_onSearchChanged);
    _scannerController.dispose();
    _manualController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _manualController.text;
    context.read<CartBloc>().add(CartSearchRequested(query));
  }

  void _onScan(String code) {
    if (code.isEmpty || _isHandlingDialog) return;

    // Sr. UX: Debounce de 1.5s para evitar ráfagas accidentales (Solicitado por el usuario)
    final now = DateTime.now();
    if (_lastScan != null && now.difference(_lastScan!).inMilliseconds < 1500)
      return;
    _lastScan = now;

    Vibration.vibrate(duration: 50);
    SystemSound.play(SystemSoundType.click);
    _audioPlayer.play(AssetSource('audio/beep.mp3'));
    context.read<CartBloc>().add(CartScanRequested(code));
  }

  void _pauseScanner() {
    setState(() => _isHandlingDialog = true);
  }

  void _resumeScanner() {
    setState(() => _isHandlingDialog = false);
    _manualController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CartBloc, CartState>(
      listener: (context, state) {
        if (state is CartFound) {
          // Limpieza silenciosa
        } else if (state is CartMissingPrice) {
          _pauseScanner();
          _showMissingPriceSheet(context, state.upc, state.name);
        } else if (state is CartNotFound) {
          _pauseScanner();
          _showNotFoundSheet(context, state.upc);
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('Venta Rápida', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
              onPressed: () => context.read<CartBloc>().add(CartCleared()),
            ),
          ],
        ),
        body: ProfessionalBackground(
          child: Column(
            children: [
              BlocBuilder<CartBloc, CartState>(
                builder: (context, state) {
                  return Visibility(
                    visible: state is! CartSearching,
                    maintainState: true,
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.30,
                      margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                        ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          MobileScanner(
                            controller: _scannerController,
                            errorBuilder: (context, error) => ScannerErrorWidget(error: error, onRetry: () => _scannerController.start()),
                            onDetect: (capture) {
                              if (_isHandlingDialog || state is CartSearching) return;
                              final List<Barcode> barcodes = capture.barcodes;
                              for (final barcode in barcodes) {
                                if (barcode.rawValue != null) {
                                  _onScan(barcode.rawValue!);
                                  break;
                                }
                              }
                            },
                          ),
                          Center(
                            child: Container(
                              width: 250,
                              height: 100,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _manualController,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'Busca por nombre o código...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _manualController.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.close), onPressed: () => _manualController.clear())
                        : null,
                  ),
                  onSubmitted: (val) {
                    final state = context.read<CartBloc>().state;
                    if (state is CartSearching && state.results.isNotEmpty) {
                      context.read<CartBloc>().add(CartProductAdded(state.results.first));
                      _manualController.clear();
                    } else {
                      _onScan(val);
                    }
                  },
                ),
              ),

              Expanded(
                child: BlocBuilder<CartBloc, CartState>(
                  builder: (context, state) {
                    if (state is CartSearching) return _buildSearchResults(state.results);
                    return _buildCartList(state);
                  },
                ),
              ),

              BlocBuilder<CartBloc, CartState>(
                builder: (context, state) {
                  if (state.items.isEmpty || state is CartSearching) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                      border: Border(top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05))),
                    ),
                    child: SafeArea(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('TOTAL A PAGAR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                              Text('\$${state.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1B6CA8))),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () => context.push('/cobro'),
                            style: ElevatedButton.styleFrom(minimumSize: const Size(160, 60), backgroundColor: Colors.green.shade700),
                            child: const Text('COBRAR'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartList(CartState state) {
    if (state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/animations/waiting.json', height: 160),
            const SizedBox(height: 16),
            const Text('Escanea piezas para empezar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: state.items.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final item = state.items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.orangeAccent),
              onPressed: () {
                Vibration.vibrate(duration: 50);
                context.read<CartBloc>().add(CartItemRemoved(item.product.upc));
              },
            ),
            title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Cant: ${item.quantity} x \$${item.product.price}'),
            trailing: Text('\$${item.subtotal.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Theme.of(context).colorScheme.primary)),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(List<Product> results) {
    if (results.isEmpty) return const Center(child: Text('No hay coincidencias 🔍', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      itemCount: results.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final p = results[index];
        return ListTile(
          leading: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('UPC: ${p.upc}'),
          trailing: Text('\$${p.price}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          onTap: () {
            context.read<CartBloc>().add(CartProductAdded(p));
            _manualController.clear();
          },
        );
      },
    );
  }

  void _showMissingPriceSheet(BuildContext context, String upc, String name) {
    final ctrl = TextEditingController();
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
            Text('PRODUCTO SIN PRECIO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
            Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: '¿Cuál es el precio?', 
                prefixText: '\$ ',
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))
              ),
              onSubmitted: (_) {
                final p = double.tryParse(ctrl.text) ?? 0.0;
                if (p > 0) {
                  context.read<CartBloc>().add(CartProductAdded(Product(upc: upc, name: name, price: p)));
                  Navigator.pop(ctx);
                }
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final p = double.tryParse(ctrl.text) ?? 0.0;
                if (p > 0) {
                  context.read<CartBloc>().add(CartProductAdded(Product(upc: upc, name: name, price: p)));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('AGREGAR AL CARRITO'),
            ),
          ],
        ),
      ),
    ).then((_) => _resumeScanner());
  }

  void _showNotFoundSheet(BuildContext context, String upc) {
    final nCtrl = TextEditingController();
    final pCtrl = TextEditingController();
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
            const Text('PRODUCTO NO REGISTRADO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            TextField(controller: nCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Nombre del Artículo'), textInputAction: TextInputAction.next),
            const SizedBox(height: 16),
            TextField(
              controller: pCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Precio de Venta', prefixText: '\$ '),
              onSubmitted: (_) {
                final n = nCtrl.text.trim();
                final p = double.tryParse(pCtrl.text) ?? 0.0;
                if (n.isNotEmpty && p > 0) {
                  context.read<CartBloc>().add(CartProductAdded(Product(upc: upc, name: n, price: p)));
                  Navigator.pop(ctx);
                }
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final n = nCtrl.text.trim();
                final p = double.tryParse(pCtrl.text) ?? 0.0;
                if (n.isNotEmpty && p > 0) {
                  context.read<CartBloc>().add(CartProductAdded(Product(upc: upc, name: n, price: p)));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('REGISTRAR Y VENDER'),
            ),
          ],
        ),
      ),
    ).then((_) => _resumeScanner());
  }
}
