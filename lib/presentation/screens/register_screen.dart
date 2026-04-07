import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 1;
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro Rápido'),
        leading: _step > 1 
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _step--))
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [1, 2, 3].map((i) => Expanded(
                child: Container(
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: i <= _step 
                        ? Theme.of(context).colorScheme.primary 
                        : Colors.grey.shade300,
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 48),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCurrentStep(),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _nextStep,
              child: Text(_step < 3 ? 'Siguiente' : '¡Listo, registrarme!'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 1: return _buildPhoneStep();
      case 2: return _buildPinStep();
      case 3: return _buildConfirmStep();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildPhoneStep() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('¿Cuál es tu celular?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Usarás este número para entrar a tu tienda', style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 40),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Celular (10 dígitos)',
            prefixText: '+52 ',
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget _buildPinStep() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Crea tu PIN', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Usa 4 números fáciles de recordar', style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 40),
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Tu PIN nuevo',
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Confirma tu PIN', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Repite el PIN que acabas de crear', style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 40),
        TextField(
          controller: _confirmPinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Confirmar PIN',
            counterText: '',
          ),
        ),
      ],
    );
  }

  void _nextStep() {
    if (_step == 1) {
      if (_phoneController.text.length < 10) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe un número válido')));
        return;
      }
      setState(() => _step++);
    } else if (_step == 2) {
      if (_pinController.text.length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El PIN debe tener 4 números')));
        return;
      }
      setState(() => _step++);
    } else if (_step == 3) {
      if (_pinController.text != _confirmPinController.text) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Los PINs no coinciden')));
        return;
      }
      // Simulación de registro exitoso
      context.go('/login');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Cuenta creada! Ya puedes entrar')),
      );
    }
  }
}
