import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:lottie/lottie.dart';
import '../../logic/blocs/inventory_bloc.dart';
import '../../widgets/professional_background.dart';
import '../../widgets/institutional_footer.dart';
import '../../data/models/product.dart';
import '../widgets/scanner_error_widget.dart';
import '../../utils/constants.dart';
import '../../utils/uuid_generator.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Controlador anulable para el enfoque "nuclear"
  MobileScannerController? _scannerController;

  bool _isScannerVisible = false;
  bool _isHandlingScan = false;

  // FIX: track if sheet is open to prevent double-open
  bool _isSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addObserver(this); // Registrar para cambios de estado de la app
    _searchController.addListener(() {
      context
          .read<InventoryBloc>()
          .add(InventorySearchRequested(_searchController.text));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _scannerController?.dispose(); // Destrucción segura
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Manejo del ciclo de vida de la App ──────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopAndDestroyScanner();
    } else if (state == AppLifecycleState.resumed && _isScannerVisible) {
      _startScanner();
    }
  }

  // ── Lógica robusta del escáner ──────────────────────────────────────────
  void _initController() {
    _scannerController?.dispose();
    _scannerController = MobileScannerController(autoStart: false);
  }

  Future<void> _startScanner() async {
    _initController();
    try {
      // Delay mágico para que Android libere la cámara
      await Future.delayed(const Duration(milliseconds: 150));
      await _scannerController?.start();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error al iniciar escáner: $e');
    }
  }

  Future<void> _stopAndDestroyScanner() async {
    await _scannerController?.stop();
    await _scannerController?.dispose();
    _scannerController = null;
    if (mounted) setState(() {});
  }

  Future<void> _toggleScanner() async {
    final nextVisible = !_isScannerVisible;
    setState(() {
      _isScannerVisible = nextVisible;
      if (!nextVisible) _isHandlingScan = false;
    });

    if (nextVisible) {
      await _startScanner();
    } else {
      await _stopAndDestroyScanner();
    }
  }

  Future<void> _collapseScanner() async {
    if (!_isScannerVisible) return;
    setState(() => _isScannerVisible = false);
    await _stopAndDestroyScanner();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocListener<InventoryBloc, InventoryState>(
      listenWhen: (prev, curr) =>
          curr is InventoryLoaded &&
          curr.lastScanned != null &&
          (prev is! InventoryLoaded || prev.lastScanned != curr.lastScanned),
      listener: (context, state) {
        // FIX: guard against opening sheet while already open
        if (state is InventoryLoaded &&
            state.lastScanned != null &&
            !_isSheetOpen) {
          _showAddProductSheet(context, prefilled: state.lastScanned);
        }
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 1,
          toolbarHeight: 70,
          centerTitle: false,
          titleSpacing: 16,
          backgroundColor: cs.surface,

          /// 🎨 Fondo con profundidad sutil
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.surface,
                  cs.surface.withOpacity(0.96),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          /// 🧠 HEADER
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Inventario',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              BlocBuilder<InventoryBloc, InventoryState>(
                builder: (context, state) {
                  if (state is InventoryLoaded) {
                    final count = state.products.length;

                    return Row(
                      children: [
                        /// 📦 Indicador visual
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),

                        Text(
                          '$count producto${count == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface.withOpacity(0.55),
                          ),
                        ),
                      ],
                    );
                  }

                  /// Skeleton elegante
                  return Container(
                    width: 80,
                    height: 10,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                },
              ),
            ],
          ),

          /// ⚙️ ACCIONES
          actions: [
            /// ➕ Agregar producto
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Nuevo producto',
              onPressed: () {
                _showAddProductSheet(context, prefilled: null);
              },
            ),

            /// 📷 Scanner mejor integrado
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _ScannerToggleButton(
                isActive: _isScannerVisible,
                onTap: _toggleScanner,
              ),
            ),
          ],
        ),
        body: ProfessionalBackground(
          child: Column(
            children: [
              // ── Alerta Stock Negativo ──────────────────────────────────
              BlocBuilder<InventoryBloc, InventoryState>(
                builder: (context, state) {
                  if (state is InventoryLoaded &&
                      state.negativeStockCount > 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: InkWell(
                        onTap: () {
                          context.read<InventoryBloc>().add(
                              InventorySearchRequested(state.searchQuery,
                                  showNegativeStock: !state.showNegativeStock));
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: state.showNegativeStock
                                ? Colors.red.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: state.showNegativeStock
                                    ? Colors.red.shade200
                                    : Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: state.showNegativeStock
                                      ? Colors.red.shade700
                                      : Colors.orange.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${state.negativeStockCount} producto(s) en negativo.',
                                  style: TextStyle(
                                    color: state.showNegativeStock
                                        ? Colors.red.shade900
                                        : Colors.orange.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  state.showNegativeStock
                                      ? 'Quitar Filtro'
                                      : 'Filtrar',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                                backgroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              const SizedBox(height: 12),

              // ── Selector de Filtros de Tipo ────────────────────────────
              BlocBuilder<InventoryBloc, InventoryState>(
                buildWhen: (prev, curr) {
                  if (prev is! InventoryLoaded || curr is! InventoryLoaded)
                    return true;
                  return prev.typeFilter != curr.typeFilter;
                },
                builder: (context, state) {
                  if (state is! InventoryLoaded) return const SizedBox.shrink();
                  final currentFilter = state.typeFilter ?? 'ALL';
                  final cs = Theme.of(context).colorScheme;

                  Widget filterChip(String id, String label, IconData icon) {
                    final isSelected = currentFilter == id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        showCheckmark: false,
                        label: Text(label),
                        avatar: Icon(icon,
                            size: 14,
                            color: isSelected ? cs.onPrimary : cs.primary),
                        selected: isSelected,
                        onSelected: (_) {
                          context.read<InventoryBloc>().add(
                              InventorySearchRequested(state.searchQuery,
                                  typeFilter: id == 'ALL' ? '' : id,
                                  showNegativeStock: state.showNegativeStock));
                        },
                        selectedColor: cs.primary,
                        backgroundColor: cs.surface,
                        labelStyle: TextStyle(
                          color: isSelected ? cs.onPrimary : cs.onSurface,
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        filterChip('ALL', 'Todos', Icons.dashboard_rounded),
                        filterChip(
                            'STANDARD', 'Estándar', Icons.qr_code_2_rounded),
                        filterChip('WEIGHED', 'A Granel', Icons.scale_rounded),
                        filterChip('SERVICE', 'Servicios',
                            Icons.miscellaneous_services_rounded),
                        filterChip(
                            'PREPARED', 'Preparados', Icons.restaurant_rounded),
                        filterChip(
                            'INTERNAL', 'Internos', Icons.inventory_2_rounded),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 6),

              // ── Scanner panel ──────────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 340),
                curve: Curves.easeOutCubic,
                height: _isScannerVisible ? 230 : 0,
                child: AnimatedOpacity(
                  opacity: _isScannerVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(28),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_isScannerVisible && _scannerController != null)
                          MobileScanner(
                            controller: _scannerController!,
                            placeholderBuilder: (context) => Container(
                              // <-- CORREGIDO
                              color: Colors.black,
                              child: const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white),
                              ),
                            ),
                            errorBuilder: (context, error) =>
                                ScannerErrorWidget(
                              error: error,
                              onRetry: _startScanner,
                            ),
                            onDetect: (capture) {
                              if (_isHandlingScan) return;
                              final barcodes = capture.barcodes;
                              if (barcodes.isEmpty ||
                                  barcodes.first.rawValue == null) return;

                              final code = barcodes.first.rawValue!;
                              setState(() => _isHandlingScan = true);
                              _collapseScanner();
                              _audioPlayer.play(AssetSource('audio/beep.mp3'));
                              context
                                  .read<InventoryBloc>()
                                  .add(InventoryScanRequested(code));
                            },
                          ),
                        // Dark vignette overlay
                        if (_isScannerVisible)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.35),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.35),
                                ],
                              ),
                            ),
                          ),
                        // Scan reticle
                        if (_isScannerVisible)
                          Center(
                            child: _ScanReticle(),
                          ),
                        // Label
                        if (_isScannerVisible)
                          Positioned(
                            bottom: 20,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Apunta al codigo de barras',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Close button
                        Positioned(
                          top: 12,
                          right: 12,
                          child: GestureDetector(
                            onTap: _toggleScanner,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Search bar ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _SearchBar(controller: _searchController),
              ),

              const SizedBox(height: 12),

              // ── List ───────────────────────────────────────────────────
              Expanded(
                child: BlocBuilder<InventoryBloc, InventoryState>(
                  builder: (context, state) {
                    if (state is InventoryLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state is InventoryLoaded) {
                      final products = state.filteredProducts;

                      if (products.isEmpty) {
                        return _EmptyState(
                          isSearch: state.searchQuery.isNotEmpty,
                        );
                      }

                      return ListView.builder(
                        itemCount: products.length,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          // FIX: highlight by lastScanned UPC, not by searchQuery
                          final isLastScanned =
                              state.lastScanned?.upc == product.upc &&
                                  state.searchQuery.isEmpty;
                          return _InventoryItemCard(
                            product: product,
                            highlight: isLastScanned,
                            onEdit: () => _showAddProductSheet(
                              context,
                              prefilled: product,
                            ),
                          );
                        },
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),

              // const InstitutionalFooter(),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddProductSheet(BuildContext context, {Product? prefilled}) {
    // FIX: prevent double-open
    if (_isSheetOpen) return;

    final isFromMaster = prefilled != null &&
        prefilled.id != null &&
        prefilled.id!.startsWith('new-') &&
        prefilled.id != 'new-manual';
    final isManualWithUpc = prefilled?.id == 'new-manual';
    final isEditingLocal =
        prefilled != null && !isFromMaster && !isManualWithUpc;

    final nameCtrl = TextEditingController(text: prefilled?.name ?? '');
    // FIX: manual UPC entry — should be editable; was inverted before
    final upcCtrl = TextEditingController(text: prefilled?.upc ?? '');
    final priceCtrl = TextEditingController(
      text: prefilled != null && prefilled.price > 0
          ? prefilled.price.toStringAsFixed(2)
          : '',
    );
    // FIX: show '0' instead of '' when stock is zero
    final stockCtrl = TextEditingController(
      text: prefilled != null ? prefilled.stock.toStringAsFixed(0) : '',
    );

    String sheetTitle() {
      if (isFromMaster) return 'Catálogo Nacional';
      if (isEditingLocal) return 'Editar Producto';
      if (isManualWithUpc) return 'Nuevo Producto';
      return 'Nuevo Artículo';
    }

    String sheetSubtitle() {
      if (isFromMaster) {
        return 'Encontrado en la base maestra. Personaliza el nombre y asigna precio y stock.';
      }
      if (isEditingLocal) {
        return 'Actualiza nombre, precio o stock de este producto.';
      }
      if (isManualWithUpc) {
        return 'Código no reconocido. Completa los datos para darlo de alta.';
      }
      return 'Ingresa los datos para registrar un producto nuevo en tu catálogo.';
    }

    setState(() => _isSheetOpen = true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String selectedType = prefilled?.productType ?? 'STANDARD';
        String selectedUnit = prefilled?.measurementUnit ?? 'PZA';

        void onTypeSelected(String type, StateSetter setModalState) {
          setModalState(() {
            selectedType = type;
            if (type == 'SERVICE')
              selectedUnit = 'SRV';
            else if (type == 'WEIGHED')
              selectedUnit = 'KG';
            else if (type == 'PREPARED')
              selectedUnit = 'PZA';
            else if (type == 'STANDARD' && selectedUnit == 'SRV')
              selectedUnit = 'PZA';

            if (!isEditingLocal && !isFromMaster) {
              if (type == 'STANDARD') {
                upcCtrl.text = ''; // Esperar escaneo/tecleo manual
              } else if (type == 'INTERNAL') {
                upcCtrl.text =
                    'INT-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
              } else if (type == 'SERVICE') {
                upcCtrl.text =
                    'SRV-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
                stockCtrl.text = '0'; // Servicios no requieren stock
              } else if (type == 'WEIGHED') {
                upcCtrl.text =
                    'GRN-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
              } else if (type == 'PREPARED') {
                upcCtrl.text =
                    'PRP-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
              }
            }
          });
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            final cs = Theme.of(context).colorScheme;
            return Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
                left: 24,
                right: 24,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sheetTitle(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sheetSubtitle(),
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.55),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isFromMaster) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.verified_rounded,
                                  size: 14, color: cs.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Maestra',
                                style: TextStyle(
                                  color: cs.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Master product info card
                  if (isFromMaster && prefilled != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: cs.primary.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.inventory_2_rounded,
                                color: cs.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prefilled.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'UPC: ${prefilled.upc}',
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Selector de Tipo de Producto
                  if (!isFromMaster) ...[
                    const Text(
                      'Tipo de Artículo',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _TypeChip(
                              'STANDARD',
                              'Estándar',
                              Icons.qr_code,
                              selectedType,
                              (t) => onTypeSelected(t, setModalState),
                              cs),
                          _TypeChip(
                              'WEIGHED',
                              'A Granel',
                              Icons.scale_rounded,
                              selectedType,
                              (t) => onTypeSelected(t, setModalState),
                              cs),
                          _TypeChip(
                              'PREPARED',
                              'Preparado',
                              Icons.restaurant_rounded,
                              selectedType,
                              (t) => onTypeSelected(t, setModalState),
                              cs),
                          _TypeChip(
                              'INTERNAL',
                              'Interno',
                              Icons.inventory_2_rounded,
                              selectedType,
                              (t) => onTypeSelected(t, setModalState),
                              cs),
                          _TypeChip(
                              'SERVICE',
                              'Servicio',
                              Icons.miscellaneous_services_rounded,
                              selectedType,
                              (t) => onTypeSelected(t, setModalState),
                              cs),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Dropdown de Unidades (Sólo visible si no es maestra y no es servicio)
                  if (!isFromMaster && selectedType != 'SERVICE') ...[
                    const Text(
                      'Unidad de medida',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final unit in ['PZA', 'KG', 'LTS', 'MTRS', 'PAQ'])
                          ChoiceChip(
                            label: Text(unit),
                            selected: selectedUnit == unit,
                            onSelected: (val) {
                              if (val) setModalState(() => selectedUnit = unit);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Fields
                  TextField(
                    controller: nameCtrl,
                    autofocus:
                        isFromMaster || isManualWithUpc || prefilled == null,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: isFromMaster
                          ? 'Nombre en tu tienda'
                          : 'Nombre del producto',
                      prefixIcon: const Icon(Icons.label_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: upcCtrl,
                    enabled: !isFromMaster &&
                        !isEditingLocal &&
                        selectedType == 'STANDARD',
                    decoration: InputDecoration(
                      labelText: selectedType != 'STANDARD'
                          ? 'Código Autogenerado'
                          : 'Código UPC / Barras',
                      prefixIcon: const Icon(Icons.qr_code_rounded),
                      filled: selectedType != 'STANDARD',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Precio venta',
                            prefixText: '\$ ',
                            prefixIcon: Icon(Icons.sell_outlined),
                          ),
                        ),
                      ),
                      if (selectedType != 'SERVICE') ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Stock inicial',
                              prefixIcon: Icon(Icons.inventory_outlined),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Save button
                  FilledButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final upc = upcCtrl.text.trim();
                      final price = double.tryParse(priceCtrl.text);

                      if (name.isEmpty || upc.isEmpty || price == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Completa nombre, UPC y precio'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      final product = Product(
                        id: isEditingLocal
                            ? prefilled!.id
                            : UuidGenerator.generate(),
                        tenantId: Constants.tenantId ?? 'offline-tenant',
                        upc: upc,
                        name: name,
                        price: price,
                        productType: selectedType,
                        measurementUnit:
                            selectedType == 'SERVICE' ? 'SRV' : selectedUnit,
                        stock: selectedType == 'SERVICE'
                            ? 0.0
                            : (double.tryParse(stockCtrl.text) ?? 0.0),
                        createdAt: isEditingLocal
                            ? prefilled!.createdAt
                            : DateTime.now().toIso8601String(),
                        updatedAt: DateTime.now().toIso8601String(),
                      );

                      context
                          .read<InventoryBloc>()
                          .add(InventoryProductAdded(product));
                      Navigator.pop(ctx);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEditingLocal
                                ? '${product.name} actualizado'
                                : '${product.name} agregado al catálogo',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isEditingLocal
                          ? 'GUARDAR CAMBIOS'
                          : 'AGREGAR AL CATÁLOGO',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _isHandlingScan = false;
          _isSheetOpen = false; // FIX: always reset on close
        });
      }
    });
  }
}

// ── Scan reticle ──────────────────────────────────────────────────────────────

class _ScanReticle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      height: 120,
      child: CustomPaint(
        painter: _ReticlePainter(),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const corner = 20.0;
    const len = 28.0;
    final r = Radius.circular(corner);

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, corner)
        ..arcToPoint(Offset(corner, 0), radius: r)
        ..lineTo(len, 0),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, 0)
        ..lineTo(size.width - corner, 0)
        ..arcToPoint(Offset(size.width, corner), radius: r)
        ..lineTo(size.width, len),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height - len)
        ..lineTo(size.width, size.height - corner)
        ..arcToPoint(Offset(size.width - corner, size.height), radius: r)
        ..lineTo(size.width - len, size.height),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(len, size.height)
        ..lineTo(corner, size.height)
        ..arcToPoint(Offset(0, size.height - corner), radius: r)
        ..lineTo(0, size.height - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Scanner toggle button ─────────────────────────────────────────────────────

class _ScannerToggleButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _ScannerToggleButton({
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? cs.primary : cs.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.close_rounded : Icons.qr_code_scanner_rounded,
              size: 18,
              color: isActive ? cs.onPrimary : cs.primary,
            ),
            const SizedBox(width: 6),
            Text(
              isActive ? 'Cerrar' : 'Escanear',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isActive ? cs.onPrimary : cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final String selectedValue;
  final Function(String) onSelect;
  final ColorScheme cs;

  const _TypeChip(this.value, this.label, this.icon, this.selectedValue,
      this.onSelect, this.cs);

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selectedValue;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        avatar:
            Icon(icon, size: 16, color: isSelected ? cs.onPrimary : cs.primary),
        selected: isSelected,
        onSelected: (_) => onSelect(value),
        selectedColor: cs.primary,
        labelStyle: TextStyle(
          color: isSelected ? cs.onPrimary : cs.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Buscar por nombre o código...',
        prefixIcon: Icon(
          Icons.search_rounded,
          color: cs.onSurface.withValues(alpha: 0.4),
        ),
        suffixIcon: ValueListenableBuilder(
          valueListenable: controller,
          builder: (_, val, __) => val.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: controller.clear,
                )
              : const SizedBox.shrink(),
        ),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isSearch;

  const _EmptyState({required this.isSearch});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset('assets/animations/waiting.json', width: 140),
          const SizedBox(height: 16),
          Text(
            isSearch ? 'Sin resultados' : 'Catálogo vacío',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isSearch
                ? 'No hay productos que coincidan con tu búsqueda.'
                : 'Agrega tu primer producto con el botón +.',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Inventory item card ───────────────────────────────────────────────────────

class _InventoryItemCard extends StatelessWidget {
  final Product product;
  final bool highlight;
  final VoidCallback onEdit;

  const _InventoryItemCard({
    required this.product,
    required this.highlight,
    required this.onEdit,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Eliminar producto',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          '¿Quieres eliminar "${product.name}" de tu catálogo local?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<InventoryBloc>().add(InventoryProductRemoved(product.upc));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} eliminado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stock = product.stock;
    final isService = product.productType == 'SERVICE';
    final isWeighed = product.productType == 'WEIGHED' ||
        product.measurementUnit == 'KG' ||
        product.measurementUnit == 'LTS';

    final isCritical = !isService && stock < 3;
    final isLow = !isService && stock < 10 && !isCritical;

    final stockColor = isCritical
        ? Colors.red
        : isLow
            ? Colors.orange.shade700
            : Colors.green.shade700;

    Color getCardColor() {
      switch (product.productType) {
        case 'SERVICE':
          return Colors.blue;
        case 'WEIGHED':
          return Colors.teal;
        case 'PREPARED':
          return Colors.orange;
        case 'INTERNAL':
          return Colors.deepPurple;
        default:
          return cs.primary;
      }
    }

    IconData getCardIcon() {
      switch (product.productType) {
        case 'SERVICE':
          return Icons.miscellaneous_services_rounded;
        case 'WEIGHED':
          return Icons.scale_rounded;
        case 'PREPARED':
          return Icons.restaurant_rounded;
        case 'INTERNAL':
          return Icons.inventory_2_rounded;
        default:
          return Icons.qr_code_2_rounded;
      }
    }

    final cardColor = getCardColor();
    final cardIcon = getCardIcon();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: highlight
                    ? cs.primary
                    : cs.outlineVariant.withValues(alpha: 0.4),
                width: highlight ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      cardIcon,
                      color: cardColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${product.upc} • ${isService ? 'Servicio' : product.productType}',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.45),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Price + stock badge row
                        Row(
                          children: [
                            _Chip(
                              label: '\$${product.price.toStringAsFixed(2)}',
                              color: Colors.green.shade700,
                              bgColor: Colors.green.withValues(alpha: 0.08),
                            ),
                            if (isCritical || isLow) ...[
                              const SizedBox(width: 6),
                              _Chip(
                                label:
                                    isCritical ? '⚠ Crítico' : '↓ Stock bajo',
                                color: stockColor,
                                bgColor: stockColor.withValues(alpha: 0.1),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Stock control
                  if (isService)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        '∞',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    )
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StockButton(
                          icon: Icons.add_rounded,
                          onTap: () => context
                              .read<InventoryBloc>()
                              .add(InventoryStockUpdated(product.upc, 1)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isWeighed
                              ? stock.toStringAsFixed(2)
                              : stock.toInt().toString(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isCritical ? Colors.red : null,
                          ),
                        ),
                        Text(
                          product.measurementUnit,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 2),
                        _StockButton(
                          icon: Icons.remove_rounded,
                          onTap: () => context
                              .read<InventoryBloc>()
                              .add(InventoryStockUpdated(product.upc, -1)),
                        ),
                      ],
                    ),
                  const SizedBox(width: 4),

                  // Delete
                  IconButton(
                    onPressed: () => _confirmDelete(context),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.07),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Chip ──────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;

  const _Chip({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ── Stock button ──────────────────────────────────────────────────────────────

class _StockButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StockButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 15, color: cs.primary),
      ),
    );
  }
}
