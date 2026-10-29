import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de bloqueo con huella / rostro.
///
/// Concepto: NO reemplaza el login. La sesión sigue viva (las notificaciones
/// push siguen llegando aunque la app esté cerrada). Lo que hace es pedir la
/// huella al ABRIR la app, para proteger la información sensible (cuotas,
/// pagos, generación de QR) si alguien más agarra el teléfono desbloqueado.
///
/// Día 72 — quedan DOS cosas bien separadas:
///   · Iniciar sesión = correo + contraseña, una sola vez. La sesión queda
///     abierta en el servidor hasta que la persona la cierre.
///   · Desbloquear = esta clase. Es local, en el teléfono, para cuando la
///     sesión sigue abierta y la persona vuelve a la app.
///   · Inicio de sesión rápido con huella = credenciales_guardadas.dart.
///     Opcional, para volver a entrar después de CERRAR sesión.
///
/// Es OPCIONAL: se ofrece al iniciar sesión y se cambia desde Más.
class BloqueoBiometrico {
  static final _auth = LocalAuthentication();
  static const _prefKey = 'bloqueo_biometrico_activo';

  /// true mientras el diálogo de huella está en pantalla. En algunos
  /// teléfonos ese diálogo manda la app a "segundo plano" por un instante;
  /// el bloqueo automático (bloqueo_app.dart) lo ignora mientras tanto.
  static bool enCurso = false;

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

  /// Guarda la preferencia sin volver a pedir la huella (para cuando ya se
  /// pidió justo antes, p. ej. en el diálogo que aparece al iniciar sesión).
  static Future<void> fijar(bool valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, valor);
  }

  /// Pide la autenticación biométrica. Devuelve true si fue exitosa.
  static Future<bool> autenticar({String motivo = 'Verificá tu identidad'}) async {
    enCurso = true;
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
    } finally {
      enCurso = false;
    }
  }
}
