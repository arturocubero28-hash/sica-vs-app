import 'package:flutter/material.dart';
import '../api/client.dart';
import '../api/bloqueo_biometrico.dart';
import '../widgets/marca_residencial.dart';
import '../theme/app_theme.dart';
import '../modules/shared/role_router.dart';
import 'consentimiento_screen.dart';
import 'login_screen.dart';

/// Pantalla de inicio: verifica si ya hay sesión guardada.
/// Si la hay, navega al módulo del rol correspondiente.
/// Si no, muestra el login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  bool _bloqueado = false;

  // Día 71 — entrada animada: una vez la aparición, y sin fin el giro de
  // los rayos y el latido del resplandor.
  late final AnimationController _entrada = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1700));
  late final AnimationController _giro = AnimationController(
      vsync: this, duration: const Duration(seconds: 24));
  bool _animacionLista = false;

  @override
  void initState() {
    super.initState();
    _verificar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animacionLista) return;
    _animacionLista = true;
    // Si el teléfono tiene "quitar animaciones" por accesibilidad, se
    // muestra todo de una vez y quieto.
    if (MediaQuery.of(context).disableAnimations) {
      _entrada.value = 1;
    } else {
      _entrada.forward();
      _giro.repeat();
    }
  }

  @override
  void dispose() {
    _entrada.dispose();
    _giro.dispose();
    super.dispose();
  }

  /// Día 72 — orden nuevo, estilo WhatsApp:
  ///   1. ¿Hay sesión guardada? Si no, login (o consentimiento).
  ///   2. Desbloqueo LOCAL con huella, si la persona lo activó. Va primero
  ///      porque es instantáneo y no depende de la red.
  ///   3. Verificar la sesión con el servidor (renovándola sola si el JWT
  ///      venció). Solo se va al login si el servidor dice que la sesión
  ///      se cerró de verdad. Sin red, se entra igual.
  ///
  /// Antes se pedía la contraseña cada vez que el JWT de 12 horas había
  /// vencido, y además cualquier error genérico del servidor ('ERROR')
  /// también mandaba al login.
  Future<void> _verificar() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    // Día 64 — el permiso de cámara NO se pide acá: dejaba la app pegada
    // en el inicio en algunos Samsung. Se pide en scanner_screen.
    final haySesion = await AuthStorage.tieneSesion();
    final rol = await AuthStorage.getRol();
    if (!mounted) return;
    if (!haySesion || rol == null) {
      await _irAlLogin();
      return;
    }

    if (await BloqueoBiometrico.estaActivo()) {
      final ok = await BloqueoBiometrico.autenticar(
        motivo: 'Desbloqueá Villas del Sol',
      );
      if (!ok) {
        if (mounted) setState(() => _bloqueado = true);
        return;
      }
    }
    await _entrar(rol);
  }

  Future<void> _entrar(String rol) async {
    final estado = await ApiClient.verificarSesion();
    if (!mounted) return;
    if (estado == EstadoSesion.cerrada) {
      await AuthStorage.limpiar();
      AppColors.restablecerFabrica();
      await _irAlLogin(mensaje: 'Tu sesión se cerró. Iniciá sesión de nuevo.');
      return;
    }
    // valida o sinConexion: se entra. Sin red la app trabaja con lo que
    // tiene en caché; la próxima petición renueva la sesión sola.
    await _recuperarComprobanteSiHubo();
    if (!mounted) return;
    AuthStorage.desbloqueada = true;
    RoleRouter.navegar(context, rol);
  }

  Future<void> _irAlLogin({String? mensaje}) async {
    // Día 64 — si nunca aceptó los términos (o se actualizaron), primero
    // la pantalla de consentimiento.
    final necesita = await ConsentimientoScreen.necesitaConsentimiento();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => necesita
          ? const ConsentimientoScreen()
          : LoginScreen(mensajeInicial: mensaje),
    ));
  }

  /// Si Android mató la app mientras el residente tomaba una foto de
  /// comprobante, NO se sube nada automáticamente — el residente puede
  /// haber estado acumulando varias fotos para el mismo pago. El estado
  /// queda intacto y la pantalla de cuotas lo recupera cuando el residente
  /// vuelve a intentar subir el comprobante de esa cuota.
  Future<void> _recuperarComprobanteSiHubo() async {
    // Sin acción: se deja el estado pendiente en SharedPreferences tal cual.
    // _PantallaMultiplesComprobantes lo lee en su initState() cuando el
    // residente reabre la subida de esa cuota específica.
  }

  Future<void> _reintentar() async {
    final ok = await BloqueoBiometrico.autenticar(
      motivo: 'Desbloqueá Villas del Sol',
    );
    if (!ok || !mounted) return;
    final rol = await AuthStorage.getRol();
    if (rol == null) {
      await _irAlLogin();
      return;
    }
    setState(() => _bloqueado = false);
    await _entrar(rol);
  }

  Future<void> _cerrarSesion() async {
    await AuthStorage.cerrarSesion(); // AUTH-02: revoca el JWT en el servidor, no solo local
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.azulDeFabrica,
      body: FondoMarca(
        child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MarcaAnimada(entrada: _entrada, giro: _giro, tamLogo: 108),
            const SizedBox(height: 32),
            if (_bloqueado) ...[
              const Icon(Icons.lock_outline, color: Colors.white70, size: 32),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text('App bloqueada. Tu sesión sigue abierta: usá tu huella para entrar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _reintentar,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Desbloquear'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _cerrarSesion,
                child: const Text('Cerrar sesión',
                    style: TextStyle(color: Colors.white54)),
              ),
            ] else
              // La ruedita aparece recién al final de la animación: si el
              // arranque es rápido ni se ve, y si tarda, avisa que sigue.
              FadeTransition(
                opacity: CurvedAnimation(parent: _entrada, curve: const Interval(0.85, 1.0)),
                child: const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(
                      color: AppColors.naranjaDeFabrica, strokeWidth: 2.5),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}
