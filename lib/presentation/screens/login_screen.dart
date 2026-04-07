import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../logic/blocs/auth_bloc.dart';
import '../../widgets/professional_background.dart';
import '../../widgets/institutional_footer.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _telCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _pin = '';
  bool _mostrarTel = true; // true = teléfono, false = PIN

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
    
    // Sr. UX: Auto-enfocado para teclado físico (Windows/Mac)
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

  void _onDigito(String d) {
    HapticFeedback.lightImpact();
    if (_mostrarTel) {
      if (_telCtrl.text.length < 10) setState(() => _telCtrl.text += d);
    } else {
      if (_pin.length < 4) {
        setState(() => _pin += d);
        if (_pin.length == 4) _login();
      }
    }
  }

  void _onBorrar() {
    HapticFeedback.mediumImpact();
    if (_mostrarTel) {
      if (_telCtrl.text.isNotEmpty) {
        setState(() => _telCtrl.text =
            _telCtrl.text.substring(0, _telCtrl.text.length - 1));
      }
    } else {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
    }
  }

  void _login() {
    context.read<AuthBloc>().add(AuthLoginRequested(_telCtrl.text, _pin));
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    
    // Números (0-9) y Numpad (0-9)
    if (key.keyLabel.isNotEmpty && RegExp(r'^[0-9]$').hasMatch(key.keyLabel)) {
      _onDigito(key.keyLabel);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.backspace) {
      _onBorrar();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_mostrarTel) {
        if (_telCtrl.text.length == 10) {
          setState(() => _mostrarTel = false);
        }
      } else {
        if (_pin.length == 4) _login();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape && !_mostrarTel) {
      setState(() {
        _mostrarTel = true;
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

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          if (state.isNew) {
            context.go('/onboarding');
          } else {
            context.go('/home');
          }
        } else if (state is AuthError) {
          _shakeCtrl.forward(from: 0);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message,
                  style: const TextStyle(color: Colors.white)),
              backgroundColor: cs.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _pin = '');
        }
      },
      child: Scaffold(
        body: Focus(
          focusNode: _focusNode,
          onKeyEvent: _handleKeyEvent,
          autofocus: true,
          child: GestureDetector(
            onTap: () => _focusNode.requestFocus(), // Asegurar que el click no quite el foco
            child: ProfessionalBackground(
              child: SafeArea(
                child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        // Logo Placeholder
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black
                                      .withOpacity(isDark ? 0.3 : 0.05),
                                  blurRadius: 15)
                            ],
                          ),
                          child: Icon(Icons.store_rounded,
                              size: 48, color: cs.primary),
                        ),
                        const SizedBox(height: 16),
                        Text('Meyi POS',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: cs.onSurface)),
                        const SizedBox(height: 4),
                        Text(
                          _mostrarTel
                              ? 'Ingresa tu número de teléfono'
                              : 'Ingresa tu PIN de seguridad',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: cs.onSurface.withOpacity(0.5),
                              fontSize: 14),
                        ),
                        const SizedBox(height: 32),

                        // Card de Entrada
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black
                                      .withOpacity(isDark ? 0.2 : 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: _mostrarTel
                              ? _buildTelInput(cs, isDark)
                              : _buildPinInput(cs, isDark),
                        ),
                        const SizedBox(height: 24),

                        // Teclado Custom
                        _buildKeyboard(cs, isDark),

                        const SizedBox(height: 16),
                        if (!_mostrarTel)
                          TextButton(
                            onPressed: () => setState(() {
                              _mostrarTel = true;
                              _pin = '';
                            }),
                            style: TextButton.styleFrom(
                                foregroundColor: cs.primary),
                            child: const Text('← Usar otro número',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ),
                const InstitutionalFooter(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
}

  Widget _buildTelInput(ColorScheme cs, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('+52',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface.withOpacity(0.3))),
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
              ? () => setState(() => _mostrarTel = false)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(60),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: const Text('CONTINUAR',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
      ],
    );
  }

  Widget _buildPinInput(ColorScheme cs, bool isDark) {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        final offset = _shakeAnim.value * 12 * (0.5 - _shakeAnim.value).sign;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final isFilled = index < _pin.length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? cs.primary : cs.onSurface.withOpacity(0.1),
              boxShadow: isFilled
                  ? [
                      BoxShadow(
                          color: cs.primary.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2)
                    ]
                  : [],
              border: Border.all(
                  color: isFilled
                      ? Colors.transparent
                      : cs.onSurface.withOpacity(0.05),
                  width: 2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildKeyboard(ColorScheme cs, bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: GridView.count(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        childAspectRatio: 1.8,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          ...['1', '2', '3', '4', '5', '6', '7', '8', '9']
              .map((d) => _keyboardButton(d, cs, isDark)),
          const SizedBox.shrink(),
          _keyboardButton('0', cs, isDark),
          _keyboardButton('', cs, isDark, isDelete: true),
        ],
      ),
    );
  }

  Widget _keyboardButton(String label, ColorScheme cs, bool isDark,
      {bool isDelete = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDelete ? _onBorrar : () => _onDigito(label),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.onSurface.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1))
            ],
          ),
          alignment: Alignment.center,
          child: isDelete
              ? Icon(Icons.backspace_rounded,
                  size: 24, color: cs.onSurface.withOpacity(0.6))
              : Text(label,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface)),
        ),
      ),
    );
  }
}
