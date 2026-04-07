import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<List<ConnectivityResult>> _controller = StreamController<List<ConnectivityResult>>.broadcast();

  ConnectivityService() {
    _connectivity.onConnectivityChanged.listen(_controller.add);
  }

  Stream<List<ConnectivityResult>> get onConnectivityChanged => _controller.stream;

  Future<bool> hasInternet() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  void dispose() {
    _controller.close();
  }
}