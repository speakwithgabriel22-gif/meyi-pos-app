import 'dart:async';
import 'dart:convert';
import 'package:comedor_app/data/local/db_helper.dart';
import 'package:comedor_app/data/services/background_sync_service.dart';
import 'package:comedor_app/data/services/sync_event_bus_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import '../../data/services/sync_service.dart';
import '../../utils/constants.dart';

// ==========================================
// EVENTS
// ==========================================
abstract class SyncEvent extends Equatable {
  const SyncEvent();
  @override
  List<Object> get props => [];
}

class SyncStarted extends SyncEvent {}

class SyncSuppliersOnly extends SyncEvent {}

class SyncCashSessionsOnly extends SyncEvent {}

class CheckPendingCount extends SyncEvent {}

// ==========================================
// STATES
// ==========================================
abstract class SyncState extends Equatable {
  const SyncState();
  @override
  List<Object> get props => [];
}

class SyncInitial extends SyncState {}

class SyncInProgress extends SyncState {
  final String currentTable;
  final double progress;
  final int completed;
  final int total;

  const SyncInProgress({
    required this.currentTable,
    required this.progress,
    this.completed = 0,
    this.total = 0,
  });

  @override
  List<Object> get props => [currentTable, progress, completed, total];
}

class SyncSuccess extends SyncState {
  final int syncedCount;
  const SyncSuccess({this.syncedCount = 0});

  @override
  List<Object> get props => [syncedCount];
}

class SyncFailure extends SyncState {
  final String error;
  final String? failedTable;

  const SyncFailure(this.error, {this.failedTable});

  @override
  List<Object> get props => [error, failedTable ?? ''];
}

class PendingCountUpdated extends SyncState {
  final Map<String, int> pendingByTable;
  final int totalPending;

  const PendingCountUpdated(this.pendingByTable, this.totalPending);

  @override
  List<Object> get props => [pendingByTable, totalPending];
}

// ==========================================
// BLOC
// ==========================================
class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final SyncService _syncService;
  late final StreamSubscription _dataChangeSubscription;
  final BackgroundSyncService _backgroundSync = BackgroundSyncService();

  // Orden correcto de sincronización (respeta dependencias FK)
  static const int _totalTables = 8;

  SyncBloc({SyncService? syncService})
      : _syncService = syncService ?? SyncService(),
        super(SyncInitial()) {
    on<SyncStarted>(_onSyncStarted);
    on<SyncSuppliersOnly>(_onSyncSuppliersOnly);
    on<SyncCashSessionsOnly>(_onSyncCashSessionsOnly);
    on<CheckPendingCount>(_onCheckPendingCount);

    _dataChangeSubscription = SyncEventBus().onDataChanged.listen((_) {
      add(CheckPendingCount());
    });

    add(CheckPendingCount());
  }

  @override
  Future<void> close() {
    _dataChangeSubscription.cancel();
    return super.close();
  }

  /// Sincronización completa de TODAS las tablas
  Future<void> _onSyncStarted(
      SyncStarted event, Emitter<SyncState> emit) async {
    _backgroundSync.notifySyncStarted();

    emit(const SyncInProgress(
      currentTable: 'Iniciando sincronización...',
      progress: 0.0,
      completed: 0,
      total: _totalTables,
    ));

    try {
      // 🔐 VERIFICAR AUTENTICACIÓN
      final token = Constants.token;
      final tenantId = Constants.tenantId;

      if (token == null || token.isEmpty) {
        _backgroundSync.notifySyncFinished();
        emit(const SyncFailure(
            'No hay sesión activa. Inicia sesión para sincronizar.'));
        return;
      }

      if (tenantId == null || tenantId.isEmpty) {
        _backgroundSync.notifySyncFinished();
        emit(const SyncFailure('No hay un tenant activo para sincronizar'));
        return;
      }

      if (_isTokenExpired(token)) {
        _backgroundSync.notifySyncFinished();
        emit(const SyncFailure(
            'La sesión ha expirado. Vuelve a iniciar sesión.'));
        return;
      }

      int completed = 0;

      // ==========================================
      // 1. PROVEEDORES
      // ==========================================
      emit(SyncInProgress(
        currentTable: 'Proveedores',
        progress: _calculateProgress(0),
        completed: completed,
        total: _totalTables,
      ));
      final suppliersSuccess =
          await _syncService.syncSuppliers(tenantId: tenantId);
      if (suppliersSuccess) {
        completed++;
        await Future.delayed(const Duration(milliseconds: 2000));
      }

      // ==========================================
      // 2. SESIONES DE CAJA
      // ==========================================
      emit(SyncInProgress(
        currentTable: 'Sesiones de caja',
        progress: _calculateProgress(1),
        completed: completed,
        total: _totalTables,
      ));
      final cashSuccess =
          await _syncService.syncCashSessions(tenantId: tenantId);
      if (cashSuccess) {
        completed++;
        await Future.delayed(const Duration(milliseconds: 2000));
      }

      // ==========================================
      // 3. PRODUCTOS
      // ==========================================
      emit(SyncInProgress(
        currentTable: 'Productos',
        progress: _calculateProgress(2),
        completed: completed,
        total: _totalTables,
      ));
      final productsSuccess =
          await _syncService.syncStoreProducts(tenantId: tenantId);
      if (productsSuccess) {
        completed++;
        await Future.delayed(const Duration(milliseconds: 2000));
      }

      // ==========================================
      // 4. FOLIOS
      // ==========================================
      emit(SyncInProgress(
        currentTable: 'Folios',
        progress: _calculateProgress(3),
        completed: completed,
        total: _totalTables,
      ));
      final foliosSuccess =
          await _syncService.syncRegistroFolios(tenantId: tenantId);
      if (foliosSuccess) {
        completed++;
        await Future.delayed(const Duration(milliseconds: 2000));
      }

      // ==========================================
      // 5. GASTOS
      // ==========================================
      emit(SyncInProgress(
        currentTable: 'Gastos',
        progress: _calculateProgress(4),
        completed: completed,
        total: _totalTables,
      ));
      final expensesSuccess =
          await _syncService.syncExpenses(tenantId: tenantId);
      if (expensesSuccess) {
        completed++;
        await Future.delayed(const Duration(milliseconds: 2000));
      }

      // ==========================================
      // 6. TRANSACCIONES DE PROVEEDORES
      // ==========================================
      emit(SyncInProgress(
        currentTable: 'Transacciones',
        progress: _calculateProgress(5),
        completed: completed,
        total: _totalTables,
      ));
      final transactionsSuccess =
          await _syncService.syncSupplierTransactions(tenantId: tenantId);
      if (transactionsSuccess) {
        completed++;
        await Future.delayed(const Duration(milliseconds: 2000));
      }

      // ==========================================
      // 7. VENTAS (con items)
      // ==========================================
      emit(SyncInProgress(
        currentTable: 'Ventas',
        progress: _calculateProgress(6),
        completed: completed,
        total: _totalTables,
      ));
      final salesSuccess = await _syncService.syncSales(tenantId: tenantId);
      if (salesSuccess) {
        completed++;
        await Future.delayed(const Duration(milliseconds: 2000));
      }

      // ==========================================
      // 8. ITEMS DE RECEPCIÓN
      // ==========================================
      emit(SyncInProgress(
        currentTable: 'Recepciones',
        progress: _calculateProgress(7),
        completed: completed,
        total: _totalTables,
      ));
      final receptionSuccess =
          await _syncService.syncReceptionItems(tenantId: tenantId);
      if (receptionSuccess) {
        completed++;
        await Future.delayed(const Duration(milliseconds: 2000));
      }

      // Actualizar contador de pendientes
      add(CheckPendingCount());

      _backgroundSync.notifySyncFinished();

      if (completed == _totalTables) {
        emit(SyncSuccess(syncedCount: completed));
      } else {
        emit(SyncFailure(
            'Algunas tablas no se sincronizaron correctamente (${completed}/${_totalTables})'));
      }
    } catch (e) {
      _backgroundSync.notifySyncFinished();
      debugPrint('❌ Error en SyncBloc._onSyncStarted: $e');

      if (e.toString().contains('401') || e.toString().contains('403')) {
        emit(const SyncFailure('Sesión expirada. Vuelve a iniciar sesión.'));
      } else {
        emit(SyncFailure('Error inesperado durante la sincronización: $e'));
      }
    }
  }

  double _calculateProgress(int step) {
    return (step + 0.5) / _totalTables;
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));

      final exp = payload['exp'] as int?;
      if (exp == null) return true;

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiryDate);
    } catch (e) {
      return true;
    }
  }

  Future<void> _onSyncSuppliersOnly(
      SyncSuppliersOnly event, Emitter<SyncState> emit) async {
    if (state is SyncInProgress) {
      debugPrint('⚠️ Ya hay una sincronización en progreso');
      return;
    }

    _backgroundSync.notifySyncStarted();

    emit(const SyncInProgress(
      currentTable: 'Proveedores',
      progress: 0.0,
      completed: 0,
      total: 1,
    ));

    try {
      final token = Constants.token;
      final tenantId = Constants.tenantId;

      if (token == null || token.isEmpty) {
        _backgroundSync.notifySyncFinished();
        emit(const SyncFailure(
            'No hay sesión activa. Inicia sesión para sincronizar.'));
        return;
      }

      if (tenantId == null || tenantId.isEmpty) {
        _backgroundSync.notifySyncFinished();
        emit(const SyncFailure('No hay un tenant activo para sincronizar'));
        return;
      }

      if (_isTokenExpired(token)) {
        _backgroundSync.notifySyncFinished();
        emit(const SyncFailure(
            'La sesión ha expirado. Vuelve a iniciar sesión.'));
        return;
      }

      emit(const SyncInProgress(
        currentTable: 'Proveedores',
        progress: 0.5,
        completed: 0,
        total: 1,
      ));

      final success = await _syncService.syncSuppliers(tenantId: tenantId);

      add(CheckPendingCount());
      _backgroundSync.notifySyncFinished();

      if (success) {
        emit(SyncSuccess(syncedCount: 1));
      } else {
        emit(const SyncFailure('No se pudieron sincronizar los proveedores',
            failedTable: 'suppliers'));
      }
    } catch (e) {
      _backgroundSync.notifySyncFinished();
      debugPrint('❌ Error en SyncBloc._onSyncSuppliersOnly: $e');

      if (e.toString().contains('401') || e.toString().contains('403')) {
        emit(const SyncFailure('Sesión expirada. Vuelve a iniciar sesión.'));
      } else {
        emit(SyncFailure('Error sincronizando proveedores: $e',
            failedTable: 'suppliers'));
      }
    }
  }

  Future<void> _onSyncCashSessionsOnly(
      SyncCashSessionsOnly event, Emitter<SyncState> emit) async {
    if (state is SyncInProgress) {
      debugPrint('⚠️ Ya hay una sincronización en progreso');
      return;
    }

    _backgroundSync.notifySyncStarted();

    emit(const SyncInProgress(
      currentTable: 'Sesiones de caja',
      progress: 0.0,
      completed: 0,
      total: 1,
    ));

    try {
      final token = Constants.token;
      final tenantId = Constants.tenantId;

      if (token == null || token.isEmpty) {
        _backgroundSync.notifySyncFinished();
        emit(const SyncFailure(
            'No hay sesión activa. Inicia sesión para sincronizar.'));
        return;
      }

      if (tenantId == null || tenantId.isEmpty) {
        _backgroundSync.notifySyncFinished();
        emit(const SyncFailure('No hay un tenant activo para sincronizar'));
        return;
      }

      if (_isTokenExpired(token)) {
        _backgroundSync.notifySyncFinished();
        emit(const SyncFailure(
            'La sesión ha expirado. Vuelve a iniciar sesión.'));
        return;
      }

      emit(const SyncInProgress(
        currentTable: 'Sesiones de caja',
        progress: 0.5,
        completed: 0,
        total: 1,
      ));

      final success = await _syncService.syncCashSessions(tenantId: tenantId);

      add(CheckPendingCount());
      _backgroundSync.notifySyncFinished();

      if (success) {
        emit(SyncSuccess(syncedCount: 1));
      } else {
        emit(const SyncFailure(
            'No se pudieron sincronizar las sesiones de caja',
            failedTable: 'cash_sessions'));
      }
    } catch (e) {
      _backgroundSync.notifySyncFinished();
      debugPrint('❌ Error en SyncBloc._onSyncCashSessionsOnly: $e');

      if (e.toString().contains('401') || e.toString().contains('403')) {
        emit(const SyncFailure('Sesión expirada. Vuelve a iniciar sesión.'));
      } else {
        emit(SyncFailure('Error sincronizando sesiones de caja: $e',
            failedTable: 'cash_sessions'));
      }
    }
  }

  Future<void> _onCheckPendingCount(
      CheckPendingCount event, Emitter<SyncState> emit) async {
    try {
      final tenantId = Constants.tenantId;
      if (tenantId == null || tenantId.isEmpty) {
        emit(const PendingCountUpdated({}, 0));
        return;
      }

      final dbHelper = DbHelper();
      final pendingByTable = await dbHelper.getDirtyCounts(tenantId);
      final totalPending = pendingByTable.values.fold(0, (a, b) => a + b);

      emit(PendingCountUpdated(pendingByTable, totalPending));

      debugPrint('📊 Pendientes actualizados: $totalPending registro(s)');
    } catch (e) {
      debugPrint('❌ Error verificando pendientes: $e');
      emit(const PendingCountUpdated({}, 0));
    }
  }

  String _getTableDisplayName(String tableName) {
    return switch (tableName) {
      'suppliers' => 'Proveedores',
      'cash_sessions' => 'Sesiones de caja',
      'store_products' => 'Productos',
      'registro_folios' => 'Folios',
      'expenses' => 'Gastos',
      'supplier_transactions' => 'Transacciones',
      'sales' => 'Ventas',
      'sale_items' => 'Items de venta',
      'reception_items' => 'Recepciones',
      _ => tableName,
    };
  }
}
