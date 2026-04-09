import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../logic/blocs/auth_bloc.dart';
import '../../data/services/auth_service.dart';
import '../../logic/blocs/cash_bloc.dart';
import '../../logic/blocs/inventory_bloc.dart';
import '../../logic/blocs/reports_bloc.dart';
import '../../logic/blocs/sales_history_bloc.dart';
import '../../logic/blocs/suppliers_bloc.dart';
import '../../utils/api_helper.dart';
import '../../utils/constants.dart';
import '../../widgets/professional_background.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Inicializa los módulos del tenant (caja, inventario, proveedores, etc.)
  /// Se llama una vez que confirmamos que hay sesión válida.
  void _bootstrapTenantModules() {
    context.read<CashBloc>().add(CashDashboardLoaded());
    context.read<InventoryBloc>().add(InventoryStarted());
    context.read<SuppliersBloc>().add(SuppliersStarted());
    context.read<ReportsBloc>().add(ReportsStarted());
    context.read<SalesHistoryBloc>().add(SalesHistoryStarted());
  }

  /// Navega al home confiando en la sesión local.
  /// Se usa tanto para offline como cuando el servidor no responde.
  void _goHomeWithLocalSession() {
    if (!mounted) return;
    context.read<AuthBloc>().add(AuthRestoreRequested());
    _bootstrapTenantModules();
    context.go('/home');
  }

  Future<void> _init() async {
    debugPrint('--- INICIANDO SPLASH SCREEN (OFFLINE FIRST) ---');

    // ── 1. ATAJO: Si ya hay sesión en memoria (hot reload / estado vivo)
    if (Constants.hasSesion && Constants.hasActiveTenant) {
      debugPrint('-> Atajo en memoria. Entrando a Home y verificando en segundo plano.');
      AuthService().verifySession(); // Fire and forget
      await Future.delayed(const Duration(milliseconds: 300));
      _goHomeWithLocalSession();
      return;
    }

    // ── 2. LEYENDO SECURE STORAGE (Cold start)
    debugPrint('2. LEYENDO SECURE STORAGE...');
    final hasLocalSession = await Constants.loadSesion();

    if (!mounted) return;

    // ── 3. FLUJO OFFLINE-FIRST: ¿Tenemos sesión local persistida?
    if (hasLocalSession && Constants.hasActiveTenant) {
      debugPrint('-> Sesión local encontrada. Entrando a Home de inmediato.');
      // Lanzamos la actualización o chequeo del token al fondo para no bloquear UI
      AuthService().verifySession(); 
      _goHomeWithLocalSession();
      return;
    }

    // ── 4. SIN SESIÓN LOCAL (Requiere Login)
    debugPrint('4. SIN SESIÓN O TENANT INVÁLIDO. Preparando para Login.');
    
    // Limpiamos posibles residuos
    if (hasLocalSession && !Constants.hasActiveTenant) {
      await Constants.clearSesion();
    }

    // ── 5. VERIFICACIÓN DE RED SÓLO PORQUE OCUPAMOS LOGIN PRIMERA VEZ
    final hasInternet = await ApiHelper().hasInternet();
    if (!mounted) return;

    if (!hasInternet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sin conexión. Se requiere internet para acceder o iniciar sesión por primera vez.'),
        ),
      );
    }
    
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ProfessionalBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.15),
                      blurRadius: 50,
                    ),
                  ],
                ),
                child: Center(
                  child: Lottie.asset(
                    'assets/animations/circle-loading.json',
                    width: 100,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'MeyiSoft POS',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 40,
                child: LinearProgressIndicator(
                  backgroundColor: Theme.of(context).dividerColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
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
