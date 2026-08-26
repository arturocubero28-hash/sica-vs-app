import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'bloqueo_biometrico.dart';

/// Día 65 — credenciales guardadas para login biométrico.
///
/// Flujo completo:
/// 1. Usuario inicia sesión por primera vez con email/contraseña.
/// 2. Si el dispositivo tiene biometría disponible y la función no está ya
///    activada, la app pregunta si quiere activar el acceso biométrico.
/// 3. Si acepta: se guarda email + contraseña en el almacenamiento seguro
///    del dispositivo (encriptado con Android Keystore / iOS Keychain), y se
///    activa el bloqueo biométrico.
/// 4. En logins siguientes: la pantalla de login muestra un botón "Entrar con
///    huella". Al pulsarlo, se autentica con biometría y se recuperan las
///    credenciales guardadas para hacer el login automáticamente.
///
/// SEGURIDAD:
/// - Las credenciales se guardan en FlutterSecureStorage (no SharedPreferences,
///   no almacenamiento en texto plano).
/// - Se borran automáticamente al cerrar sesión (AuthStorage.cerrarSesion).
/// - Si la biometría falla, el usuario puede seguir usando email/contraseña.
class CredencialesGuardadas {
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyEmail = 'sica_cred_email';
  static const _keyPass  = 'sica_cred_pass';
  static const _keyActivo = 'sica_cred_biometrico_activo';

  /// ¿Hay credenciales guardadas y el usuario activó el login biométrico?
  static Future<bool> estaActivo() async {
    final activo = await _secure.read(key: _keyActivo);
    if (activo != '1') return false;
    final email = await _secure.read(key: _keyEmail);
    return email != null && email.isNotEmpty;
  }

  /// Guardar credenciales y activar el login biométrico.
  static Future<void> activar(String email, String password) async {
    await _secure.write(key: _keyEmail, value: email);
    await _secure.write(key: _keyPass,  value: password);
    await _secure.write(key: _keyActivo, value: '1');
    // También activar el bloqueo biométrico de la app (pantalla al abrir).
    await BloqueoBiometrico.activar(true);
  }

  /// Recuperar el email guardado (para mostrarlo en el formulario).
  static Future<String?> getEmail() async {
    return await _secure.read(key: _keyEmail);
  }

  /// Recuperar email y contraseña para el login automático.
  /// Solo llamar DESPUÉS de autenticar con biometría.
  static Future<({String email, String password})?> getCredenciales() async {
    final email = await _secure.read(key: _keyEmail);
    final pass  = await _secure.read(key: _keyPass);
    if (email == null || pass == null) return null;
    return (email: email, password: pass);
  }

  /// Borrar todo. Llamar al cerrar sesión.
  static Future<void> limpiar() async {
    await _secure.delete(key: _keyEmail);
    await _secure.delete(key: _keyPass);
    await _secure.delete(key: _keyActivo);
  }
}
