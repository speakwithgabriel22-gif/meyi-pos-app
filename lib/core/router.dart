import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../presentation/screens/splash_screen.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/screens/onboarding_screen.dart';
import '../presentation/screens/profile_screen.dart';
import '../presentation/screens/venta_screen.dart';
import '../presentation/screens/cobro_screen.dart';
import '../presentation/screens/main_wrapper.dart';
import '../presentation/screens/inventory_screen.dart';
import '../presentation/screens/suppliers_screen.dart';
import '../presentation/screens/sales_history_screen.dart';
import '../presentation/screens/windows_pos.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Splash
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    // Auth
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    // Onboarding (nuevos usuarios)
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    // Perfil de usuario
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),

    // Modern Shell Navigation (Home, Inventory, Suppliers, Reports)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainWrapper(navigationShell: navigationShell);
      },
      branches: [
        // Tab 1: Dashboard (Reportes)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const PosScreen(),
            ),
          ],
        ),
        // Tab 2: Historial (Ventas de Hoy)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/historial',
              builder: (context, state) => const SalesHistoryScreen(),
            ),
          ],
        ),
        // Tab 3: Inventario
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/inventario',
              builder: (context, state) => const InventoryScreen(),
            ),
          ],
        ),
        // Tab 4: Proveedores
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/proveedores',
              builder: (context, state) => const SuppliersScreen(),
            ),
          ],
        ),
      ],
    ),

    // POS Flow (Goes over the shell because it needs full screen)
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/venta',
      builder: (context, state) => const VentaScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/cobro',
      builder: (context, state) => const CobroScreen(),
    ),
  ],
);
