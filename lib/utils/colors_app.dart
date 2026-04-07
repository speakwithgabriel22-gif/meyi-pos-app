import 'package:flutter/material.dart';

class AppColors {
  // 🔴 COLORES DE MARCA (Brand Colors)
  // El rojo exacto del logo (vibrante y profesional)
  static Color primaryRed = const Color.fromARGB(255, 0, 150, 205);
  // Un rojo más oscuro para degradados o estados "pressed"
  static const Color darkRed = Color.fromARGB(255, 2, 2, 6);

  // ⚪⚪ SUPERFICIES CLARAS (Light Theme)
  static const Color bgLight =
      Color(0xFFF5F5F7); // Gris frío muy claro (tipo Apple/Industrial)
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textMainLight = Color(0xFF1D1D1F); // Negro casi puro
  static const Color textSecondaryLight =
      Color(0xFF6E6E73); // Gris para subtítulos

  // ⚫⚫ SUPERFICIES OSCURAS (Dark Theme)
  static const Color bgDark = Color(0xFF000000); // Negro puro (oled ready)
  static const Color surfaceDark =
      Color(0xFF1C1C1E); // Gris muy oscuro para tarjetas
  static const Color textMainDark = Color(0xFFF5F5F7);
  static const Color textSecondaryDark = Color(0xFF86868B);

  // 🚥 ESTADOS DE CONSUMO (Sincronizados con tu Enum de Java)
  static const Color created = Color(0xFF007AFF); // Azul (Info/Nuevo)
  static const Color paid = Color(0xFF5856D6); // Morado (Transacción ok)
  static const Color preparing = Color(0xFFFF9500); // Naranja (En cocina)
  static const Color ready = Color(0xFF34C759); // Verde (¡Listo!)
  static const Color delivered = Color(0xFF8E8E93); // Gris (Historial)
  static const Color cancelled = Color(0xFFFF3B30); // Rojo Error
}
