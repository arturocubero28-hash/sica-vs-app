import 'package:flutter/material.dart';
import '../api/client.dart';
import '../theme/app_theme.dart';
import '../modules/shared/role_router.dart';
import '../api/notificaciones.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  bool _cargando      = false;
  bool _verPass       = false;
  String? _error;

  // ── Bloqueo por intentos fallidos ──
  int _intentosFallidos = 0;
  DateTime? _bloqueadoHasta;
  static const int _maxIntentos = 8;
  static const int _minutosBloqueo = 3;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  bool get _estaBloqueado {
    if (_bloqueadoHasta == null) return false;
    if (DateTime.now().isAfter(_bloqueadoHasta!)) {
      _bloqueadoHasta = null;
      _intentosFallidos = 0;
      return false;
    }
    return true;
  }

  String get _tiempoRestante {
    if (_bloqueadoHasta == null) return '';
    final diff = _bloqueadoHasta!.difference(DateTime.now());
    if (diff.isNegative) return '';
    final min = diff.inMinutes;
    final seg = diff.inSeconds % 60;
    return '${min}m ${seg.toString().padLeft(2, '0')}s';
  }

  Future<void> _login() async {
    if (_estaBloqueado) {
      setState(() => _error = 'Demasiados intentos. Esperá $_tiempoRestante.');
      return;
    }
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Completá el correo y la contraseña');
      return;
    }
    setState(() { _cargando = true; _error = null; });
    try {
      final res = await AuthApi.login(
        _emailCtrl.text.trim().toLowerCase(),
        _passCtrl.text,
      );
      final token = res['token'] as String;
      final user  = res['usuario'] as Map<String, dynamic>;
      final rol   = user['rol'] as String;

      await AuthStorage.guardar(token, rol, user);
      await NotificacionesService.registrarToken();

      _intentosFallidos = 0; // reset on success

      if (!mounted) return;
      RoleRouter.navegar(context, rol);
    } on ApiException catch (e) {
      _intentosFallidos++;
      if (_intentosFallidos >= _maxIntentos) {
        _bloqueadoHasta = DateTime.now().add(const Duration(minutes: _minutosBloqueo));
        setState(() => _error = 'Demasiados intentos fallidos. Bloqueado por $_minutosBloqueo minutos.');
      } else {
        final restantes = _maxIntentos - _intentosFallidos;
        setState(() => _error = '${e.message} ($restantes intentos restantes)');
      }
    } catch (_) {
      setState(() => _error = 'No se pudo conectar. Verificá tu conexión.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _abrirRecuperacion() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _RecuperarPasswordSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.azul,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.shield, color: AppColors.naranja, size: 48),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('SICA-VS',
                    style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: 2,
                    )),
                const SizedBox(height: 4),
                Text('Residencial Villas del Sol',
                    style: TextStyle(
                      fontSize: 13, color: Colors.white.withOpacity(0.7),
                    )),
                const SizedBox(height: 40),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.15),
                          blurRadius: 20, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Iniciar sesión',
                          style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700,
                            color: AppColors.azul,
                          )),
                      const SizedBox(height: 20),

                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: _passCtrl,
                        obscureText: !_verPass,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_verPass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () => setState(() => _verPass = !_verPass),
                          ),
                        ),
                      ),

                      // ── Link de recuperación ──
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _abrirRecuperacion,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('¿Olvidaste tu contraseña?',
                              style: TextStyle(fontSize: 13, color: AppColors.naranja)),
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F0),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.rojo.withOpacity(0.4)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline, color: AppColors.rojo, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!,
                                style: const TextStyle(color: AppColors.rojo, fontSize: 13))),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 16),

                      ElevatedButton(
                        onPressed: (_cargando || _estaBloqueado) ? null : _login,
                        child: _cargando
                            ? const SizedBox(height: 20, width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(_estaBloqueado ? 'Bloqueado ($_tiempoRestante)' : 'Entrar'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('v1.0.0 · Día 30',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bottom sheet para recuperar contraseña ──────────────────────────────────
class _RecuperarPasswordSheet extends StatefulWidget {
  const _RecuperarPasswordSheet();

  @override
  State<_RecuperarPasswordSheet> createState() => _RecuperarPasswordSheetState();
}

class _RecuperarPasswordSheetState extends State<_RecuperarPasswordSheet> {
  final _emailCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _enviando = false;
  bool _tokenEnviado = false;
  bool _restableciendo = false;
  bool _completado = false;
  String? _error;
  String? _devToken; // solo en desarrollo

  @override
  void dispose() {
    _emailCtrl.dispose();
    _tokenCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _solicitarRecuperacion() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresá tu correo electrónico');
      return;
    }
    setState(() { _enviando = true; _error = null; });
    try {
      final res = await ApiClient.post('/auth/recuperar',
          {'email': _emailCtrl.text.trim().toLowerCase()}, auth: false);
      final data = res as Map<String, dynamic>;
      setState(() {
        _tokenEnviado = true;
        _devToken = data['dev_token']?.toString();
        if (_devToken != null) _tokenCtrl.text = _devToken!;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo conectar');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _restablecer() async {
    if (_tokenCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Completá el token y la nueva contraseña');
      return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }
    setState(() { _restableciendo = true; _error = null; });
    try {
      await ApiClient.post('/auth/reset', {
        'token': _tokenCtrl.text.trim(),
        'password': _passCtrl.text,
      }, auth: false);
      setState(() => _completado = true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo conectar');
    } finally {
      if (mounted) setState(() => _restableciendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(
              color: AppColors.borde, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Icon(_completado ? Icons.check_circle : Icons.lock_reset,
              size: 40, color: _completado ? AppColors.verde : AppColors.azul),
          const SizedBox(height: 10),
          Text(_completado ? '¡Contraseña restablecida!' : 'Recuperar contraseña',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.azul)),
          const SizedBox(height: 16),

          if (_completado) ...[
            const Text('Tu contraseña fue actualizada. Ya podés iniciar sesión.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.gris, fontSize: 14)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver al login'),
              ),
            ),
          ] else if (!_tokenEnviado) ...[
            const Text('Ingresá tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.gris, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
            ],
            const SizedBox(height: 18),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _enviando ? null : _solicitarRecuperacion,
                child: _enviando
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Enviar enlace'),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.verde.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.verde.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_outline, color: AppColors.verde, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  _devToken != null
                      ? 'Modo desarrollo: el token se autocompletó abajo.'
                      : 'Si el correo está registrado, recibirás un enlace.',
                  style: const TextStyle(color: AppColors.verde, fontSize: 13),
                )),
              ]),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _tokenCtrl,
              decoration: const InputDecoration(
                labelText: 'Token de recuperación',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nueva contraseña (mínimo 6 caracteres)',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
            ],
            const SizedBox(height: 18),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _restableciendo ? null : _restablecer,
                child: _restableciendo
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Restablecer contraseña'),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
