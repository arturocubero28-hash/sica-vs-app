import 'package:flutter/material.dart';
import '../api/client.dart';
import '../theme/app_theme.dart';
import '../modules/shared/role_router.dart';
import '../api/notificaciones.dart';
import '../widgets/error_dialog.dart';

class LoginScreen extends StatefulWidget {
  // Día 58 (A-2) — mensaje que se muestra al entrar, usado cuando se llega
  // acá porque el backend expulsó al usuario (sesión revocada/expirada), en
  // vez del login normal en blanco.
  final String? mensajeInicial;
  const LoginScreen({super.key, this.mensajeInicial});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  bool _cargando      = false;
  bool _verPass       = false;

  @override
  void initState() {
    super.initState();
    // Día 63 — antes se guardaba en _error y se mostraba como texto chico
    // dentro del formulario, fácil de pasar por alto justo en el momento
    // en que más importa que la persona lo note (fue expulsada de su
    // sesión). Se muestra con el modal, después del primer frame (no se
    // puede abrir un diálogo antes de que la pantalla exista).
    if (widget.mensajeInicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ErrorDialog.mostrar(context, widget.mensajeInicial!, titulo: 'Sesión finalizada');
      });
    }
  }

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

  // Día 46: carga el nombre/logo de la residencial para CUALQUIER rol (no
  // solo el residente), porque guardias y otros roles también ven pantallas
  // con la marca (ej. seleccionar_punto_screen). No se espera (no bloquea la
  // navegación) y es silenciosa: si falla, ResidencialCache cae en sus
  // valores por defecto en vez de trabar el login.
  void _cargarResidencialEnSegundoPlano() {
    ResidenteApi.miResidencial().then((r) {
      ResidencialCache.set(
        r?['nombre'] as String?,
        logoArchivo: r?['logo_archivo'] as String?,
      );
      ResidencialCache.asegurarLogoDescargado(); // no bloquea; queda en disco para siempre
      // Día 47 — colores personalizables: se aplican apenas llegan, junto
      // con nombre/logo. AppColors.actualizar valida el formato e ignora
      // valores mal formados en silencio.
      AppColors.actualizar(
        primario: r?['color_primario'] as String?,
        secundario: r?['color_secundario'] as String?,
      );
    }).catchError((_) {});
  }

  Future<void> _login() async {
    if (_estaBloqueado) {
      ErrorDialog.mostrar(context, 'Demasiados intentos. Esperá $_tiempoRestante.');
      return;
    }
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      ErrorDialog.mostrar(context, 'Completá el correo y la contraseña');
      return;
    }
    setState(() { _cargando = true; });
    try {
      final res = await AuthApi.login(
        _emailCtrl.text.trim().toLowerCase(),
        _passCtrl.text,
      );
      final token = res['token'] as String;
      final user  = res['usuario'] as Map<String, dynamic>;
      final rol   = user['rol'] as String;

      await AuthStorage.guardar(token, rol, user);
      // Día 63: marca que este arranque de GuardiaShell viene de un login
      // real (usuario/contraseña), no de una simple reapertura de la app.
      AuthStorage.esLoginFresco = true;
      await NotificacionesService.registrarToken();
      _cargarResidencialEnSegundoPlano(); // no bloquea la navegación

      _intentosFallidos = 0; // reset on success

      if (!mounted) return;
      RoleRouter.navegar(context, rol);
    } on ApiException catch (e) {
      _intentosFallidos++;
      if (_intentosFallidos >= _maxIntentos) {
        _bloqueadoHasta = DateTime.now().add(const Duration(minutes: _minutosBloqueo));
        ErrorDialog.mostrar(context, 'Demasiados intentos fallidos. Bloqueado por $_minutosBloqueo minutos.');
      } else {
        final restantes = _maxIntentos - _intentosFallidos;
        ErrorDialog.mostrar(context, '${e.message} ($restantes intentos restantes)');
      }
    } catch (e) {
      // Día 62 — antes "catch (_)" descartaba el error real por completo,
      // sin dejar ningún rastro ni en pantalla ni en el log del sistema.
      // Un problema real de conexión quedaba imposible de diagnosticar sin
      // conectar el teléfono por USB. Ahora se muestra el tipo de error
      // real entre paréntesis (ej. "SocketException", "HandshakeException",
      // "TimeoutException") -- da una pista concreta sin exponer detalles
      // técnicos excesivos al residente.
      ErrorDialog.mostrar(context, 'No se pudo conectar. Verificá tu conexión. (${e.runtimeType})');
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
      backgroundColor: AppColors.azulDeFabrica,
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
                        const Icon(Icons.shield, color: AppColors.naranjaDeFabrica, size: 48),
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
                            color: AppColors.azulDeFabrica,
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
                              style: TextStyle(fontSize: 13, color: AppColors.naranjaDeFabrica)),
                        ),
                      ),

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
                Text('v1.0.0',
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
      ErrorDialog.mostrar(context, 'Ingresá tu correo electrónico');
      return;
    }
    setState(() { _enviando = true; });
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
      ErrorDialog.mostrar(context, e.message);
    } catch (e) {
      // Día 62 — mismo criterio que el catch de login: mostrar el tipo de
      // error real en vez de descartarlo, para poder diagnosticar sin
      // depender de conectar el teléfono por USB.
      ErrorDialog.mostrar(context, 'No se pudo conectar (${e.runtimeType})');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _restablecer() async {
    if (_tokenCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      ErrorDialog.mostrar(context, 'Completá el token y la nueva contraseña');
      return;
    }
    if (_passCtrl.text.length < 6) {
      ErrorDialog.mostrar(context, 'La contraseña debe tener al menos 6 caracteres');
      return;
    }
    setState(() { _restableciendo = true; });
    try {
      await ApiClient.post('/auth/reset', {
        'token': _tokenCtrl.text.trim(),
        'password': _passCtrl.text,
      }, auth: false);
      setState(() => _completado = true);
    } on ApiException catch (e) {
      ErrorDialog.mostrar(context, e.message);
    } catch (e) {
      // Día 62 — mismo criterio que el catch de login: mostrar el tipo de
      // error real en vez de descartarlo, para poder diagnosticar sin
      // depender de conectar el teléfono por USB.
      ErrorDialog.mostrar(context, 'No se pudo conectar (${e.runtimeType})');
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
              size: 40, color: _completado ? AppColors.verde : AppColors.azulDeFabrica),
          const SizedBox(height: 10),
          Text(_completado ? '¡Contraseña restablecida!' : 'Recuperar contraseña',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.azulDeFabrica)),
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
