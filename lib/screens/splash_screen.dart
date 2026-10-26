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

  Future<void> _verificar() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    // Día 64 — pedido del usuario: pedir el permiso de cámara al arrancar
    // la app (no solo cuando el guardia entra al escáner). De lo contrario,
    // el módulo del guardia arrancaba con la cámara denegada porque el
    // permiso recién se pedía cuando ya necesitaba usarse, demasiado tarde
    // para que Android pudiera mostrarlo sin interrumpir el flujo.
    // Se pide silenciosamente (sin diálogo propio): si Android muestra su
    // pop-up de permiso, bienvenido; si ya fue concedido, no hace nada.
    // Día 64 — se intentó pedir el permiso de cámara aquí al arrancar,
    // pero causaba que la app se quedara pegada en el splash en algunos
    // dispositivos Samsung después de que el usuario concedía el permiso.
    // El permiso se pide directamente en scanner_screen cuando se necesita.
    if (!mounted) return;

    final token = await AuthStorage.getToken();
    final rol   = await AuthStorage.getRol();

    if (token == null || rol == null) {
      // Día 64 — chequeo de consentimiento: si el usuario nunca aceptó los
      // términos (primera apertura de la app, o si los documentos se
      // actualizaron), mostrar la pantalla de consentimiento antes del login.
      final necesita = await ConsentimientoScreen.necesitaConsentimiento();
      if (!mounted) return;
      if (necesita) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => const ConsentimientoScreen(),
        ));
      } else {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
      return;
    }

    // Verificar que el token sigue siendo válido en el servidor.
    // Si el JWT expiró, el servidor devuelve 401 → _parse() limpia el token
    // → redirigir al login en vez de mostrar la app con errores de "token inválido".
    try {
      await ApiClient.get('/auth/me');
    } on ApiException catch (e) {
      if (!mounted) return;
      // El token expiró o fue revocado — ir al login
      if (e.code == 'no_autorizado' || e.code == 'ERROR') {
        final necesita = await ConsentimientoScreen.necesitaConsentimiento();
        if (!mounted) return;
        if (necesita) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => const ConsentimientoScreen(),
          ));
        } else {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()));
        }
        return;
      }
    } catch (_) {
      // Sin conexión — dejar entrar igual (funciona offline con datos en caché)
      // El primer request que haga fallará con error de red, no con 401
    }

    // Intentar recuperar comprobante pendiente
    await _recuperarComprobanteSiHubo();

    // Si el bloqueo biométrico está activo, pedir huella antes de entrar.
    final bloqueoActivo = await BloqueoBiometrico.estaActivo();
    if (bloqueoActivo) {
      final ok = await BloqueoBiometrico.autenticar(
        motivo: 'Desbloqueá la app con tu huella',
      );
      if (!ok) {
        if (mounted) setState(() => _bloqueado = true);
        return;
      }
    }
    if (!mounted) return;
    RoleRouter.navegar(context, rol);
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
      motivo: 'Desbloqueá la app con tu huella',
    );
    if (ok && mounted) {
      final rol = await AuthStorage.getRol();
      if (rol != null && mounted) RoleRouter.navegar(context, rol);
    }
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
                child: Text('App bloqueada. Usá tu huella para entrar.',
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
