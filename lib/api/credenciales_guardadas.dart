import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Día 66 — credenciales guardadas para login biométrico.
///
/// Estrategia de almacenamiento:
/// - Email: SharedPreferences (no sensible, persiste siempre, visible en login)
/// - Contraseña: FlutterSecureStorage sin encryptedSharedPreferences
///   (evita que Samsung borre los datos al limpiar EncryptedSharedPreferences)
/// - Flag activo: SharedPreferences (persiste entre sesiones)
class CredencialesGuardadas {
  // Sin encryptedSharedPreferences — usa KeyStore directamente, más estable
  // en Samsung que EncryptedSharedPreferences que puede borrarse en ciertos
  // eventos del sistema.
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: false),
  );

  static const _keyPass   = 'sica_cred_pass';
  static const _keyEmail  = 'sica_cred_email_prefs';   // en SharedPreferences
  static const _keyActivo = 'sica_cred_activo_prefs';  // en SharedPreferences

  /// ¿Hay credenciales guardadas para el login biométrico?
  static Future<bool> estaActivo() async {
    final prefs = await SharedPreferences.getInstance();
    final activo = prefs.getBool(_keyActivo) ?? false;
    if (!activo) return false;
    final email = prefs.getString(_keyEmail) ?? '';
    return email.isNotEmpty;
  }

  /// Guardar credenciales y activar el login biométrico.
  static Future<void> activar(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
    await prefs.setBool(_keyActivo, true);
    await prefs.setBool('bloqueo_biometrico_activo', true);
    // Solo la contraseña va al almacenamiento seguro
    await _secure.write(key: _keyPass, value: password);
  }

  /// Recuperar el email guardado (para mostrarlo en el formulario).
  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_keyEmail);
    return (email != null && email.isNotEmpty) ? email : null;
  }

  /// Recuperar email y contraseña para el login automático.
  /// Solo llamar DESPUÉS de autenticar con biometría.
  static Future<({String email, String password})?> getCredenciales() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_keyEmail) ?? '';
    final pass  = await _secure.read(key: _keyPass);
    if (email.isEmpty || pass == null) return null;
    return (email: email, password: pass);
  }

  /// Borrar todo — solo al desactivar biometría explícitamente.
  /// NO se llama al cerrar sesión normal.
  static Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyActivo);
    await _secure.delete(key: _keyPass);
  }
}
