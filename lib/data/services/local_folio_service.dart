import 'package:comedor_app/utils/uuid_generator.dart';
import 'package:intl/intl.dart';
import '../local/db_helper.dart';
import '../services/sync_event_bus_service.dart'; // 🆕 Importar

class LocalFolioService {
  final DbHelper _dbHelper = DbHelper();

  /// Genera el siguiente folio para un tenant y tipo (tipo SAL, EXP, etc.)
  /// Sigue el formato: TIPO-YYYYMMDD-0001
  Future<String> siguiente(String tenantId, String tipo) async {
    final db = await _dbHelper.database;
    final hoy = DateFormat('yyyyMMdd').format(DateTime.now());

    // 1. Buscar si ya existe un registro para hoy de ese tipo
    final List<Map<String, dynamic>> res = await db.query(
      'registro_folios',
      where: 'tenant_id = ? AND tipo = ? AND fecha = ?',
      whereArgs: [tenantId, tipo, hoy],
    );

    int proximoFolio = 1;
    String id;

    if (res.isNotEmpty) {
      final row = res.first;
      id = row['id'] as String;
      proximoFolio = (row['ultimo_folio'] as int) + 1;

      // Actualizar
      await db.update(
        'registro_folios',
        {
          'ultimo_folio': proximoFolio,
          'is_dirty': 1,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      id = UuidGenerator.generate();
      await db.insert('registro_folios', {
        'id': id,
        'tenant_id': tenantId,
        'tipo': tipo,
        'fecha': hoy,
        'ultimo_folio': proximoFolio,
        'is_dirty': 1,
      });
    }

    // 🆕 Notificar cambio pendiente
    SyncEventBus().notifyDataChanged();

    // Formatear: SAL-20260407-0001
    return "$tipo-$hoy-${proximoFolio.toString().padLeft(4, '0')}";
  }
}
