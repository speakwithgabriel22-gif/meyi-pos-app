import 'package:comedor_app/data/services/background_sync_service.dart';
import 'package:comedor_app/logic/blocs/sync_bloc.dart';
import 'package:comedor_app/widgets/inactivity_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/router.dart';
import 'data/services/auth_service.dart';
import 'data/services/cash_service.dart';
import 'data/services/pos_service.dart';
import 'logic/blocs/auth_bloc.dart';
import 'logic/blocs/cart_bloc.dart';
import 'logic/blocs/cash_bloc.dart';
import 'logic/blocs/inventory_bloc.dart';
import 'logic/blocs/suppliers_bloc.dart';
import 'logic/blocs/reports_bloc.dart';
import 'logic/blocs/sales_history_bloc.dart';
import 'logic/blocs/theme_bloc.dart';
import 'data/repositories/business_repository.dart';
import 'data/repositories/sqlite_business_repository.dart';
import 'utils/app_theme.dart';
import 'logic/blocs/bloc_observer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forzar retrato para consistencia en POS móvil
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Asigna tu observador global
  Bloc.observer = AppBlocObserver();

  // Inyección de dependencias
  final authService = AuthService();
  final cashService = CashService();
  final businessRepo = SqliteBusinessRepository();
  final posService = PosService(businessRepo);

  // 🆕 Crear SyncBloc aquí para poder inicializar BackgroundSyncService
  final syncBloc = SyncBloc();

  runApp(
    RepositoryProvider<BusinessRepository>(
      create: (context) => businessRepo,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => ThemeBloc()..add(ThemeLoaded())),
          BlocProvider(create: (context) => AuthBloc(authService)),
          BlocProvider(create: (context) => CartBloc(posService)),
          BlocProvider(create: (context) => CashBloc(cashService)),
          BlocProvider(create: (context) => InventoryBloc(businessRepo)),
          BlocProvider(create: (context) => SuppliersBloc(businessRepo)),
          BlocProvider(create: (context) => ReportsBloc(businessRepo)),
          BlocProvider(create: (context) => SalesHistoryBloc(businessRepo)),
          BlocProvider.value(
              value: syncBloc), // 🆕 Usar .value con la instancia creada
        ],
        child: const PosTienditaApp(),
      ),
    ),
  );

  // 🆕 Inicializar BackgroundSyncService DESPUÉS de runApp
  // para asegurar que el Bloc esté disponible en el árbol
  WidgetsBinding.instance.addPostFrameCallback((_) {
    BackgroundSyncService().initialize(syncBloc);
  });
}

class PosTienditaApp extends StatelessWidget {
  const PosTienditaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        return MaterialApp.router(
          title: 'POS Tiendita',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getTheme(false),
          darkTheme: AppTheme.getTheme(true),
          themeMode: themeState.isDark ? ThemeMode.dark : ThemeMode.light,
          routerConfig: router,
          themeAnimationDuration: const Duration(milliseconds: 300),
          themeAnimationCurve: Curves.easeInOut,
          // 🆕 El builder permite envolver toda la app con InactivityDetector
          builder: (context, child) {
            return InactivityDetector(
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
