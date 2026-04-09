import 'dart:async';

/// Bus de eventos global para notificar cambios en los datos locales.
/// Permite que el SyncBloc se entere cuando hay nuevos registros pendientes.
class SyncEventBus {
  static final SyncEventBus _instance = SyncEventBus._internal();
  factory SyncEventBus() => _instance;
  SyncEventBus._internal();

  final _controller = StreamController<void>.broadcast();

  /// Stream que emite cada vez que se modifica un dato local
  Stream<void> get onDataChanged => _controller.stream;

  /// Notifica que se ha creado/modificado/eliminado un registro
  void notifyDataChanged() {
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}
