import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/blocs/sync_bloc.dart';

class SyncStatusWidget extends StatelessWidget {
  final VoidCallback? onSyncTap;

  const SyncStatusWidget({super.key, this.onSyncTap});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncBloc, SyncState>(
      builder: (context, state) {
        return InkWell(
          onTap: state is SyncInProgress ? null : onSyncTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getBackgroundColor(state),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIcon(state),
                const SizedBox(width: 6),
                Text(
                  _getStatusText(state),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getTextColor(state),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getBackgroundColor(SyncState state) {
    if (state is SyncInProgress) return Colors.blue.shade50;
    if (state is SyncSuccess) return Colors.green.shade50;
    if (state is SyncFailure) return Colors.red.shade50;
    return Colors.grey.shade100;
  }

  Color _getTextColor(SyncState state) {
    if (state is SyncInProgress) return Colors.blue.shade700;
    if (state is SyncSuccess) return Colors.green.shade700;
    if (state is SyncFailure) return Colors.red.shade700;
    return Colors.grey.shade600;
  }

  Widget _buildIcon(SyncState state) {
    if (state is SyncInProgress) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (state is SyncSuccess) {
      return Icon(Icons.cloud_done, size: 16, color: Colors.green.shade700);
    }
    if (state is SyncFailure) {
      return Icon(Icons.cloud_off, size: 16, color: Colors.red.shade700);
    }
    return Icon(Icons.cloud_queue, size: 16, color: Colors.grey.shade600);
  }

  String _getStatusText(SyncState state) {
    if (state is SyncInProgress) {
      return 'Sync: ${state.currentTable}';
    }
    if (state is SyncSuccess) {
      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      return 'Sync $timeStr';
    }
    if (state is SyncFailure) {
      return 'Error de sync';
    }
    return 'Pendiente';
  }
}
