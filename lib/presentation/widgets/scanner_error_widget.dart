import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerErrorWidget extends StatelessWidget {
  final MobileScannerException error;
  final VoidCallback onRetry;

  const ScannerErrorWidget({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    String title = 'Error de Cámara';
    String message = 'Hubo un problema al iniciar el escáner.';
    IconData icon = Icons.error_outline_rounded;

    if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
      title = 'Permisos Necesarios';
      message = 'Activa la cámara en los ajustes de tu celular para vender.';
      icon = Icons.no_photography_rounded;
    } else if (error.errorCode == MobileScannerErrorCode.unsupported) {
      title = 'Cámara No Soportada';
      message = 'Tu dispositivo no parece ser compatible con el escáner.';
    }

    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.amber.shade700),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('REINTENTAR ESCÁNER'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B6CA8),
              minimumSize: const Size(200, 48),
            ),
          ),
          if (error.errorCode == MobileScannerErrorCode.permissionDenied)
            TextButton(
              onPressed: () {
                // Sr. UX: Podríamos usar permission_handler para abrir ajustes
              },
              child: const Text('Configurar Permisos'),
            ),
        ],
      ),
    );
  }
}
