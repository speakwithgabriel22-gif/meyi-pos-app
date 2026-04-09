import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../../data/local/db_helper.dart';
import '../../logic/blocs/sync_bloc.dart';
import '../../utils/constants.dart';

/// Servicio que gestiona la sincronización automática en background.
/// Funciona en Windows, Android, iOS (no depende de Workmanager).
class BackgroundSyncService {
  static final BackgroundSyncService _instance =
      BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  Timer? _periodicTimer;
  Timer? _inactivityTimer;
  SyncBloc? _syncBloc;

  // Configuración
  static const Duration _periodicInterval = Duration(minutes: 20);
  static const Duration _inactivityDelay = Duration(seconds: 30);
  static const Duration _initialDelay = Duration(seconds: 5);

  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  DateTime? _lastUserInteraction;

  /// Inicializa el servicio con el SyncBloc
  void initialize(SyncBloc syncBloc) {
    _syncBloc = syncBloc;
    _startPeriodicSync();
    debugPrint('🔄 BackgroundSyncService inicializado');
  }

  /// Inicia la sincronización periódica
  void _startPeriodicSync() {
    // Primera sincronización después de 5 segundos
    Future.delayed(_initialDelay, () {
      _triggerSyncIfNeeded(reason: 'INICIO');
    });

    // Sincronización periódica cada 15 minutos
    _periodicTimer = Timer.periodic(_periodicInterval, (_) {
      _triggerSyncIfNeeded(reason: 'PERIÓDICA');
    });

    debugPrint(
        '⏰ Sync periódico configurado (cada ${_periodicInterval.inMinutes} min)');
  }

  /// Debe llamarse cada vez que el usuario interactúa con la pantalla
  void onUserInteraction() {
    _lastUserInteraction = DateTime.now();
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityDelay, () {
      _triggerSyncIfNeeded(reason: 'INACTIVIDAD');
    });
  }

  /// Dispara la sincronización si se cumplen las condiciones
  Future<void> _triggerSyncIfNeeded({required String reason}) async {
    if (_syncBloc == null) {
      debugPrint('⚠️ SyncBloc no inicializado');
      return;
    }

    if (_isSyncing) {
      debugPrint('⏭️ Ya hay una sincronización en progreso');
      return;
    }

    // Verificar conexión a internet
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      debugPrint('📴 Sin conexión - Sync omitido ($reason)');
      return;
    }

    // Verificar sesión activa
    final token = Constants.token;
    final tenantId = Constants.tenantId;
    if (token == null ||
        token.isEmpty ||
        tenantId == null ||
        tenantId.isEmpty) {
      debugPrint('🔒 Sin sesión activa - Sync omitido ($reason)');
      return;
    }

    // 🆕 Verificar si hay registros pendientes (evita llamadas innecesarias)
    final hasPending = await _hasPendingRecords(tenantId);
    if (!hasPending) {
      debugPrint('📭 Sin registros pendientes - Sync omitido ($reason)');
      return;
    }

    debugPrint('🚀 Iniciando sincronización automática - $reason');
    _syncBloc!.add(SyncStarted());
  }

  /// Verifica si hay registros pendientes de sincronizar
  Future<bool> _hasPendingRecords(String tenantId) async {
    try {
      final dbHelper = DbHelper();
      final counts = await dbHelper.getDirtyCounts(tenantId);
      final totalPending = counts.values.fold(0, (a, b) => a + b);
      return totalPending > 0;
    } catch (e) {
      debugPrint('⚠️ Error verificando pendientes: $e');
      return true; // En caso de error, intentar sincronizar por seguridad
    }
  }

  /// Sincronización manual (llamada desde UI)
  Future<void> forceSync() async {
    if (_syncBloc == null) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      debugPrint('📴 Sin conexión - Force sync omitido');
      return;
    }

    // Verificar sesión activa
    final token = Constants.token;
    final tenantId = Constants.tenantId;
    if (token == null ||
        token.isEmpty ||
        tenantId == null ||
        tenantId.isEmpty) {
      debugPrint('🔒 Sin sesión activa - Force sync omitido');
      return;
    }

    debugPrint('💪 Iniciando sincronización forzada');
    _syncBloc!.add(SyncStarted());
  }

  /// Marca el inicio de una sincronización
  void notifySyncStarted() {
    _isSyncing = true;
  }

  /// Marca el fin de una sincronización
  void notifySyncFinished() {
    _isSyncing = false;
    _lastSyncTime = DateTime.now();
  }

  /// Libera recursos
  void dispose() {
    _periodicTimer?.cancel();
    _inactivityTimer?.cancel();
    debugPrint('🛑 BackgroundSyncService detenido');
  }
}
