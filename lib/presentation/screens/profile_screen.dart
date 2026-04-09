import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../logic/blocs/auth_bloc.dart';
import '../../logic/blocs/theme_bloc.dart';
import '../../logic/blocs/sync_bloc.dart';
import '../../utils/colors_app.dart';
import '../../utils/constants.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeBloc>().state.isDark;
    final cs = Theme.of(context).colorScheme;

    final userName = Constants.nombre.isNotEmpty ? Constants.nombre : 'Usuario';
    final phone = Constants.phoneNumber;
    final role = Constants.rol;
    final tenantId = Constants.tenantId ?? '';

    final String initial =
        userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Hero del perfil ──────────────────────────────────────────
            _ProfileHero(
              initial: initial,
              userName: userName,
              phone: phone,
              role: role,
              isDark: isDark,
            ),

            const SizedBox(height: 8),

            // ── Sección: Preferencias ────────────────────────────────────
            _SectionLabel(text: 'PREFERENCIAS'),
            _SettingsTile(
              icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              iconColor: AppColors.created,
              title: 'Modo oscuro',
              trailing: Switch.adaptive(
                value: isDark,
                activeColor: AppColors.primaryRed,
                onChanged: (_) {
                  HapticFeedback.lightImpact();
                  context.read<ThemeBloc>().add(ThemeToggleRequested());
                },
              ),
            ),

            const SizedBox(height: 8),

            // ── Sección: Cuenta ──────────────────────────────────────────
            _SectionLabel(text: 'CUENTA'),

            _SettingsTile(
              icon: Icons.store_rounded,
              iconColor: AppColors.ready,
              title: 'Mi Tienda',
              subtitle: tenantId.isNotEmpty
                  ? 'ID: ${tenantId.substring(0, tenantId.length > 8 ? 8 : tenantId.length)}...'
                  : 'Configurar nombre y dirección',
              onTap: () {},
            ),

            // 🆕 SINCRONIZACIÓN
            _SyncSettingsTile(),

            _SettingsTile(
              icon: Icons.lock_rounded,
              iconColor: AppColors.preparing,
              title: 'Cambiar PIN',
              subtitle: 'Actualiza tu PIN de acceso',
              onTap: () {},
            ),

            _SettingsTile(
              icon: Icons.headset_mic_rounded,
              iconColor: AppColors.created,
              title: 'Soporte técnico',
              subtitle: 'Contáctanos por WhatsApp',
              onTap: () => _launchWhatsApp(context),
            ),

            _SettingsTile(
              icon: Icons.privacy_tip_rounded,
              iconColor: AppColors.primaryRed,
              title: 'Aviso de privacidad',
              subtitle: 'Consulta nuestras políticas',
              onTap: () =>
                  _launchUrl(context, 'https://example.com/privacidad'),
            ),

            const SizedBox(height: 8),

            // ── Sección: Sesión ──────────────────────────────────────────
            _SectionLabel(text: 'SESIÓN'),
            _SettingsTile(
              icon: Icons.logout_rounded,
              iconColor: AppColors.cancelled,
              title: 'Cerrar sesión',
              titleColor: AppColors.cancelled,
              onTap: () => _confirmLogout(context),
            ),

            // ── Sección: Personalización (Colores) ──────────────────────
            _SectionLabel(text: 'PERSONALIZACIÓN'),
            _ColorPickerRow(),

            const SizedBox(height: 32),

            // ── Footer ───────────────────────────────────────────────────
            Text(
              'MeyiSoft POS v1.0.0',
              style: GoogleFonts.outfit(
                color: cs.onSurface.withOpacity(0.3),
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LogoutSheet(),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace.')),
        );
      }
    }
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    const phone = '5219991557878';
    const message = 'Hola, necesito soporte técnico para MeyiSoft POS.';
    final uri =
        Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// TILE DE SINCRONIZACIÓN
// ─────────────────────────────────────────────────────────────────
class _SyncSettingsTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncBloc, SyncState>(
      builder: (context, syncState) {
        int pendingCount = 0;
        if (syncState is PendingCountUpdated) {
          pendingCount = syncState.totalPending;
        }

        return _SettingsTile(
          icon: Icons.sync_rounded,
          iconColor: _getIconColor(syncState, pendingCount),
          title: 'Sincronización',
          subtitle: _getSubtitle(syncState, pendingCount),
          trailing: _buildTrailing(syncState, pendingCount),
          onTap: () => _showSyncDialog(context),
        );
      },
    );
  }

  Color _getIconColor(SyncState state, int pendingCount) {
    if (state is SyncInProgress) return AppColors.primaryRed;
    if (state is SyncFailure) return AppColors.cancelled;
    if (pendingCount > 0) return AppColors.warning;
    if (state is SyncSuccess) return AppColors.ready;
    return AppColors.created;
  }

  String _getSubtitle(SyncState state, int pendingCount) {
    if (state is SyncInProgress) {
      return '${state.currentTable} (${(state.progress * 100).toInt()}%)';
    }
    if (state is SyncFailure) return 'Error: ${state.error}';
    if (pendingCount > 0) return '$pendingCount registro(s) pendiente(s)';
    if (state is SyncSuccess) return 'Sincronización completada';
    return 'Todo sincronizado';
  }

  Widget? _buildTrailing(SyncState state, int pendingCount) {
    if (state is SyncInProgress) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: state.progress,
          color: AppColors.primaryRed,
        ),
      );
    }

    if (pendingCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$pendingCount',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.warning,
          ),
        ),
      );
    }

    if (state is SyncSuccess) {
      return Icon(Icons.check_circle_rounded, color: AppColors.ready, size: 20);
    }

    if (state is SyncFailure) {
      return Icon(Icons.error_outline_rounded,
          color: AppColors.cancelled, size: 20);
    }

    return null;
  }

  void _showSyncDialog(BuildContext context) {
    HapticFeedback.selectionClick();

    final token = Constants.token;
    final isLoggedIn = token != null && token.isNotEmpty;

    if (!isLoggedIn) {
      _showLoginRequiredDialog(context);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _SyncBottomSheet(),
    );
  }

  void _showLoginRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: AppColors.warning),
            const SizedBox(width: 8),
            const Text('Sesión requerida'),
          ],
        ),
        content: const Text(
          'Debes iniciar sesión para sincronizar datos con el servidor.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Iniciar sesión'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// HERO DEL PERFIL
// ─────────────────────────────────────────────────────────────────
class _ProfileHero extends StatelessWidget {
  final String initial;
  final String userName;
  final String phone;
  final String role;
  final bool isDark;

  const _ProfileHero({
    required this.initial,
    required this.userName,
    required this.phone,
    required this.role,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final roleLabel = role == 'OWNER' ? 'Propietario' : 'Agente';
    final roleColor =
        role == 'OWNER' ? AppColors.primaryRed : AppColors.created;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryRed, AppColors.darkRed],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryRed.withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: GoogleFonts.outfit(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            userName,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          if (phone.isNotEmpty)
            Text(
              '+52 $phone',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: roleColor.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  role == 'OWNER'
                      ? Icons.verified_rounded
                      : Icons.badge_rounded,
                  size: 14,
                  color: roleColor,
                ),
                const SizedBox(width: 6),
                Text(
                  roleLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: roleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// ETIQUETA DE SECCIÓN
// ─────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TILE DE AJUSTE
// ─────────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveTitleColor = titleColor ?? cs.onSurface;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        onTap: onTap != null
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: effectiveTitleColor,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: cs.onSurface.withOpacity(0.45),
                ),
              )
            : null,
        trailing: trailing ??
            (onTap != null
                ? Icon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurface.withOpacity(0.3),
                    size: 20,
                  )
                : null),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SHEET DE CONFIRMACIÓN DE LOGOUT
// ─────────────────────────────────────────────────────────────────
class _LogoutSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: cs.onSurface.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.cancelled.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: AppColors.cancelled,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '¿Cerrar sesión?',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tendrás que ingresar tu número\ny PIN para volver a entrar.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: cs.onSurface.withOpacity(0.5),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
                context.read<AuthBloc>().add(AuthLogoutRequested());
                context.go('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cancelled,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              child: const Text('SÍ, CERRAR SESIÓN'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurface.withOpacity(0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Cancelar',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// BOTTOM SHEET DE SINCRONIZACIÓN (COMPLETO)
// ─────────────────────────────────────────────────────────────────
class _SyncBottomSheet extends StatefulWidget {
  const _SyncBottomSheet();

  @override
  State<_SyncBottomSheet> createState() => _SyncBottomSheetState();
}

class _SyncBottomSheetState extends State<_SyncBottomSheet> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<SyncBloc, SyncState>(
      listener: (context, state) {
        if (state is SyncSuccess && _isSyncing) {
          _isSyncing = false;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.ready),
                  const SizedBox(width: 8),
                  Text(
                      'Sincronización completada (${state.syncedCount} tabla(s))'),
                ],
              ),
              backgroundColor: cs.surface,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is SyncFailure && _isSyncing) {
          _isSyncing = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: AppColors.cancelled),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.error)),
                ],
              ),
              backgroundColor: cs.surface,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final pendingCount =
            state is PendingCountUpdated ? state.totalPending : 0;
        final pendingByTable = state is PendingCountUpdated
            ? state.pendingByTable
            : <String, int>{};
        final isCurrentlySyncing = state is SyncInProgress;

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sync_rounded,
                  color: AppColors.primaryRed,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isCurrentlySyncing ? 'Sincronizando...' : 'Sincronización',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              if (isCurrentlySyncing && state is SyncInProgress) ...[
                Text(
                  state.currentTable,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: cs.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LinearProgressIndicator(
                    value: state.progress,
                    backgroundColor: cs.surfaceVariant,
                    color: AppColors.primaryRed,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(state.progress * 100).toInt()}%',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryRed,
                  ),
                ),
              ] else ...[
                _buildInfoRow(
                  icon: Icons.pending_actions,
                  label: 'Pendientes de enviar',
                  value: '$pendingCount registro(s)',
                  color: pendingCount > 0 ? AppColors.warning : AppColors.ready,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.cloud_queue,
                  label: 'Tablas a sincronizar',
                  value: _getTablesWithPending(pendingByTable),
                ),
                if (pendingCount > 0) ...[
                  const SizedBox(height: 8),
                  ..._buildPendingBreakdown(pendingByTable),
                ],
                if (state is SyncFailure) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cancelled.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: AppColors.cancelled, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.error,
                            style: TextStyle(
                                color: AppColors.cancelled, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isCurrentlySyncing
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cerrar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isCurrentlySyncing || pendingCount == 0
                          ? null
                          : () {
                              setState(() => _isSyncing = true);
                              context.read<SyncBloc>().add(SyncSuppliersOnly());
                            },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        pendingCount > 0 ? 'SINCRONIZAR AHORA' : 'SINCRONIZAR',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }

  String _getTablesWithPending(Map<String, int> pendingByTable) {
    final tablesWithPending =
        pendingByTable.entries.where((e) => e.value > 0).toList();
    if (tablesWithPending.isEmpty) return 'Ninguna';
    final count = tablesWithPending.length;
    return '$count tabla${count > 1 ? 's' : ''}';
  }

  List<Widget> _buildPendingBreakdown(Map<String, int> pendingByTable) {
    final tablesWithPending =
        pendingByTable.entries.where((e) => e.value > 0).toList();
    if (tablesWithPending.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Text(
            'No hay registros pendientes',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ];
    }
    return tablesWithPending.map((entry) {
      final tableName = _getTableDisplayName(entry.key);
      final count = entry.value;
      return Padding(
        padding: const EdgeInsets.only(left: 32, bottom: 4),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.warning,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tableName,
                style: GoogleFonts.outfit(
                    fontSize: 13, color: Colors.grey.shade700),
              ),
            ),
            Text(
              '$count',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      );
    }).toList();
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

// ─────────────────────────────────────────────────────────────────
// COLOR PICKER
// ─────────────────────────────────────────────────────────────────
class _ColorPickerRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeState = context.watch<ThemeBloc>().state;
    final currentColor = themeState.primaryColor;

    final List<Color> colors = [
      const Color.fromARGB(255, 0, 150, 205),
      const Color(0xFFE53935),
      const Color(0xFF43A047),
      const Color(0xFF8E24AA),
      const Color(0xFFFF9800),
      const Color(0xFF3949AB),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: colors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final color = colors[index];
          final isSelected = currentColor.value == color.value;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.read<ThemeBloc>().add(ThemeColorChanged(color));
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: isSelected ? 3 : 0,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                ],
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 24)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
