import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/api_helper.dart';

class ConnectivityChip extends StatefulWidget {
  const ConnectivityChip({super.key});

  @override
  State<ConnectivityChip> createState() => _ConnectivityChipState();
}

class _ConnectivityChipState extends State<ConnectivityChip> {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen((results) async {
      // Aunque Connectivity diga que hay red, validamos con un test real
      if (results.contains(ConnectivityResult.none)) {
        if (mounted) setState(() => _isOnline = false);
      } else {
        final hasRealInternet = await ApiHelper().hasInternet();
        if (mounted) setState(() => _isOnline = hasRealInternet);
      }
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final hasRealInternet = await ApiHelper().hasInternet();
    if (mounted) setState(() => _isOnline = hasRealInternet);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isOnline
          ? const SizedBox.shrink()
          : Container(
              key: const ValueKey('offline'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded,
                      size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Text('Offline',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange.shade700)),
                ],
              ),
            ),
    );
  }
}
