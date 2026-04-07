import 'package:comedor_app/utils/colors_app.dart';
import 'package:flutter/material.dart';

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.info, // Añadimos info para estados como CREADO
  });

  final Color success;
  final Color warning;
  final Color info;

  @override
  AppSemanticColors copyWith({Color? success, Color? warning, Color? info}) {
    return AppSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      info: Color.lerp(info, other.info, t) ?? info,
    );
  }
}

class AppTheme {
  static ThemeData getTheme(bool isDarkMode) {
    // 🚚 Usamos el Rojo Elola como semilla
    final baseScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryRed,
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
    );

    final colorScheme = baseScheme.copyWith(
      primary: AppColors.primaryRed,
      onPrimary: Colors.white,
      secondary: AppColors.darkRed,
      error: AppColors.cancelled,
      surface: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
      // Cambiamos background por surface/scaffold en M3
    );

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,

      // Fondo de la app industrial
      scaffoldBackgroundColor:
          isDarkMode ? AppColors.bgDark : AppColors.bgLight,

      // 💳 CARDS: Más sólidas para transporte
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: isDarkMode ? 0 : 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
      ),

      // 📏 DIVIDERS
      dividerTheme: DividerThemeData(
        color: isDarkMode
            ? AppColors.surfaceDark.withOpacity(0.5)
            : Colors.grey.withOpacity(0.2),
        thickness: 1,
      ),

      // 🔝 APPBAR: Estilo Elola (Sólido)
      appBarTheme: AppBarTheme(
        backgroundColor: isDarkMode ? AppColors.bgDark : AppColors.surfaceLight,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0, // Evita que cambie de color al hacer scroll
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w800, // Extra Bold para branding
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(
            color: isDarkMode ? Colors.white : AppColors.primaryRed),
      ),

      // 🖋️ TEXTOS
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(color: colorScheme.onSurface, fontSize: 16),
        bodyMedium: TextStyle(
          color: colorScheme.onSurface.withOpacity(0.8),
          fontSize: 14,
        ),
      ),

      // 🔘 BOTONES PRINCIPALES
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),

      // 🏷️ BOTTOM SHEET
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      // 🔔 SNACKBAR (Notificaciones de pedido)
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDarkMode ? AppColors.surfaceDark : Colors.black87,
        contentTextStyle:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // 🚦 EXTENSIONES (Semántica de pedidos)
      extensions: <ThemeExtension<dynamic>>[
        AppSemanticColors(
          success: AppColors.ready,
          warning: AppColors.preparing,
          info: AppColors.created,
        ),
      ],
    );
  }
}
