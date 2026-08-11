import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../theme/app_theme.dart';

/// Día 56 — pantalla para que el usuario cambie su propia contraseña desde
/// la app. Valida en el cliente (coincidencia + reglas de fortaleza que
/// coinciden con el backend) y llama a AuthApi.cambiarPassword.
class CambiarPasswordScreen extends StatefulWidget {
  const CambiarPasswordScreen({super.key});

  @override
  State<CambiarPasswordScreen> createState() => _CambiarPasswordScreenState();
}

class _CambiarPasswordScreenState extends State<CambiarPasswordScreen> {
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();

  bool _verActual = false;
  bool _verNueva = false;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  /// Mismas reglas que valida el backend (validar_password): mínimo 8
  /// caracteres, al menos una mayúscula y un carácter especial.
  String? _validarNueva(String p) {
    if (p.length < 8) return 'La nueva contraseña debe tener al menos 8 caracteres.';
    if (!RegExp(r'[A-Z]').hasMatch(p)) return 'Debe incluir al menos una letra mayúscula.';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(p)) return 'Debe incluir al menos un carácter especial.';
    return null;
  }

  Future<void> _guardar() async {
    setState(() => _error = null);
    final actual = _actual.text;
    final nueva = _nueva.text;
    final confirmar = _confirmar.text;

    if (actual.isEmpty) {
      setState(() => _error = 'Ingresá tu contraseña actual.');
      return;
    }
    final errReglas = _validarNueva(nueva);
    if (errReglas != null) {
      setState(() => _error = errReglas);
      return;
    }
    if (nueva != confirmar) {
      setState(() => _error = 'La nueva contraseña y su confirmación no coinciden.');
      return;
    }
    if (nueva == actual) {
      setState(() => _error = 'La nueva contraseña debe ser distinta de la actual.');
      return;
    }

    setState(() => _guardando = true);
    try {
      await AuthApi.cambiarPassword(actual, nueva);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Contraseña actualizada correctamente'),
        backgroundColor: AppColors.verde,
      ));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      // El mensaje del backend viene en la excepción (ej. "La contraseña
      // actual es incorrecta"). Se limpia el prefijo técnico si lo hubiera.
      var msg = e.toString().replaceFirst('Exception: ', '');
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cambiar contraseña'),
        backgroundColor: AppColors.azul,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Elegí una contraseña nueva. Debe tener al menos 8 caracteres, una mayúscula y un carácter especial.',
            style: TextStyle(color: AppColors.gris, fontSize: 13.5),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _actual,
            obscureText: !_verActual,
            decoration: InputDecoration(
              labelText: 'Contraseña actual',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_verActual ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _verActual = !_verActual),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nueva,
            obscureText: !_verNueva,
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
              prefixIcon: const Icon(Icons.lock_reset),
              suffixIcon: IconButton(
                icon: Icon(_verNueva ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _verNueva = !_verNueva),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _confirmar,
            obscureText: !_verNueva,
            decoration: const InputDecoration(
              labelText: 'Confirmar nueva contraseña',
              prefixIcon: Icon(Icons.lock_reset),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.rojo.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.rojo, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(_error!,
                    style: const TextStyle(color: AppColors.rojo, fontSize: 13))),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.azul,
                foregroundColor: Colors.white,
              ),
              child: _guardando
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
