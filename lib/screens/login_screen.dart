import 'package:flutter/material.dart';
import '../api/client.dart';
import '../api/bloqueo_biometrico.dart';
import '../api/credenciales_guardadas.dart';
import '../widgets/marca_residencial.dart';
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
  // Día 65 — login biométrico
  bool _biometricoDisponible = false;
  bool _biometricoActivo     = false;
  // Día 69 — a QUÉ cuenta pertenece la huella guardada. Antes no se guardaba
  // esta referencia en ningún lado: el casillero de credenciales era único y
  // anónimo, así que la app no sabía de quién eran y el botón de huella
  // entraba siempre con la primera cuenta que se hubiera guardado.
  String? _emailBiometrico;


  @override
  void initState() {
    super.initState();
    _verificarBiometrico();
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

  Future<void> _verificarBiometrico() async {
    final disponible = await BloqueoBiometrico.disponible();
    final activo = await CredencialesGuardadas.estaActivo();
    final email = activo ? await CredencialesGuardadas.getEmail() : null;
    // Día 72 — si no hay inicio rápido, igual se sugiere el último correo.
    final sugerido = email ?? await AuthStorage.getUltimoEmail();
    if (!mounted) return;
    setState(() {
      _biometricoDisponible = disponible;
      _biometricoActivo = activo;
      _emailBiometrico = email;
    });
    if (sugerido != null && _emailCtrl.text.isEmpty) {
      _emailCtrl.text = sugerido;
    }
  }

  /// Día 70 — marca si el login en curso lo disparó la huella. Sin esto no
  /// hay forma de saber, en el manejo del error, si la contraseña que falló
  /// la escribió la persona o salió del casillero guardado -- y solo en el
  /// segundo caso corresponde borrar la credencial.
  bool _veniaDeHuella = false;

  Future<void> _loginBiometrico() async {
    final ok = await BloqueoBiometrico.autenticar(
        motivo: 'Usá tu huella para iniciar sesión');
    if (!ok || !mounted) return;
    final creds = await CredencialesGuardadas.getCredenciales();
    if (creds == null) {
      // Día 70 — si la contraseña guardada no está, lo guardado YA NO SIRVE
      // para nada. Antes solo se apagaba la opción en pantalla y el correo
      // seguía guardado, así que al volver al login el botón "Entrar con
      // huella" reaparecía y fallaba otra vez. Se borra de verdad.
      await CredencialesGuardadas.limpiar();
      if (!mounted) return;
      ErrorDialog.mostrar(context,
          'El acceso con huella se desconfiguró en este teléfono. '
          'Entrá con tu contraseña y volvé a activarlo.');
      setState(() {
        _biometricoActivo = false;
        _emailBiometrico = null;
      });
      return;
    }
    _emailCtrl.text = creds.email;
    _passCtrl.text  = creds.password;
    _veniaDeHuella = true;
    try {
      await _login();
    } finally {
      _veniaDeHuella = false;
    }
  }

  /// Día 72 — al iniciar sesión se ofrecen las DOS funciones de huella,
  /// cada una con su propio interruptor porque sirven para cosas distintas:
  ///
  ///   · Inicio de sesión rápido: se ofrece cuando ESTA cuenta no tiene sus
  ///     credenciales guardadas en el teléfono. Sirve para volver a entrar
  ///     con la huella después de cerrar sesión.
  ///   · Desbloqueo con huella: se ofrece si todavía no está activo. Es para
  ///     cuando la sesión sigue abierta y la persona vuelve a la app. No se
  ///     ofrece al guardia (su sesión vence con el turno).
  ///
  /// Día 69 — regla que se mantiene: hay UN casillero de inicio rápido por
  /// teléfono y gana la ÚLTIMA cuenta que lo guarda. Si ya había otra, se
  /// avisa cuál se reemplaza; nunca se pisa en silencio.
  Future<void> _ofrecerHuella(String email, String password, String rol) async {
    if (!_biometricoDisponible) return;
    final ofrecerRapido = !await CredencialesGuardadas.esDe(email);
    final ofrecerDesbloqueo =
        rol != 'guardia' && !await BloqueoBiometrico.estaActivo();
    if (!ofrecerRapido && !ofrecerDesbloqueo) return;
    final otraCuenta = ofrecerRapido ? await CredencialesGuardadas.getEmail() : null;

    bool rapido = ofrecerRapido;
    bool desbloqueo = ofrecerDesbloqueo;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final aceptado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.naranja.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.fingerprint, color: AppColors.naranja, size: 30),
            ),
            const SizedBox(height: 14),
            Text('¿Usar tu huella en este teléfono?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.azul),
              textAlign: TextAlign.center),
            const SizedBox(height: 4),
            const Text('Tu sesión queda abierta hasta que la cierres.',
              style: TextStyle(fontSize: 13, color: AppColors.gris),
              textAlign: TextAlign.center),
            const SizedBox(height: 12),
            if (ofrecerRapido)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: rapido,
                activeColor: AppColors.naranja,
                onChanged: (v) => setD(() => rapido = v),
                title: const Text('Inicio de sesión rápido',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                subtitle: Text(
                  (otraCuenta != null && otraCuenta.isNotEmpty)
                      ? 'Si cerrás sesión, entrás de nuevo solo con tu huella. '
                        'Reemplaza al de $otraCuenta en este teléfono.'
                      : 'Si cerrás sesión, entrás de nuevo solo con tu huella, '
                        'sin escribir la contraseña.',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.gris, height: 1.3)),
              ),
            if (ofrecerDesbloqueo)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: desbloqueo,
                activeColor: AppColors.naranja,
                onChanged: (v) => setD(() => desbloqueo = v),
                title: const Text('Desbloqueo con huella',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                subtitle: const Text(
                  'Mientras tu sesión esté abierta, te pedimos la huella cada vez '
                  'que volvés a la app.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.gris, height: 1.3)),
              ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.naranja, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Guardar',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Ahora no', style: TextStyle(color: AppColors.gris.withOpacity(0.7))),
            ),
          ]),
        ),
      )),
    );
    if (aceptado != true || (!rapido && !desbloqueo)) return;

    // Se confirma la huella UNA vez, valga para lo que se haya elegido.
    final ok = await BloqueoBiometrico.autenticar(motivo: 'Confirmá tu huella');
    if (!ok) {
      if (mounted) {
        ErrorDialog.mostrar(context,
            'No se activó la huella. Podés hacerlo después desde Más.');
      }
      return;
    }
    if (rapido) {
      // activar() escribe sobre el mismo casillero: gana la última cuenta.
      await CredencialesGuardadas.activar(email, password);
      if (mounted) {
        setState(() {
          _biometricoActivo = true;
          _emailBiometrico = email;
        });
      }
    }
    if (desbloqueo) await BloqueoBiometrico.fijar(true);
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

      // Día 72 — refresh_token: la sesión queda abierta hasta que la
      // persona la cierre. El servidor no lo manda para el guardia.
      await AuthStorage.guardar(token, rol, user,
          refresh: res['refresh_token'] as String?);
      await AuthStorage.setUltimoEmail(_emailCtrl.text.trim().toLowerCase());
      // Día 63: marca que este arranque de GuardiaShell viene de un login
      // real (usuario/contraseña), no de una simple reapertura de la app.
      AuthStorage.esLoginFresco = true;
      await NotificacionesService.registrarToken();
      _cargarResidencialEnSegundoPlano(); // no bloquea la navegación

      _intentosFallidos = 0; // reset on success

      if (!mounted) return;
      // Dia 66 — ofrecer la huella ANTES de navegar.
      // RoleRouter.navegar() usa pushReplacement, destruyendo el context
      // del login. Si el diálogo se abría después, showDialog() fallaba
      // en silencio y no se guardaba nada.
      final emailUsado = _emailCtrl.text.trim().toLowerCase();
      final passUsada  = _passCtrl.text;
      // Si entró CON la huella, ya está todo guardado: no se pregunta nada.
      if (!_veniaDeHuella) await _ofrecerHuella(emailUsado, passUsada, rol);
      if (!mounted) return;
      AuthStorage.desbloqueada = true;
      RoleRouter.navegar(context, rol);
    } on ApiException catch (e) {
      // Día 70 — si el intento venía de la huella y el servidor rechazó la
      // contraseña, la credencial guardada quedó vieja (la cambiaron desde
      // la web, por ejemplo). Se borra ACÁ MISMO.
      //
      // Antes no se borraba, y el costo no era solo una molestia: el
      // servidor permite 5 intentos cada 15 minutos POR IP. Cada toque al
      // botón de la huella gastaba uno de esos cinco sin que la persona lo
      // supiera, y en cuatro toques quedaba sin poder entrar ni con la
      // contraseña correcta. Un residente podía dejarse afuera de su propia
      // cuenta sin escribir una sola letra mal.
      // Día 70 — SOLO se borra la credencial guardada cuando el servidor
      // dice que la contraseña está mal. Nada más.
      //
      // La primera versión de este arreglo borraba ante CUALQUIER error, y
      // eso convertía el bloqueo por intentos en una pérdida de datos: al
      // repetir la prueba se superaban los 5 intentos por IP, el servidor
      // respondía 'demasiados_intentos', y la app interpretaba eso como
      // "la contraseña guardada no sirve" y la borraba. El usuario perdía
      // su acceso con huella por un límite que no tiene nada que ver con
      // si su contraseña es correcta.
      //
      // Un 429 (muchos intentos), un 500 o un corte de red no dicen
      // absolutamente nada sobre la credencial. Solo
      // 'credenciales_invalidas' lo dice.
      final credencialRechazada = e.code == 'credenciales_invalidas';
      final bloqueoDelServidor  = e.code == 'demasiados_intentos';

      if (_veniaDeHuella && credencialRechazada) {
        await CredencialesGuardadas.limpiar();
        if (mounted) {
          setState(() {
            _biometricoActivo = false;
            _emailBiometrico = null;
          });
        }
      }
      if (!mounted) return;

      if (bloqueoDelServidor) {
        // No se suma al contador local: el que está bloqueando es el
        // servidor, y contarlo acá además encadenaría los dos bloqueos.
        ErrorDialog.mostrar(context, e.message);
        return;
      }

      _intentosFallidos++;
      if (_intentosFallidos >= _maxIntentos) {
        _bloqueadoHasta = DateTime.now().add(const Duration(minutes: _minutosBloqueo));
        ErrorDialog.mostrar(context, 'Demasiados intentos fallidos. Bloqueado por $_minutosBloqueo minutos.');
      } else if (_veniaDeHuella && credencialRechazada) {
        ErrorDialog.mostrar(context,
            'La contraseña guardada para la huella ya no es válida. '
            'Entrá con tu contraseña y volvé a activar la huella.');
      } else if (_veniaDeHuella) {
        // Falló por otra cosa (red, servidor). La huella sigue guardada.
        ErrorDialog.mostrar(context,
            'No se pudo entrar con la huella: ${e.message}');
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
      body: FondoMarca(
        child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const MarcaResidencial(tamLogo: 92),
                const SizedBox(height: 36),

                Container(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.18),
                          blurRadius: 30, offset: const Offset(0, 12)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Bienvenido',
                          style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800,
                            color: AppColors.azulDeFabrica,
                          )),
                      const SizedBox(height: 4),
                      const Text('Iniciá sesión para continuar',
                          style: TextStyle(fontSize: 13.5, color: AppColors.gris)),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.naranjaDeFabrica,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        child: _cargando
                            ? const SizedBox(height: 20, width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(_estaBloqueado ? 'Bloqueado ($_tiempoRestante)' : 'Entrar'),
                      ),

                      // Dia 65 — boton de huella si hay credenciales guardadas
                      if (_biometricoActivo) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _cargando ? null : _loginBiometrico,
                          icon: const Icon(Icons.fingerprint),
                          // Dia 69 — el boton dice de QUIEN es la huella
                          // guardada. Antes decia solo "Entrar con huella" y
                          // entraba con una cuenta que podia no ser la que el
                          // usuario tenia escrita en el formulario.
                          label: Text(
                            _emailBiometrico == null
                                ? 'Entrar con huella'
                                : 'Entrar con huella · $_emailBiometrico',
                            textAlign: TextAlign.center,
                          ),
                          style: OutlinedButton.styleFrom(
                            // Día 66 — era blanco sobre la tarjeta blanca del
                            // formulario: el botón se renderizaba pero era
                            // completamente invisible.
                            foregroundColor: AppColors.azulDeFabrica,
                            side: const BorderSide(color: AppColors.naranjaDeFabrica, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('$kNombreApp · v1.0.0',
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),

              ],
            ),
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
  bool _enviando = false;
  bool _enviado = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _solicitarRecuperacion() async {
    if (_emailCtrl.text.trim().isEmpty) {
      ErrorDialog.mostrar(context, 'Ingresá tu correo electrónico');
      return;
    }
    setState(() { _enviando = true; });
    try {
      await ApiClient.post('/auth/recuperar',
          {'email': _emailCtrl.text.trim().toLowerCase()}, auth: false);
      // Día 65 — ya no se muestra el campo de token ni de nueva contraseña
      // en la app. El backend envía el link al correo con el token incluido;
      // el usuario hace clic en ese link desde su correo y define su
      // contraseña en el panel web. Así el flujo es más simple y seguro.
      // La respuesta del backend puede ser éxito (cuenta encontrada) o
      // 404 (cuenta no encontrada), pero en ambos casos mostramos el mismo
      // mensaje para no revelar si un correo existe en el sistema.
      if (mounted) setState(() => _enviado = true);
    } catch (_) {
      // Mismo criterio de privacidad: no revelar si el correo existe o no.
      // Si hay un error de red real, el estado 'enviado' no se activa y
      // el usuario puede reintentar.
      if (mounted) setState(() => _enviado = true);
    } finally {
      if (mounted) setState(() => _enviando = false);
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
          Icon(_enviado ? Icons.mark_email_read_outlined : Icons.lock_reset,
              size: 40, color: _enviado ? AppColors.verde : AppColors.azulDeFabrica),
          const SizedBox(height: 10),
          Text(_enviado ? 'Revisá tu correo' : 'Recuperar contraseña',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.azulDeFabrica)),
          const SizedBox(height: 16),

          if (_enviado) ...[
            const Text(
              'Si tu correo está registrado en el sistema, vas a recibir un mensaje con un enlace para restablecer tu contraseña.\n\nRevisá también la carpeta de spam.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gris, fontSize: 13, height: 1.5)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver al login'),
              ),
            ),
          ] else ...[
            const Text('Ingresá tu correo y te enviaremos un enlace para restablecer tu contraseña.',
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
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

