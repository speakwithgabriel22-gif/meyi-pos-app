import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../logic/blocs/auth_bloc.dart';
import '../../logic/blocs/cash_bloc.dart';
import '../../logic/blocs/inventory_bloc.dart';
import '../../logic/blocs/reports_bloc.dart';
import '../../logic/blocs/sales_history_bloc.dart';
import '../../logic/blocs/suppliers_bloc.dart';
import '../../utils/constants.dart';
import '../../widgets/institutional_footer.dart';
import '../../widgets/professional_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _telCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _pin = '';
  bool _showPhone = true;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _telCtrl.dispose();
    _focusNode.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _appendDigit(String value) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_showPhone) {
        if (_telCtrl.text.length < 10) {
          _telCtrl.text += value;
        }
      } else if (_pin.length < 4) {
        _pin += value;
      }
    });

    if (!_showPhone && _pin.length == 4) {
      _login();
    }
  }

  void _deleteDigit() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_showPhone) {
        if (_telCtrl.text.isNotEmpty) {
          _telCtrl.text = _telCtrl.text.substring(0, _telCtrl.text.length - 1);
        }
      } else if (_pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  void _login() {
    if (_telCtrl.text.length != 10 || _pin.length != 4) return;
    context.read<AuthBloc>().add(AuthLoginRequested(_telCtrl.text, _pin));
  }

  void _refreshTenantAwareModules() {
    context.read<CashBloc>().add(CashDashboardLoaded());
    context.read<InventoryBloc>().add(InventoryStarted());
    context.read<SuppliersBloc>().add(SuppliersStarted());
    context.read<ReportsBloc>().add(ReportsStarted());
    context.read<SalesHistoryBloc>().add(SalesHistoryStarted());
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key.keyLabel.isNotEmpty && RegExp(r'^[0-9]$').hasMatch(key.keyLabel)) {
      _appendDigit(key.keyLabel);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _deleteDigit();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_showPhone) {
        if (_telCtrl.text.length == 10) {
          setState(() => _showPhone = false);
        }
      } else {
        _login();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && !_showPhone) {
      setState(() {
        _showPhone = true;
        _pin = '';
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          if (!state.isNew &&
              (!Constants.hasActiveTenant || state.tenantId.isEmpty)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No se pudo cargar la sucursal activa de esta sesion.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }

          if (state.isNew) {
            context.go('/onboarding', extra: {
              'phone': state.phone,
              'pin': state.pin,
            });
          } else {
            _refreshTenantAwareModules();
            context.go('/home');
          }
        } else if (state is AuthError) {
          _shakeCtrl.forward(from: 0);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.message,
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: cs.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _pin = '');
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Scaffold(
          body: Stack(
            children: [
              Focus(
                focusNode: _focusNode,
                onKeyEvent: _handleKeyEvent,
                autofocus: true,
                child: GestureDetector(
                  onTap: () => _focusNode.requestFocus(),
                  child: ProfessionalBackground(
                    child: SafeArea(
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                children: [
                                  const SizedBox(height: 30),
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: cs.surface,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(
                                            isDark ? 0.3 : 0.05,
                                          ),
                                          blurRadius: 15,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.store_rounded,
                                      size: 48,
                                      color: cs.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Meyi POS',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _showPhone
                                        ? 'Ingresa tu numero de telefono'
                                        : 'Ingresa tu PIN de seguridad',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: cs.onSurface.withOpacity(0.5),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: cs.surface,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(
                                            isDark ? 0.2 : 0.03,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: _showPhone
                                        ? _buildPhoneInput(cs)
                                        : _buildPinInput(cs),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildKeyboard(cs),
                                  const SizedBox(height: 16),
                                  if (!_showPhone)
                                    TextButton(
                                      onPressed: () => setState(() {
                                        _showPhone = true;
                                        _pin = '';
                                      }),
                                      child: const Text(
                                        '<- Usar otro numero',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // const InstitutionalFooter(),
                          const SizedBox(height: 26),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (isLoading) _buildLoadingOverlay(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          color: Colors.black.withOpacity(0.1),
          child: Center(
            child: Lottie.asset(
              'assets/animations/circle-loading.json',
              width: 150,
              height: 150,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput(ColorScheme cs) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '+52',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cs.onSurface.withOpacity(0.3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _telCtrl.text.isEmpty ? '000 000 0000' : _telCtrl.text,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: _telCtrl.text.isEmpty
                      ? cs.onSurface.withOpacity(0.1)
                      : cs.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: _telCtrl.text.length == 10
              ? () => setState(() => _showPhone = false)
              : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'CONTINUAR',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
      ],
    );
  }

  Widget _buildPinInput(ColorScheme cs) {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        final offset = _shakeAnim.value * 12 * (0.5 - _shakeAnim.value).sign;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              4,
              (index) => Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: index < _pin.length
                      ? cs.primary
                      : cs.surfaceVariant.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _telCtrl.text,
            style: TextStyle(
              color: cs.onSurface.withOpacity(0.5),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _pin.length == 4 ? _login : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'INGRESAR',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboard(ColorScheme cs) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '<'];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final key = keys[index];
        if (key.isEmpty) {
          return const SizedBox.shrink();
        }

        final isDelete = key == '<';
        return Material(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: isDelete ? _deleteDigit : () => _appendDigit(key),
            child: Center(
              child: IconTheme(
                data: IconThemeData(color: cs.onSurface),
                child: isDelete
                    ? const Icon(Icons.backspace_rounded)
                    : Text(
                        key,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
