import 'package:flutter/material.dart';
import '../../data/services/background_sync_service.dart';

class InactivityDetector extends StatefulWidget {
  final Widget child;

  const InactivityDetector({super.key, required this.child});

  @override
  State<InactivityDetector> createState() => _InactivityDetectorState();
}

class _InactivityDetectorState extends State<InactivityDetector> {
  final BackgroundSyncService _syncService = BackgroundSyncService();

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _syncService.onUserInteraction(),
      onPointerMove: (_) => _syncService.onUserInteraction(),
      onPointerUp: (_) => _syncService.onUserInteraction(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _syncService.onUserInteraction(),
        onPanStart: (_) => _syncService.onUserInteraction(),
        child: widget.child,
      ),
    );
  }
}
