import 'package:flutter/material.dart';

class ProfessionalBackground extends StatelessWidget {
  final Widget child;

  const ProfessionalBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Obtenemos un color primario suavecito según el tema
    final blobColor = isDark 
        ? colorScheme.primary.withOpacity(0.12) 
        : colorScheme.primary.withOpacity(0.06);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          // Blob Superior Derecho
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: blobColor,
              ),
            ),
          ),
          // Blob Inferior Izquierdo
          Positioned(
            bottom: -120,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: blobColor,
              ),
            ),
          ),
          // Contenido Principal
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
