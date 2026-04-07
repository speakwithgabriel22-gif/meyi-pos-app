import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/router.dart';
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
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forzar retrato para consistencia en POS móvil
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Inyección de dependencias
  final posService = PosService();
  final businessRepo = MockBusinessRepository();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => ThemeBloc()..add(ThemeLoaded())),
        BlocProvider(create: (context) => AuthBloc(posService)),
        BlocProvider(create: (context) => CartBloc(posService)),
        BlocProvider(create: (context) => CashBloc()),
        BlocProvider(
            create: (context) =>
                InventoryBloc(businessRepo)..add(InventoryStarted())),
        BlocProvider(
            create: (context) =>
                SuppliersBloc(businessRepo)..add(SuppliersStarted())),
        BlocProvider(
            create: (context) =>
                ReportsBloc(businessRepo)..add(ReportsStarted())),
        BlocProvider(
            create: (context) =>
                SalesHistoryBloc(businessRepo)..add(SalesHistoryStarted())),
      ],
      child: const PosTienditaApp(),
    ),
  );
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
        );
      },
    );
  }
}

