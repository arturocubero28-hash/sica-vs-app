import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de bloqueo con huella / rostro.
///
/// Concepto: NO reemplaza el login. La sesión sigue viva (las notificaciones
/// push siguen llegando aunque la app esté cerrada). Lo que hace es pedir la
/// huella al ABRIR la app, para proteger la información sensible (cuotas,
/// pagos, generación de QR) si alguien más agarra el teléfono desbloqueado.
///
/// Es OPCIONAL: el residente decide si lo activa desde la sección Más.
class BloqueoBiometrico {
  static final _auth = LocalAuthentication();
  static const _prefKey = 'bloqueo_biometrico_activo';

  /// ¿El dispositivo tiene huella/rostro configurado y disponible?
  static Future<bool> disponible() async {
    try {
      final soportado = await _auth.isDeviceSupported();
      final puede = await _auth.canCheckBiometrics;
      return soportado && puede;
    } catch (_) {
      return false;
    }
  }

  /// ¿El usuario activó el bloqueo?
  static Future<bool> estaActivo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Activar o desactivar el bloqueo. Al activar, exige autenticarse una vez
  /// para confirmar que la huella funciona.
  static Future<bool> activar(bool valor) async {
    if (valor) {
      final ok = await autenticar(motivo: 'Confirmá tu huella para activar el bloqueo');
      if (!ok) return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, valor);
    return true;
  }

  /// Pide la autenticación biométrica. Devuelve true si fue exitosa.
  static Future<bool> autenticar({String motivo = 'Verificá tu identidad'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: motivo,
        options: const AuthenticationOptions(
          stickyAuth: true,        // reintenta si la app pasa a segundo plano
          biometricOnly: false,    // permite PIN/patrón del teléfono como respaldo
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
