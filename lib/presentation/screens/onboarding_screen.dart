import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'dart:ui';
import '../../widgets/professional_background.dart';
import '../../data/services/auth_service.dart';
import '../../logic/blocs/cash_bloc.dart';
import '../../logic/blocs/inventory_bloc.dart';
import '../../logic/blocs/reports_bloc.dart';
import '../../logic/blocs/sales_history_bloc.dart';
import '../../logic/blocs/suppliers_bloc.dart';

/// Onboarding profesional de 0-fricción para nuevos usuarios.
/// Solo 3 pasos: Bienvenida → Nombre de Tienda → Listo.
class OnboardingScreen extends StatefulWidget {
  /// Teléfono y PIN del usuario que intentó login y no existía
  final String phone;
  final String pin;

  const OnboardingScreen({
    super.key,
    required this.phone,
    required this.pin,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  final _storeNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  int _currentPage = 0;
  bool _isFinishing = false;
  bool _acceptedTerms = false;
  String _selectedPlan = 'Pro'; // Plan sugerido por defecto

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;
  late AnimationController _successCtrl;
  late Animation<double> _successAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _successAnim =
        CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);

    _fadeCtrl.forward();
    _scaleCtrl.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _storeNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
    _fadeCtrl.dispose();
    _scaleCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    HapticFeedback.lightImpact();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishOnboarding() async {
    HapticFeedback.mediumImpact();
    setState(() => _isFinishing = true);
    _successCtrl.forward();

    // Registrar con los datos que llegaron directamente del LoginScreen vía router
    final response = await AuthService().register(
      storeName: _storeNameCtrl.text.trim(),
      ownerName: _ownerNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: widget.phone,
      pin: widget.pin,
    );

    if (response.success) {
      if (mounted) {
        context.read<CashBloc>().add(CashDashboardLoaded());
        context.read<InventoryBloc>().add(InventoryStarted());
        context.read<SuppliersBloc>().add(SuppliersStarted());
        context.read<ReportsBloc>().add(ReportsStarted());
        context.read<SalesHistoryBloc>().add(SalesHistoryStarted());
        context.go('/home');
      }
    } else {
      setState(() => _isFinishing = false);
      _showQuickSnack(response.message ?? 'Ocurrió un error al crear tu tienda');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final darkText = Theme.of(context).colorScheme.onSurface;

    return AnimatedBuilder(
      animation: _fadeAnim,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnim.value,
          child: child,
        );
      },
      child: Scaffold(
        body: Stack(
          children: [
            ProfessionalBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    // ---- Top bar con indicador de progreso ----
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Row(
                        children: [
                          if (_currentPage > 0)
                            GestureDetector(
                              onTap: _previousPage,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Theme.of(context).dividerColor),
                                ),
                                child: Icon(Icons.arrow_back_rounded,
                                    size: 20, color: darkText),
                              ),
                            )
                          else
                            const SizedBox(width: 40),
                          const SizedBox(width: 16),
                          Expanded(child: _buildProgressBar(primaryColor)),
                          const SizedBox(width: 16),
                          Text(
                            '${_currentPage + 1}/4',
                            style: GoogleFonts.outfit(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
    
                    // ---- Pages ----
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (page) {
                          setState(() => _currentPage = page);
                          if (page == 2) _successCtrl.forward();
                        },
                        children: [
                          _buildWelcomePage(primaryColor, darkText),
                          _buildStoreInfoPage(primaryColor, darkText),
                          _buildPricingPage(primaryColor, darkText),
                          _buildReadyPage(primaryColor, darkText),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isFinishing) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          color: Colors.white.withOpacity(0.8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/animations/circle-loading.json',
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 24),
              Text(
                'PREPARANDO TU TIENDA...',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1B6CA8),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Estamos configurando todo para que\npuedas empezar a vender.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================
  // PROGRESS BAR
  // ============================
  Widget _buildProgressBar(Color primaryBlue) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(3),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                width: constraints.maxWidth * ((_currentPage + 1) / 4),
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryBlue, primaryBlue.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================
  // PAGE 1: WELCOME
  // ============================
  Widget _buildWelcomePage(Color primaryBlue, Color darkText) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryBlue,
                      primaryBlue.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              '¡Bienvenido!',
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: darkText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tu punto de venta inteligente\nestá listo para configurarse',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 17,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),

            // Feature highlights
            _buildFeatureRow(
              Icons.bolt_rounded,
              'Ventas ultra rápidas',
              'Cobra en segundos con tu teclado',
              primaryBlue,
            ),
            const SizedBox(height: 16),
            _buildFeatureRow(
              Icons.inventory_2_rounded,
              'Control de inventario',
              'Siempre sabe qué tienes en stock',
              const Color(0xFF2ECC71),
            ),
            const SizedBox(height: 16),
            _buildFeatureRow(
              Icons.analytics_rounded,
              'Reportes claros',
              'Entiende tu negocio de un vistazo',
              const Color(0xFFF39C12),
            ),

            const Spacer(),
            _buildPrimaryButton('COMENZAR', _nextPage),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(
      IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: const Color(0xFF202124),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================
  // PAGE 2: STORE INFO
  // ============================
  Widget _buildStoreInfoPage(Color primaryBlue, Color darkText) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.store_rounded, size: 40, color: primaryBlue),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Tu Negocio',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: darkText,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Solo necesitamos estos datos para\npersonalizar tu experiencia',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Nombre de la tienda
          Text(
            'NOMBRE DE TU TIENDA',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _storeNameCtrl,
            hint: 'Ej: Abarrotes Don Pepe',
            icon: Icons.storefront_rounded,
            primaryBlue: primaryBlue,
          ),
          const SizedBox(height: 24),

          // Nombre del dueño
          Text(
            'TU NOMBRE',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _ownerNameCtrl,
            hint: 'Ej: José Pérez',
            icon: Icons.person_rounded,
            primaryBlue: primaryBlue,
          ),
          const SizedBox(height: 24),

          // Correo del dueño
          Text(
            'CORREO ELECTRÓNICO',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _emailCtrl,
            hint: 'Ej: contacto@tienda.com',
            icon: Icons.email_rounded,
            primaryBlue: primaryBlue,
          ),

          const SizedBox(height: 48),
          _buildPrimaryButton(
            'CONTINUAR',
            () {
              if (_storeNameCtrl.text.trim().isEmpty) {
                _showQuickSnack('Escribe el nombre de tu tienda');
                return;
              }
              if (_ownerNameCtrl.text.trim().isEmpty) {
                _showQuickSnack('Escribe tu nombre');
                return;
              }
              if (_emailCtrl.text.trim().isEmpty) {
                _showQuickSnack('Escribe tu correo electrónico');
                return;
              }
              FocusScope.of(context).unfocus();
              _nextPage();
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                _nextPage();
              },
              child: Text(
                'Configurar después',
                style: GoogleFonts.outfit(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color primaryBlue,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF202124),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(
            color: Colors.grey.shade400,
            fontWeight: FontWeight.normal,
          ),
          prefixIcon: Icon(icon, color: primaryBlue.withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  // ============================
  // PAGE 3: PRICING & T&C
  // ============================
  Widget _buildPricingPage(Color primaryBlue, Color darkText) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2), // Soft red/pink
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_rounded, size: 16, color: Color(0xFFB91C1C)),
                const SizedBox(width: 8),
                Text(
                  '🎁 ¡Pruébalo gratis por 15 días!',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFB91C1C),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Elige tu Plan',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: darkText,
            ),
          ),
          Text(
            'Sin compromisos, cancela cuando quieras',
            style: GoogleFonts.outfit(
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),

          _buildPlanCard(
            'Starter',
            'Sencillo y efectivo',
            'Gratis',
            ['1 Usuario', 'Catálogo Básico', 'Reportes Diarios'],
            primaryBlue,
            isPro: false,
          ),
          const SizedBox(height: 12),
          _buildPlanCard(
            'Pro',
            'Más potencia',
            '\$299/mes',
            ['Usuarios Ilimitados', 'Inventario Avanzado', 'Multi-dispositivo'],
            primaryBlue,
            isPro: true,
          ),
          const SizedBox(height: 12),
          _buildPlanCard(
            'Enterprise',
            'Negocio Total',
            'Personalizado',
            ['Multi-sucursal', 'API Access', 'Soporte 24/7'],
            primaryBlue,
            isPro: false,
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              Checkbox(
                value: _acceptedTerms,
                onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                activeColor: primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                  child: Text.rich(
                    TextSpan(
                      text: 'Acepto los ',
                      style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade600),
                      children: [
                        TextSpan(
                          text: 'Términos y Condiciones',
                          style: TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const TextSpan(text: ' de MeyiSoft POS.'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _buildPrimaryButton(
            'CONFIRMAR Y SIGUIENTE',
            _acceptedTerms ? _nextPage : null,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    String name,
    String desc,
    String price,
    List<String> features,
    Color primaryBlue, {
    bool isPro = false,
  }) {
    final isSelected = _selectedPlan == name;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryBlue : const Color(0xFFE2E8F0),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: primaryBlue.withOpacity(0.12),
                blurRadius: 20,
                spreadRadius: 2,
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF202124),
                      ),
                    ),
                    Text(
                      desc,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                if (isPro)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Sugerido',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: primaryBlue,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: primaryBlue,
                  ),
                ),
                if (!price.contains('Gratis') && !price.contains('Personalizado'))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, left: 4),
                    child: Text(
                      '/ mes',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================
  // PAGE 4: READY
  // ============================
  Widget _buildReadyPage(Color primaryBlue, Color darkText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _successAnim,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2ECC71).withOpacity(0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            '¡Todo Listo!',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: darkText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _storeNameCtrl.text.trim().isNotEmpty
                ? '${_storeNameCtrl.text.trim()} está\nconfigurado y listo para vender'
                : 'Tu tienda está configurada\ny lista para vender',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 17,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),

          // Quick stats preview
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildReadyItem(
                  Icons.point_of_sale_rounded,
                  'Punto de Venta',
                  'Listo',
                  const Color(0xFF2ECC71),
                ),
                const Divider(height: 24),
                _buildReadyItem(
                  Icons.inventory_2_rounded,
                  'Inventario',
                  'Listo',
                  const Color(0xFF2ECC71),
                ),
                const Divider(height: 24),
                _buildReadyItem(
                  Icons.analytics_rounded,
                  'Reportes',
                  'Listo',
                  const Color(0xFF2ECC71),
                ),
              ],
            ),
          ),

          const Spacer(),
          _buildPrimaryButton(
            _isFinishing ? 'PREPARANDO...' : 'IR A MI TIENDA',
            _isFinishing ? null : _finishOnboarding,
            isGreen: true,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildReadyItem(
      IconData icon, String label, String status, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: const Color(0xFF202124),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                status,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================
  // SHARED WIDGETS
  // ============================
  Widget _buildPrimaryButton(String label, VoidCallback? onPressed,
      {bool isGreen = false}) {
    final color = isGreen ? const Color(0xFF2ECC71) : const Color(0xFF1B6CA8);

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
        child: _isFinishing && isGreen
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(label),
      ),
    );
  }

  void _showQuickSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF202124),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
