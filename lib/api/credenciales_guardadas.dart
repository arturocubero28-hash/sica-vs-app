import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Día 72 — se eliminó "Iniciar sesión con huella".
///
/// Esa función guardaba la CONTRASEÑA en el teléfono para mandarla al
/// servidor cuando la huella coincidía. Con la sesión persistente ya no
/// hace falta: la sesión queda abierta hasta que la persona la cierra, y la
/// huella solo DESBLOQUEA la app (ver bloqueo_biometrico.dart).
///
/// Lo único que queda es la limpieza de los teléfonos que ya tenían la
/// contraseña guardada: se borra una vez, en el primer arranque con esta
/// versión. El correo se conserva para sugerirlo en el login.
class CredencialesGuardadas {
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'sica_credenciales_biometricas',
      resetOnError: true,
    ),
  );
  static const _keyEmail  = 'sica_cred_email_prefs';
  static const _keyActivo = 'sica_cred_activo_prefs';
  static const _marca     = 'migrado_dia72_sin_contrasena';

  static Future<void> borrarContrasenaGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_marca) == true) return;
    final email = prefs.getString(_keyEmail);
    if (email != null && email.isNotEmpty &&
        (prefs.getString('ultimo_email') ?? '').isEmpty) {
      await prefs.setString('ultimo_email', email);
    }
    try {
      await _secure.deleteAll();
    } catch (_) {}
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyActivo);
    await prefs.setBool(_marca, true);
  }
}
