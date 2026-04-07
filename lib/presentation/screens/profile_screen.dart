import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../logic/blocs/auth_bloc.dart';
import '../../logic/blocs/theme_bloc.dart';
import '../../utils/colors_app.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isDark = context.watch<ThemeBloc>().state.isDark;
    final cs = Theme.of(context).colorScheme;

    // Datos del usuario desde el bloc
    String userName = 'Usuario';
    String phone = '';
    String role = 'owner';
    
    if (authState is AuthAuthenticated) {
      userName = authState.userName.isNotEmpty ? authState.userName : 'Usuario';
      phone = authState.phone;
      role = authState.role;
    }
    
    final String initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

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
              subtitle: 'Configurar nombre y dirección',
              onTap: () {},
            ),
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
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.privacy_tip_rounded,
              iconColor: AppColors.primaryRed,
              title: 'Aviso de privacidad',
              subtitle: 'Consulta nuestras políticas',
              onTap: () => _lanzarUrl(context, 'https://example.com/privacidad'),
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

  Future<void> _lanzarUrl(BuildContext context, String url) async {
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
    final roleLabel = role == 'owner' ? 'Propietario' : 'Cajero';
    final roleColor = role == 'owner' ? AppColors.primaryRed : AppColors.created;

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
          // Avatar
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

          // Nombre
          Text(
            userName,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),

          // Teléfono
          if (phone.isNotEmpty)
            Text(
              '+52 $phone',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          const SizedBox(height: 12),

          // Badge de rol
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
                  role == 'owner' ? Icons.verified_rounded : Icons.badge_rounded,
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
          // Handle visual
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: cs.onSurface.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Icono de advertencia
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

          // Botón: Sí, cerrar
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

          // Botón: Cancelar
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
// COLOR PICKER (Cambio de variables dinámico)
// ─────────────────────────────────────────────────────────────────
class _ColorPickerRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeState = context.watch<ThemeBloc>().state;
    final currentColor = themeState.primaryColor;
    
    final List<Color> colors = [
      const Color.fromARGB(255, 0, 150, 205), // Azul marca principal
      const Color(0xFFE53935), // Rojo
      const Color(0xFF43A047), // Verde
      const Color(0xFF8E24AA), // Morado
      const Color(0xFFFF9800), // Naranja
      const Color(0xFF3949AB), // Índigo
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
                  color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
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
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 24)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
